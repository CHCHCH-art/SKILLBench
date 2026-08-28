#!/usr/bin/env python3
"""Build a merged dataset from selected Part-2k components.

When Standard and Random_2K are selected together, a Random skill is omitted when
its complete internal tree matches Standard. The top-level directory name is not
part of this comparison. Other components are merged without cross-component
deduplication.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import shutil
import sys
import tempfile
import time
import uuid
from collections import Counter
from pathlib import Path


BASE = Path(__file__).resolve().parent
COMPONENTS = ("Danger", "Standard", "High_Cost", "Random_2K")
COMPONENT_LOOKUP = {name.casefold(): name for name in COMPONENTS}
DEFAULT_ROLES = {
    "Danger": "Danger",
    "Standard": "Standard",
    "High_Cost": "High_Cost",
    "Random_2K": "Random_sample",
}
MIN_COMPONENTS = 2
REQUIRED_RECORD_FIELDS = ("skill_id", "skill_name", "skill_dir_name")
TASK_REGISTRY_FILENAME = "task_skill_registry.jsonl"
RELATION_FIELDS = ("task_id", "label", "skill_dir_name")
EXPECTED_COMPONENT_LABEL = {
    "Standard": "Standard",
    "Danger": "Risk",
    "High_Cost": "High_Cost",
}
INVALID_WINDOWS_NAME_CHARS = set('<>:"/\\|?*')
RESERVED_WINDOWS_NAMES = {
    "CON",
    "PRN",
    "AUX",
    "NUL",
    *(f"COM{index}" for index in range(1, 10)),
    *(f"LPT{index}" for index in range(1, 10)),
}


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Merge 2 to 4 Part-2k components into a new dataset containing "
            "All.jsonl and skills/."
        ),
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog=r"""
Examples:
  python build_dataset.py --components Random_2K Standard Danger ^
    --output-root ..\datasets ^
    --dataset-name Random-Standard-Danger

  python build_dataset.py --components Random_2K Standard Danger High_Cost ^
    --output-root ..\datasets ^
    --dataset-name Full-Part-2k --id-prefix Full-Part-2k

Add --dry-run to validate and preview without writing files.
""",
    )
    parser.add_argument(
        "--components",
        nargs="+",
        required=True,
        metavar="NAME",
        help="Ordered selection from: Danger, Standard, High_Cost, Random_2K.",
    )
    parser.add_argument(
        "--output-root",
        required=True,
        type=Path,
        help="Parent directory in which the named dataset directory is created.",
    )
    parser.add_argument(
        "--dataset-name",
        required=True,
        help="New dataset directory name.",
    )
    parser.add_argument(
        "--id-prefix",
        help="Prefix for sequential skill_id values; defaults to dataset-name.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate inputs and print the merge plan without creating output.",
    )
    return parser.parse_args()


def normalize_components(raw_components: list[str]) -> list[str]:
    normalized: list[str] = []
    unknown: list[str] = []
    for raw in raw_components:
        component = COMPONENT_LOOKUP.get(raw.casefold())
        if component is None:
            unknown.append(raw)
        else:
            normalized.append(component)

    if unknown:
        raise ValueError(
            f"Unknown components: {unknown}. Allowed values: {list(COMPONENTS)}"
        )
    if len(normalized) != len(set(normalized)):
        raise ValueError("Each component may be selected only once")
    if len(normalized) < MIN_COMPONENTS:
        raise ValueError(
            f"Select at least {MIN_COMPONENTS} distinct components; "
            f"received {len(normalized)}"
        )
    return normalized


def validate_dataset_name(name: str) -> None:
    if not name or name in {".", ".."}:
        raise ValueError("dataset-name must be a non-empty directory name")
    if name[-1] in {" ", "."}:
        raise ValueError("dataset-name may not end with a space or period")
    invalid = sorted(set(name) & INVALID_WINDOWS_NAME_CHARS)
    if invalid:
        raise ValueError(f"dataset-name contains invalid characters: {invalid}")
    if name.split(".", 1)[0].upper() in RESERVED_WINDOWS_NAMES:
        raise ValueError(f"dataset-name is reserved on Windows: {name}")


def validate_id_prefix(prefix: str) -> None:
    if not prefix or "\n" in prefix or "\r" in prefix:
        raise ValueError("id-prefix must be non-empty and contain no newlines")


def read_jsonl(path: Path) -> list[dict[str, object]]:
    rows: list[dict[str, object]] = []
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(),
        start=1,
    ):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as error:
            raise ValueError(f"Invalid JSON at {path}:{line_number}: {error}") from error
        if not isinstance(row, dict):
            raise ValueError(f"Expected a JSON object at {path}:{line_number}")
        missing_fields = [field for field in REQUIRED_RECORD_FIELDS if field not in row]
        if missing_fields:
            raise ValueError(
                f"Missing fields {missing_fields} at {path}:{line_number}"
            )
        rows.append(row)
    return rows


def read_task_registry(
    component: str,
    path: Path,
    valid_skill_dir_names: set[str],
) -> list[dict[str, str]]:
    if component not in EXPECTED_COMPONENT_LABEL:
        return []
    if not path.is_file():
        raise FileNotFoundError(
            f"{component} is missing {TASK_REGISTRY_FILENAME}: {path}"
        )
    expected_label = EXPECTED_COMPONENT_LABEL[component]
    valid_folded = {name.casefold() for name in valid_skill_dir_names}
    relations: list[dict[str, str]] = []
    seen: set[tuple[str, str, str]] = set()
    for line_number, line in enumerate(
        path.read_text(encoding="utf-8").splitlines(), start=1
    ):
        if not line.strip():
            continue
        try:
            row = json.loads(line)
        except json.JSONDecodeError as exc:
            raise ValueError(f"Invalid JSON at {path}:{line_number}: {exc}") from exc
        if not isinstance(row, dict):
            raise ValueError(f"Expected a JSON object at {path}:{line_number}")
        missing = [field for field in RELATION_FIELDS if field not in row]
        if missing:
            raise ValueError(f"Missing fields {missing} at {path}:{line_number}")
        task_id = str(row["task_id"]).strip()
        label = str(row["label"]).strip()
        skill_dir_name = str(row["skill_dir_name"]).strip()
        if not task_id or not skill_dir_name:
            raise ValueError(f"Empty Task-Skill relation at {path}:{line_number}")
        if label != expected_label:
            raise ValueError(
                f"{component} relation label must be {expected_label!r}, "
                f"got {label!r} at {path}:{line_number}"
            )
        if skill_dir_name.casefold() not in valid_folded:
            raise ValueError(
                f"Unknown skill_dir_name {skill_dir_name!r} at {path}:{line_number}"
            )
        key = (task_id, label, skill_dir_name.casefold())
        if key in seen:
            raise ValueError(f"Duplicate Task-Skill relation at {path}:{line_number}")
        seen.add(key)
        relations.append(
            {
                "task_id": task_id,
                "label": label,
                "skill_dir_name": skill_dir_name,
            }
        )
    if not relations:
        raise ValueError(f"{component}/{TASK_REGISTRY_FILENAME} contains no relations")
    return relations


def skill_md_sha256(skill_dir: Path) -> str:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        raise FileNotFoundError(f"Missing SKILL.md: {skill_md}")
    return hashlib.sha256(skill_md.read_bytes()).hexdigest()


def tree_sha256(skill_dir: Path) -> str:
    """Hash internal paths and contents, excluding the top-level directory name."""
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


def unique_destination_name(preferred: str, used_names: set[str]) -> str:
    candidate = preferred
    suffix = 2
    while candidate.casefold() in used_names:
        candidate = f"{preferred}--{suffix}"
        suffix += 1
    used_names.add(candidate.casefold())
    return candidate


def validate_component(
    component: str,
) -> tuple[list[dict[str, object]], Path, list[dict[str, str]]]:
    component_dir = BASE / component
    all_jsonl = component_dir / "All.jsonl"
    skills_dir = component_dir / "skills"

    if not all_jsonl.is_file():
        raise FileNotFoundError(f"{component} is missing All.jsonl: {all_jsonl}")
    if not skills_dir.is_dir():
        raise FileNotFoundError(f"{component} is missing skills/: {skills_dir}")

    rows = read_jsonl(all_jsonl)
    if not rows:
        raise ValueError(f"{component}/All.jsonl contains no records")

    record_names = [str(row["skill_dir_name"]) for row in rows]
    record_names_folded = [name.casefold() for name in record_names]
    if len(record_names_folded) != len(set(record_names_folded)):
        raise ValueError(f"{component}/All.jsonl has duplicate skill_dir_name values")

    disk_dirs = [path for path in skills_dir.iterdir() if path.is_dir()]
    disk_by_name = {path.name.casefold(): path for path in disk_dirs}
    if len(disk_by_name) != len(disk_dirs):
        raise ValueError(f"{component}/skills has case-insensitive name collisions")

    missing_on_disk = sorted(
        name for name in record_names if name.casefold() not in disk_by_name
    )
    extra_on_disk = sorted(
        path.name
        for path in disk_dirs
        if path.name.casefold() not in set(record_names_folded)
    )
    if missing_on_disk or extra_on_disk:
        raise ValueError(
            f"{component} metadata/directory mismatch: "
            f"missing_on_disk={missing_on_disk}, extra_on_disk={extra_on_disk}"
        )

    for name in record_names:
        skill_md_sha256(disk_by_name[name.casefold()])
    relations = read_task_registry(
        component,
        component_dir / TASK_REGISTRY_FILENAME,
        set(record_names),
    )
    return rows, skills_dir, relations


def is_within(path: Path, potential_parent: Path) -> bool:
    return path == potential_parent or potential_parent in path.parents


def write_jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    payload = "".join(
        json.dumps(row, ensure_ascii=False, separators=(",", ":")) + "\n"
        for row in rows
    )
    path.write_text(payload, encoding="utf-8", newline="\n")


def path_exists(path: Path) -> bool:
    """Return whether a path or symlink exists without following the symlink."""
    return path.exists() or path.is_symlink()


def rename_with_retry(source: Path, target: Path) -> None:
    """Rename one path, tolerating transient Windows file locks."""
    attempts = 8
    for attempt in range(1, attempts + 1):
        try:
            source.rename(target)
            return
        except PermissionError:
            if path_exists(target):
                raise FileExistsError(
                    f"Rename target already exists: {target}"
                )
            if attempt == attempts:
                raise
            time.sleep(1.0)


def remove_path_with_retry(path: Path) -> None:
    """Remove a file, symlink, or directory after retrying transient locks."""
    attempts = 8
    for attempt in range(1, attempts + 1):
        try:
            if path.is_symlink() or path.is_file():
                path.unlink()
            elif path.exists():
                shutil.rmtree(path)
            return
        except PermissionError:
            if attempt == attempts:
                raise
            time.sleep(1.0)


def commit_staging_directory(staging: Path, output_dir: Path) -> None:
    """Atomically rebuild output, restoring the old output if the swap fails."""
    backup: Path | None = None
    if path_exists(output_dir):
        backup = output_dir.with_name(
            f".{output_dir.name}.backup-{uuid.uuid4().hex}"
        )
        rename_with_retry(output_dir, backup)

    try:
        rename_with_retry(staging, output_dir)
    except Exception:
        if backup is not None and path_exists(backup) and not path_exists(output_dir):
            rename_with_retry(backup, output_dir)
        raise

    if backup is not None:
        try:
            remove_path_with_retry(backup)
        except PermissionError:
            print(
                "WARNING: Output was rebuilt, but the old backup could not be "
                f"removed: {backup}",
                file=sys.stderr,
            )


def main() -> int:
    args = parse_args()
    components = normalize_components(args.components)
    validate_dataset_name(args.dataset_name)
    id_prefix = args.id_prefix if args.id_prefix is not None else args.dataset_name
    validate_id_prefix(id_prefix)

    output_root = args.output_root.resolve()
    output_dir = output_root / args.dataset_name
    resolved_output_dir = output_dir.resolve(strict=False)

    validated: list[
        tuple[str, list[dict[str, object]], Path, list[dict[str, str]]]
    ] = []
    for component in components:
        rows, skills_dir, relations = validate_component(component)
        skills_resolved = skills_dir.resolve()
        if is_within(resolved_output_dir, skills_resolved):
            raise ValueError(
                f"Output dataset may not be created inside a source skills directory: "
                f"{skills_resolved}"
            )
        validated.append((component, rows, skills_resolved, relations))

    output_rows: list[dict[str, object]] = []
    copy_plan: list[tuple[Path, str, str]] = []
    used_destination_names: set[str] = set()
    input_counts: Counter[str] = Counter()
    kept_counts: Counter[str] = Counter()
    standard_random_duplicate_counts: Counter[str] = Counter()
    renamed_counts: Counter[str] = Counter()
    relation_counts: Counter[str] = Counter()
    source_to_output_position: dict[tuple[str, str], int] = {}

    standard_tree_hashes_by_skill_md: dict[str, set[str]] = {}
    if "Standard" in components and "Random_2K" in components:
        standard_rows, standard_skills_dir = next(
            (rows, skills_dir)
            for component, rows, skills_dir, _ in validated
            if component == "Standard"
        )
        standard_dirs = {
            path.name.casefold(): path
            for path in standard_skills_dir.iterdir()
            if path.is_dir()
        }
        for row in standard_rows:
            standard_dir = standard_dirs[str(row["skill_dir_name"]).casefold()]
            skill_md_hash = skill_md_sha256(standard_dir)
            standard_tree_hashes_by_skill_md.setdefault(skill_md_hash, set()).add(
                tree_sha256(standard_dir)
            )

    for component, rows, skills_dir, _ in validated:
        source_dirs = {
            path.name.casefold(): path
            for path in skills_dir.iterdir()
            if path.is_dir()
        }
        for original_row in rows:
            input_counts[component] += 1
            source_name = str(original_row["skill_dir_name"])
            source_dir = source_dirs[source_name.casefold()]
            source_skill_md_hash = skill_md_sha256(source_dir)
            if component == "Random_2K":
                matching_standard_trees = standard_tree_hashes_by_skill_md.get(
                    source_skill_md_hash
                )
                if (
                    matching_standard_trees
                    and tree_sha256(source_dir) in matching_standard_trees
                ):
                    standard_random_duplicate_counts[component] += 1
                    continue

            destination_name = unique_destination_name(
                source_name,
                used_destination_names,
            )
            if destination_name != source_name:
                renamed_counts[component] += 1

            row = dict(original_row)
            row["skill_dir_name"] = destination_name
            if not str(row.get("dataset_role", "")).strip():
                row["dataset_role"] = DEFAULT_ROLES[component]

            output_rows.append(row)
            source_to_output_position[(component, source_name.casefold())] = (
                len(output_rows) - 1
            )
            copy_plan.append(
                (source_dir, destination_name, source_skill_md_hash)
            )
            kept_counts[component] += 1

    for index, row in enumerate(output_rows, start=1):
        row["skill_id"] = f"{id_prefix}-{index}"

    output_relations: list[dict[str, object]] = []
    seen_output_relations: set[tuple[str, str, str]] = set()
    labels_by_task_and_skill: dict[tuple[str, str], str] = {}
    for component, _, _, relations in validated:
        for relation in relations:
            source_key = (component, relation["skill_dir_name"].casefold())
            try:
                output_row = output_rows[source_to_output_position[source_key]]
            except KeyError as exc:
                raise RuntimeError(
                    "Task-Skill relation points to a skill removed without a "
                    f"remapping rule: component={component}, relation={relation}"
                ) from exc
            task_id = relation["task_id"]
            label = relation["label"]
            skill_id = str(output_row["skill_id"])
            final_key = (task_id, label, skill_id)
            if final_key in seen_output_relations:
                continue
            task_skill_key = (task_id, skill_id)
            previous_label = labels_by_task_and_skill.get(task_skill_key)
            if previous_label is not None and previous_label != label:
                raise ValueError(
                    "Task label sets must be mutually exclusive: "
                    f"task={task_id}, skill_id={skill_id}, "
                    f"labels={previous_label},{label}"
                )
            labels_by_task_and_skill[task_skill_key] = label
            seen_output_relations.add(final_key)
            output_relations.append(
                {
                    "schema_version": 1,
                    "task_id": task_id,
                    "label": label,
                    "skill_id": skill_id,
                    "skill_dir_name": str(output_row["skill_dir_name"]),
                }
            )
            relation_counts[component] += 1
    output_relations.sort(
        key=lambda item: (
            str(item["task_id"]).casefold(),
            str(item["label"]).casefold(),
            str(item["skill_id"]).casefold(),
        )
    )

    print(f"components={','.join(components)}")
    for component in components:
        print(
            f"component={component} "
            f"input={input_counts[component]} "
            f"kept={kept_counts[component]} "
            f"standard_random_exact_duplicate_skipped="
            f"{standard_random_duplicate_counts[component]} "
            f"renamed={renamed_counts[component]} "
            f"task_skill_relations={relation_counts[component]}"
        )
    print(f"output_records={len(output_rows)}")
    print(f"output_task_skill_relations={len(output_relations)}")
    print(f"output_dataset={output_dir}")

    if args.dry_run:
        print("dry_run=true")
        return 0

    output_root.mkdir(parents=True, exist_ok=True)
    staging = Path(
        tempfile.mkdtemp(
            prefix=f".{args.dataset_name}.staging-",
            dir=output_root,
        )
    )
    try:
        staging_skills = staging / "skills"
        staging_skills.mkdir()
        for source_dir, destination_name, _ in copy_plan:
            shutil.copytree(source_dir, staging_skills / destination_name)
        write_jsonl(staging / "All.jsonl", output_rows)
        write_jsonl(staging / TASK_REGISTRY_FILENAME, output_relations)

        copied_dirs = {
            path.name.casefold(): path
            for path in staging_skills.iterdir()
            if path.is_dir()
        }
        expected_names = {
            str(row["skill_dir_name"]).casefold()
            for row in output_rows
        }
        if set(copied_dirs) != expected_names:
            raise RuntimeError("Output directory names do not match All.jsonl")
        for _, destination_name, expected_skill_md_hash in copy_plan:
            copied_dir = copied_dirs[destination_name.casefold()]
            if skill_md_sha256(copied_dir) != expected_skill_md_hash:
                raise RuntimeError(
                    f"Copied SKILL.md differs from source: {destination_name}"
                )

        commit_staging_directory(staging, output_dir)
    except Exception:
        if staging.exists():
            shutil.rmtree(staging)
        raise

    print(f"all_jsonl={output_dir / 'All.jsonl'}")
    print(f"task_skill_registry={output_dir / TASK_REGISTRY_FILENAME}")
    print(f"skills={output_dir / 'skills'}")
    print("dry_run=false")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (
        FileExistsError,
        FileNotFoundError,
        PermissionError,
        RuntimeError,
        ValueError,
    ) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        raise SystemExit(2)
