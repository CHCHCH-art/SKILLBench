#!/usr/bin/env python3
"""Validate the required SKILL.md structure and frontmatter."""

import argparse
import shutil
from pathlib import Path
from typing import Dict, List, Optional, Tuple

import yaml


def path_is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def split_frontmatter(text: str) -> Tuple[Optional[str], Optional[str], List[str]]:
    errors = []

    text = text.replace("\r\n", "\n").replace("\r", "\n")

    if not text.startswith("---\n"):
        return None, None, ["missing_yaml_frontmatter_start"]

    lines = text.split("\n")
    end_idx = None

    for i in range(1, len(lines)):
        if lines[i].strip() == "---":
            end_idx = i
            break

    if end_idx is None:
        return None, None, ["missing_yaml_frontmatter_end"]

    yaml_text = "\n".join(lines[1:end_idx])
    body = "\n".join(lines[end_idx + 1:])

    return yaml_text, body, errors


def validate_skill(skill_md_path: Path, root: Path) -> Dict:
    skill_dir = skill_md_path.parent
    parent_dir_name = skill_dir.name.strip()

    result = {
        "skill_dir": skill_dir,
        "path": str(skill_md_path.relative_to(root)),
        "skill_relative_dir": str(skill_dir.relative_to(root)),
        "parent_dir": parent_dir_name,
        "name": "",
        "valid": False,
        "errors": [],
    }

    try:
        text = skill_md_path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        try:
            text = skill_md_path.read_text(encoding="utf-8-sig")
        except Exception as e:
            result["errors"].append(f"read_error:{type(e).__name__}")
            return result
    except Exception as e:
        result["errors"].append(f"read_error:{type(e).__name__}")
        return result

    yaml_text, body, fm_errors = split_frontmatter(text)
    result["errors"].extend(fm_errors)

    if yaml_text is None:
        return result

    try:
        metadata = yaml.safe_load(yaml_text)
    except Exception as e:
        result["errors"].append(f"yaml_parse_error:{type(e).__name__}")
        return result

    if not isinstance(metadata, dict):
        result["errors"].append("frontmatter_not_mapping")
        return result

    name = metadata.get("name")
    description = metadata.get("description")

    # name is reported but does not affect L1 validity.
    if isinstance(name, str):
        result["name"] = name.strip()

    if description is None:
        result["errors"].append("missing_description")
    elif not isinstance(description, str):
        result["errors"].append("description_not_string")
    else:
        description = description.strip()

        if not (1 <= len(description) <= 1024):
            result["errors"].append("description_length_invalid")

    if body is None or not body.strip():
        result["errors"].append("empty_markdown_body")

    result["valid"] = len(result["errors"]) == 0
    return result


def scan(root: Path, invalid_dir: Optional[Path] = None) -> List[Dict]:
    skill_md_files = sorted(root.rglob("SKILL.md"))

    filtered_files = []

    for skill_md_path in skill_md_files:
        if invalid_dir is not None and path_is_relative_to(skill_md_path, invalid_dir):
            continue
        filtered_files.append(skill_md_path)

    results = []
    for skill_md_path in filtered_files:
        results.append(validate_skill(skill_md_path, root))

    return results


def get_unique_destination(dest: Path) -> Path:
    if not dest.exists():
        return dest

    base = dest
    idx = 1

    while True:
        candidate = Path(f"{base}__dup{idx}")
        if not candidate.exists():
            return candidate
        idx += 1


def move_invalid_skills(
    results: List[Dict],
    root: Path,
    invalid_dir: Path,
    dry_run: bool = False,
) -> None:
    invalid_dir.mkdir(parents=True, exist_ok=True)

    invalid_results = [r for r in results if not r["valid"]]

    print("\n" + "=" * 80)
    print("Move Invalid Skills")
    print("=" * 80)

    if not invalid_results:
        print("No invalid skills to move.")
        return

    moved_count = 0
    skipped_count = 0

    for r in invalid_results:
        src_dir: Path = r["skill_dir"]

        if not src_dir.exists():
            print(f"[SKIP] Source no longer exists: {src_dir}")
            skipped_count += 1
            continue

        if path_is_relative_to(invalid_dir, src_dir):
            print(f"[SKIP] Invalid dir is inside source skill dir, unsafe move: {src_dir}")
            skipped_count += 1
            continue

        try:
            relative_dir = src_dir.relative_to(root)
        except ValueError:
            relative_dir = Path(src_dir.name)

        if str(relative_dir) == ".":
            relative_dir = Path(src_dir.name)

        dest_dir = invalid_dir / relative_dir
        dest_dir = get_unique_destination(dest_dir)

        print(f"\n[INVALID] {r['name'] or '[no valid name]'}")
        print(f"From: {src_dir}")
        print(f"To:   {dest_dir}")
        print("Errors:")
        for err in r["errors"]:
            print(f"  - {err}")

        if dry_run:
            print("Action: dry-run, not moved.")
            continue

        dest_dir.parent.mkdir(parents=True, exist_ok=True)
        shutil.move(str(src_dir), str(dest_dir))
        print("Action: moved.")
        moved_count += 1

    print("\n" + "-" * 80)
    print(f"Moved invalid skills: {moved_count}")
    print(f"Skipped: {skipped_count}")
    if dry_run:
        print("Dry-run mode enabled. No files were moved.")


def print_report(results: List[Dict]) -> None:
    total = len(results)
    valid = sum(1 for r in results if r["valid"])
    invalid = total - valid

    print("=" * 80)
    print("L1 Agent Skill Compliance Report")
    print("=" * 80)
    print(f"Total SKILL.md files found: {total}")
    print(f"Valid skills: {valid}")
    print(f"Invalid skills: {invalid}")

    if total > 0:
        print(f"Valid ratio: {valid / total:.2%}")

    print("\n" + "=" * 80)
    print("Invalid Skills")
    print("=" * 80)

    if invalid == 0:
        print("No invalid skills found.")
    else:
        display_idx = 1

        for r in results:
            if r["valid"]:
                continue

            display_name = r["name"] or f"[no valid name] parent_dir={r['parent_dir']}"

            print(f"\n[{display_idx}] {display_name}")
            print(f"Parent dir: {r['parent_dir']}")
            print(f"Path: {r['path']}")
            print("Errors:")
            for err in r["errors"]:
                print(f"  - {err}")

            display_idx += 1

    error_counter = {}

    for r in results:
        for err in r["errors"]:
            error_counter[err] = error_counter.get(err, 0) + 1

    print("\n" + "=" * 80)
    print("Error Summary")
    print("=" * 80)

    if not error_counter:
        print("No errors.")
    else:
        for err, count in sorted(error_counter.items(), key=lambda x: x[1], reverse=True):
            print(f"{err}: {count}")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("root", help="Root directory containing skill folders")
    parser.add_argument(
        "--invalid-dir",
        default=None,
        help="Directory to move invalid skill folders into",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Print move operations without actually moving folders",
    )

    args = parser.parse_args()

    root = Path(args.root).resolve()

    if not root.exists():
        raise FileNotFoundError(f"Root path does not exist: {root}")

    if not root.is_dir():
        raise NotADirectoryError(f"Root path is not a directory: {root}")

    invalid_dir = Path(args.invalid_dir).resolve() if args.invalid_dir else None

    if invalid_dir is not None and invalid_dir == root:
        raise ValueError("invalid-dir cannot be the same as root.")

    results = scan(root, invalid_dir=invalid_dir)
    print_report(results)

    if invalid_dir is not None:
        move_invalid_skills(
            results=results,
            root=root,
            invalid_dir=invalid_dir,
            dry_run=args.dry_run,
        )


if __name__ == "__main__":
    main()
