#!/usr/bin/env python3
"""Extract exact-unique Standard skills from the single-skill mapping."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
from collections import defaultdict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SKILL_MAPPING_FILE = REPO_ROOT / "benchmark" / "datas" / "single_skill_mapping" / "standard.jsonl"
SKILLS_ROOT = REPO_ROOT / "benchmark" / "datas" / "optional_skills" / "skills"
TARGET = Path(__file__).resolve().parent / "skills"
STAGING = TARGET.with_name("skills.__staging__")
REGISTRY = Path(__file__).resolve().parent / "task_skill_registry.jsonl"


def skill_md_sha256(skill_dir: Path) -> str:
    return hashlib.sha256((skill_dir / "SKILL.md").read_bytes()).hexdigest()


def tree_sha256(skill_dir: Path) -> str:
    """Hash relative paths, entry types, symlink targets, and file bytes."""
    digest = hashlib.sha256()
    entries = sorted(
        skill_dir.rglob("*"),
        key=lambda path: path.relative_to(skill_dir).as_posix().casefold(),
    )
    for path in entries:
        relative = path.relative_to(skill_dir).as_posix()
        digest.update(relative.encode("utf-8"))
        digest.update(b"\0")
        if path.is_symlink():
            digest.update(b"L\0")
            digest.update(os.readlink(path).encode("utf-8"))
        elif path.is_dir():
            digest.update(b"D\0")
        elif path.is_file():
            digest.update(b"F\0")
            with path.open("rb") as handle:
                for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                    digest.update(chunk)
        else:
            digest.update(b"O\0")
        digest.update(b"\0")
    return digest.hexdigest()


def exact_unique(candidates: list[Path]) -> list[Path]:
    """Deduplicate only when directory name and complete contents match."""
    by_name_and_skill_md: dict[tuple[str, str], list[Path]] = defaultdict(list)
    for skill_dir in candidates:
        key = (skill_dir.name.casefold(), skill_md_sha256(skill_dir))
        by_name_and_skill_md[key].append(skill_dir)

    selected: list[Path] = []
    for group in by_name_and_skill_md.values():
        if len(group) == 1:
            selected.append(group[0])
            continue
        seen_trees: set[str] = set()
        for skill_dir in group:
            tree_hash = tree_sha256(skill_dir)
            if tree_hash in seen_trees:
                continue
            seen_trees.add(tree_hash)
            selected.append(skill_dir)
    return selected


def mapping_records() -> list[dict[str, object]]:
    records = [
        json.loads(line)
        for line in SKILL_MAPPING_FILE.read_text(encoding="utf-8-sig").splitlines()
        if line.strip()
    ]
    if any(not isinstance(record, dict) for record in records):
        raise ValueError(f"Invalid mapping record in {SKILL_MAPPING_FILE}")
    return records


def first_task_for_skill(skill_name: str) -> str:
    for record in mapping_records():
        skills = record.get("skills")
        if isinstance(skills, list) and skill_name in skills:
            return str(record["task_id"])
    raise ValueError(f"Skill is not referenced by the mapping: {skill_name}")


def unique_destination_name(
    preferred: str,
    source_task_label: str,
    used_names: set[str],
) -> str:
    candidate = preferred
    if candidate.casefold() in used_names:
        candidate = f"{preferred}--{source_task_label}"
        suffix = 2
        while candidate.casefold() in used_names:
            candidate = f"{preferred}--{source_task_label}--{suffix}"
            suffix += 1
    used_names.add(candidate.casefold())
    return candidate


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Extract Standard skills and preserve every Task-Skill relation."
    )
    parser.add_argument(
        "--registry-only",
        action="store_true",
        help="Validate existing skills/ and rebuild only task_skill_registry.jsonl.",
    )
    return parser.parse_args()


def collect_candidates() -> list[Path]:
    candidates: list[Path] = []
    for record in mapping_records():
        task_id = record.get("task_id")
        skill_names = record.get("skills")
        if not isinstance(task_id, str) or not isinstance(skill_names, list):
            raise ValueError(f"Invalid mapping record: {record!r}")
        for skill_name in skill_names:
            if not isinstance(skill_name, str):
                raise ValueError(f"Invalid Skill name for {task_id}: {skill_name!r}")
            skill_dir = SKILLS_ROOT / skill_name
            if not (skill_dir / "SKILL.md").is_file():
                raise FileNotFoundError(f"Mapped Skill is unavailable: {skill_dir}")
            candidates.append(skill_dir)
    return candidates


def build_selection(candidates: list[Path]) -> list[tuple[Path, str, str]]:
    used_names: set[str] = set()
    selected: list[tuple[Path, str, str]] = []
    for skill_dir in exact_unique(candidates):
        source_task_label = first_task_for_skill(skill_dir.name)
        destination_name = unique_destination_name(
            skill_dir.name,
            source_task_label,
            used_names,
        )
        selected.append((skill_dir, destination_name, source_task_label))
    selected.sort(key=lambda item: item[1].casefold())
    return selected


def build_relations(
    candidates: list[Path], selected: list[tuple[Path, str, str]]
) -> list[dict[str, str | int]]:
    destination_by_identity = {
        (skill_dir.name.casefold(), tree_sha256(skill_dir)): destination_name
        for skill_dir, destination_name, _ in selected
    }
    relations: list[dict[str, str | int]] = []
    seen: set[tuple[str, str, str]] = set()
    for record in mapping_records():
        for skill_name in record["skills"]:
            skill_dir = SKILLS_ROOT / str(skill_name)
            identity = (skill_dir.name.casefold(), tree_sha256(skill_dir))
            destination_name = destination_by_identity[identity]
            relation_key = (str(record["task_id"]), "Standard", destination_name)
            if relation_key in seen:
                continue
            seen.add(relation_key)
            relations.append(
                {
                    "schema_version": 1,
                    "task_id": relation_key[0],
                    "label": relation_key[1],
                    "skill_dir_name": relation_key[2],
                }
            )
    relations.sort(
        key=lambda item: (
            str(item["task_id"]).casefold(),
            str(item["label"]).casefold(),
            str(item["skill_dir_name"]).casefold(),
        )
    )
    return relations


def validate_existing_target(selected: list[tuple[Path, str, str]]) -> None:
    expected = {destination.casefold() for _, destination, _ in selected}
    actual_dirs = [path for path in TARGET.iterdir() if path.is_dir()]
    actual = {path.name.casefold() for path in actual_dirs}
    if actual != expected or len(actual) != len(actual_dirs):
        raise RuntimeError(
            "Existing Standard skills/ does not match the extraction plan: "
            f"missing={sorted(expected - actual)}, extra={sorted(actual - expected)}"
        )
    actual_by_name = {path.name.casefold(): path for path in actual_dirs}
    for source, destination, _ in selected:
        if tree_sha256(actual_by_name[destination.casefold()]) != tree_sha256(source):
            raise RuntimeError(
                f"Existing Standard skill differs from its source: {destination}"
            )


def write_registry(relations: list[dict[str, str | int]]) -> None:
    temporary = REGISTRY.with_suffix(REGISTRY.suffix + ".tmp")
    payload = "".join(
        json.dumps(item, ensure_ascii=False, separators=(",", ":")) + "\n"
        for item in relations
    )
    temporary.write_text(payload, encoding="utf-8", newline="\n")
    temporary.replace(REGISTRY)


def main() -> None:
    args = parse_args()
    if not SKILL_MAPPING_FILE.is_file():
        raise FileNotFoundError(f"Standard mapping does not exist: {SKILL_MAPPING_FILE}")
    if not SKILLS_ROOT.is_dir():
        raise FileNotFoundError(f"Central Skill directory does not exist: {SKILLS_ROOT}")
    if not TARGET.is_dir():
        raise FileNotFoundError(f"Target directory does not exist: {TARGET}")

    candidates = collect_candidates()
    selected = build_selection(candidates)
    relations = build_relations(candidates, selected)

    if not selected:
        raise RuntimeError(
            f"No Standard skills containing a top-level SKILL.md were found in "
            f"{SKILL_MAPPING_FILE}"
        )
    if args.registry_only:
        validate_existing_target(selected)
    else:
        if any(TARGET.iterdir()):
            raise RuntimeError(f"Target directory must be empty: {TARGET}")
        if STAGING.exists():
            raise RuntimeError(f"Staging directory already exists: {STAGING}")

        STAGING.mkdir()
        for skill_dir, destination_name, _ in selected:
            shutil.copytree(skill_dir, STAGING / destination_name)

        copied_dirs = sorted(
            (path for path in STAGING.iterdir() if path.is_dir()),
            key=lambda path: path.name.casefold(),
        )
        if len(copied_dirs) != len(selected):
            raise RuntimeError("Copied directory count differs from the selected count")
        for skill_dir, destination_name, _ in selected:
            copied_dir = STAGING / destination_name
            if tree_sha256(copied_dir) != tree_sha256(skill_dir):
                raise RuntimeError(
                    f"Copied directory tree differs from source: {destination_name}"
                )

        TARGET.rmdir()
        STAGING.replace(TARGET)
    write_registry(relations)

    renamed = [
        (skill_dir.name, destination_name, source_task_label)
        for skill_dir, destination_name, source_task_label in selected
        if skill_dir.name != destination_name
    ]
    distinct_tree_hashes = {
        tree_sha256(skill_dir) for skill_dir, _, _ in selected
    }
    print(f"candidate_standard_skills={len(candidates)}")
    print(f"duplicate_candidates_removed={len(candidates) - len(selected)}")
    print(f"unique_skills_copied={len(selected)}")
    print(f"unique_name_and_tree_identities={len(selected)}")
    print(f"distinct_tree_hashes={len(distinct_tree_hashes)}")
    print(f"renamed_for_name_collisions={len(renamed)}")
    print(f"task_skill_relations={len(relations)}")
    print(f"registry={REGISTRY}")
    print(f"registry_only={str(args.registry_only).lower()}")
    for source_name, destination_name, source_task_label in renamed:
        print(
            f"renamed={source_name}->{destination_name} "
            f"source_task={source_task_label}"
        )


if __name__ == "__main__":
    main()
