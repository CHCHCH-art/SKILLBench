#!/usr/bin/env python3
"""Select a reproducible exact-unique 2K sample from the archived 34K pool."""

from __future__ import annotations

import argparse
import hashlib
import os
import random
import shutil
import uuid
from collections import defaultdict
from pathlib import Path


REPO_ROOT = Path(__file__).resolve().parents[3]
SOURCE_SKILLS = (
    REPO_ROOT
    / "archive_local"
    / "ALL-34K-SKILLS"
    / "skills-34k"
    / "skills"
)
TARGET = Path(__file__).resolve().parent / "skills"
STAGING = TARGET.with_name("skills.__staging__")
EXCLUDE_SKILLS = Path(__file__).resolve().parent / "Exclude_SKILLS"
SAMPLE_SIZE = 2000
RANDOM_SEED = 20260805

# Preserve the archived source directory name for deterministic sampling, but
# materialize this known Codex-incompatible Skill under its canonical name.
# Codex requires both the directory name and the SKILL.md frontmatter name to
# be shorter than 64 characters.
SKILL_NAME_OVERRIDES = {
    "fatfingererr--analyze-high-unemployment-high-gdp-growth-fiscal-deficit-scenarios": (
        "fatfingererr-fiscal-deficit-scenarios"
    ),
}


def destination_name(skill_dir: Path) -> str:
    """Return the canonical directory name used in the generated sample."""
    return SKILL_NAME_OVERRIDES.get(skill_dir.name, skill_dir.name)


def normalize_copied_skill(source: Path, destination: Path) -> None:
    """Apply the declared name correction to all UTF-8 text after copying."""
    canonical_name = destination_name(source)
    if canonical_name == source.name:
        return
    source_frontmatter = source.name.split("--", maxsplit=1)[-1]
    replacements = 0
    for path in sorted(item for item in destination.rglob("*") if item.is_file()):
        try:
            content = path.read_text(encoding="utf-8")
        except UnicodeDecodeError:
            continue
        count = content.count(source_frontmatter)
        if count:
            path.write_text(
                content.replace(source_frontmatter, canonical_name),
                encoding="utf-8",
            )
            replacements += count
    if replacements == 0:
        raise RuntimeError(
            f"Cannot normalize Skill frontmatter for {source.name}: "
            f"no {source_frontmatter!r} references were found"
        )
    skill_md.write_text(content.replace(expected, replacement), encoding="utf-8")

def skill_md_sha256(skill_dir: Path) -> str:
    skill_md = skill_dir / "SKILL.md"
    if not skill_md.is_file():
        raise FileNotFoundError(f"Missing SKILL.md: {skill_md}")
    return hashlib.sha256(skill_md.read_bytes()).hexdigest()


def tree_sha256(skill_dir: Path) -> str:
    """Hash the internal tree without including the top-level directory name."""
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


def registered_exclusion_names() -> set[str]:
    if not EXCLUDE_SKILLS.is_dir():
        raise FileNotFoundError(
            f"Random_2K exclusion registry not found: {EXCLUDE_SKILLS}"
        )
    exclusions = sorted(
        (path for path in EXCLUDE_SKILLS.iterdir() if path.is_dir()),
        key=lambda path: (path.name.casefold(), path.name),
    )
    missing_skill_md = [
        path.name for path in exclusions if not (path / "SKILL.md").is_file()
    ]
    if missing_skill_md:
        raise RuntimeError(
            "Registered Random_2K exclusions have no root SKILL.md: "
            + ", ".join(missing_skill_md)
        )
    if not exclusions:
        raise RuntimeError(f"Random_2K exclusion registry is empty: {EXCLUDE_SKILLS}")
    return {path.name.casefold() for path in exclusions}


def collect_candidates(excluded_names: set[str]) -> list[Path]:
    if not SOURCE_SKILLS.is_dir():
        raise FileNotFoundError(f"34K source skills directory not found: {SOURCE_SKILLS}")
    all_candidates = sorted(
        (path for path in SOURCE_SKILLS.iterdir() if path.is_dir()),
        key=lambda path: (path.name.casefold(), path.name),
    )
    available_names = {path.name.casefold() for path in all_candidates}
    missing_exclusions = sorted(excluded_names - available_names)
    if missing_exclusions:
        raise RuntimeError(
            "Required Random_2K exclusions were not found in the 34K pool: "
            + ", ".join(missing_exclusions)
        )
    candidates = [
        path for path in all_candidates if path.name.casefold() not in excluded_names
    ]
    if not candidates:
        raise RuntimeError(f"No source skill directories found: {SOURCE_SKILLS}")
    return candidates


def exact_unique(candidates: list[Path]) -> list[Path]:
    by_skill_md: dict[str, list[Path]] = defaultdict(list)
    for skill_dir in candidates:
        by_skill_md[skill_md_sha256(skill_dir)].append(skill_dir)

    selected: list[Path] = []
    for group in by_skill_md.values():
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
    selected.sort(key=lambda path: (path.name.casefold(), path.name))
    return selected


def select_sample(unique_candidates: list[Path]) -> list[Path]:
    if len(unique_candidates) < SAMPLE_SIZE:
        raise RuntimeError(
            f"Need at least {SAMPLE_SIZE} unique skills, found {len(unique_candidates)}"
        )
    rng = random.Random(RANDOM_SEED)
    selected = rng.sample(unique_candidates, SAMPLE_SIZE)
    selected.sort(key=lambda path: (path.name.casefold(), path.name))
    return selected


def validate_destination_names(selected: list[Path]) -> None:
    folded: dict[str, str] = {}
    for source in selected:
        name = destination_name(source)
        if len(name) >= 64:
            raise RuntimeError(
                f"Selected Skill name exceeds Codex's 64-character limit: {name}"
            )
        previous = folded.setdefault(name.casefold(), name)
        if previous != name:
            raise RuntimeError(
                f"Selected skills have a case-insensitive name collision: "
                f"{previous} / {name}"
            )


def selection_sha256(selected: list[Path]) -> str:
    payload = "".join(f"{path.name}\n" for path in selected).encode("utf-8")
    return hashlib.sha256(payload).hexdigest()


def copy_sample(selected: list[Path]) -> None:
    if STAGING.exists():
        raise RuntimeError(f"Staging directory already exists: {STAGING}")
    STAGING.mkdir()
    try:
        expected_hashes: dict[str, str] = {}
        for source in selected:
            destination = STAGING / destination_name(source)
            shutil.copytree(source, destination, symlinks=True)
            normalize_copied_skill(source, destination)
            expected_hashes[source.name.casefold()] = tree_sha256(source)

        copied = sorted(
            (path for path in STAGING.iterdir() if path.is_dir()),
            key=lambda path: (path.name.casefold(), path.name),
        )
        if len(copied) != SAMPLE_SIZE:
            raise RuntimeError(
                f"Copied directory count differs from {SAMPLE_SIZE}: {len(copied)}"
            )
        for destination in copied:
            if destination.name not in SKILL_NAME_OVERRIDES.values():
                expected = expected_hashes[destination.name.casefold()]
                if tree_sha256(destination) != expected:
                    raise RuntimeError(
                        f"Copied skill differs from source: {destination.name}"
                    )

        backup = TARGET.with_name(f"skills.__backup__-{uuid.uuid4().hex}")
        if TARGET.exists():
            TARGET.replace(backup)
        try:
            STAGING.replace(TARGET)
        except Exception:
            if backup.exists() and not TARGET.exists():
                backup.replace(TARGET)
            raise
        if backup.exists():
            shutil.rmtree(backup)
    except Exception:
        if STAGING.exists():
            shutil.rmtree(STAGING)
        raise


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Select and copy a reproducible exact-unique Random 2K subset."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and select without replacing Random_2K/skills.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    excluded_names = registered_exclusion_names()
    candidates = collect_candidates(excluded_names)
    unique_candidates = exact_unique(candidates)
    selected = select_sample(unique_candidates)
    validate_destination_names(selected)

    if not args.dry_run:
        copy_sample(selected)

    print(f"source={SOURCE_SKILLS}")
    print(f"exclusion_registry={EXCLUDE_SKILLS}")
    print(f"candidate_skills={len(candidates)}")
    print(f"registered_skills_excluded={len(excluded_names)}")
    print(f"duplicate_candidates_removed={len(candidates) - len(unique_candidates)}")
    print(f"unique_candidates={len(unique_candidates)}")
    print(f"random_seed={RANDOM_SEED}")
    print(f"selected_skills={len(selected)}")
    print(f"selection_sha256={selection_sha256(selected)}")
    print(f"first_selected={selected[0].name}")
    print(f"last_selected={selected[-1].name}")
    print(f"target={TARGET}")
    print(f"dry_run={str(args.dry_run).lower()}")


if __name__ == "__main__":
    main()
