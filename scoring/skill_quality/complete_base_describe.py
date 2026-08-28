#!/usr/bin/env python
"""Generate Base Describe.md metadata for first-level skill folders."""

from __future__ import annotations

import argparse
import json
import os
import re
from pathlib import Path


SCRIPT_EXTENSIONS = {
    ".bash",
    ".bat",
    ".c",
    ".cjs",
    ".cmd",
    ".cpp",
    ".cs",
    ".go",
    ".h",
    ".hpp",
    ".java",
    ".js",
    ".jsx",
    ".kt",
    ".lua",
    ".mjs",
    ".php",
    ".pl",
    ".ps1",
    ".py",
    ".rb",
    ".rs",
    ".sh",
    ".swift",
    ".ts",
    ".tsx",
}

CORE_INSTRUCTION_FILENAMES = {
    "agents.md",
    "base describe.md",
    "license",
    "license.md",
    "license.txt",
    "readme.md",
    "skill.md",
}


def read_key_values(path: Path) -> dict[str, str]:
    if not path.is_file():
        return {}

    values: dict[str, str] = {}
    for line in path.read_text(encoding="utf-8", errors="replace").splitlines():
        if ":" not in line or line.lstrip().startswith("#"):
            continue
        key, value = line.split(":", 1)
        values[key.strip()] = value.strip()
    return values


def extract_frontmatter_field(skill_md: Path, field_name: str) -> str:
    if not skill_md.is_file():
        return ""

    text = skill_md.read_text(encoding="utf-8", errors="replace")
    match = re.match(r"^---\s*\n(.*?)\n---\s*", text, flags=re.DOTALL)
    if not match:
        return ""

    frontmatter = match.group(1)
    lines = frontmatter.splitlines()
    field_lines: list[str] = []
    capturing = False
    base_indent = 0

    for line in lines:
        if not capturing:
            field_match = re.match(
                rf"^{re.escape(field_name)}\s*:\s*(.*)$", line
            )
            if not field_match:
                continue
            value = field_match.group(1).strip()
            if value in {"|", ">"}:
                capturing = True
                base_indent = 1
                continue
            return value.strip().strip('"').strip("'")

        if re.match(r"^[A-Za-z0-9_-]+\s*:", line):
            break
        if line.strip():
            field_lines.append(line[base_indent:].strip())

    return " ".join(field_lines).strip().strip('"').strip("'")


def get_skill_name(skill_dir: Path, skill_md: Path) -> str:
    return extract_frontmatter_field(skill_md, "name") or skill_dir.name


def relative_posix_path(base: Path, path: Path) -> str:
    return path.relative_to(base).as_posix()


def is_script_file(path: Path) -> bool:
    return path.suffix.lower() in SCRIPT_EXTENSIONS


def is_core_instruction_file(path: Path) -> bool:
    return path.name.lower() in CORE_INSTRUCTION_FILENAMES


def collect_stats(skill_dir: Path) -> dict[str, object]:
    files: list[Path] = []
    total_size = 0

    for root, _, filenames in os.walk(skill_dir):
        root_path = Path(root)
        for filename in filenames:
            path = root_path / filename
            files.append(path)
            try:
                total_size += path.stat().st_size
            except OSError:
                pass

    source_paths = sorted(
        relative_posix_path(skill_dir, path) for path in files if is_script_file(path)
    )
    resource_paths = sorted(
        relative_posix_path(skill_dir, path)
        for path in files
        if not is_script_file(path) and not is_core_instruction_file(path)
    )

    has_scripts = bool(source_paths)
    has_resources = bool(resource_paths)
    if has_scripts and has_resources:
        execution_type = "instruction+script+resource"
    elif has_scripts:
        execution_type = "instruction+script"
    elif has_resources:
        execution_type = "instruction+resource"
    else:
        execution_type = "instruction-only"

    return {
        "num_files": len(files),
        "num_scripts": len(source_paths),
        "total_size_kb": f"{total_size / 1024:.1f}",
        "source_files_included": "yes" if source_paths else "no",
        "source_files_path": "; ".join(source_paths),
        "execution_type": execution_type,
    }


def write_base_describe(path: Path, row: dict[str, str]) -> None:
    fields = [
        "skill_id",
        "skill_name",
        "skill_dir_name",
        "source_platform",
        "source_type",
        "source_url",
        "license",
        "num_files",
        "num_scripts",
        "total_size_kb",
        "source_files_included",
        "source_files_path",
        "execution_type",
        "redistribution_status",
        "has_skill_md",
        "frontmatter_description",
    ]
    content = ["# Base Describe", ""]
    content.extend(f"{field}: {row[field]}" for field in fields)
    content.append("")
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        handle.write("\n".join(content))


def write_jsonl(path: Path, rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8", newline="\n") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=False, sort_keys=True) + "\n")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--skills-dir",
        type=Path,
        default=Path(__file__).with_name("skills"),
        help="Directory containing skill folders.",
    )
    parser.add_argument(
        "--base-describe",
        type=Path,
        help="Optional common Base Describe.md to inherit source fields from.",
    )
    parser.add_argument(
        "--skill-id-prefix",
        default="34k",
        help="Prefix for generated skill_id values.",
    )
    parser.add_argument(
        "--discover-by-skill-md",
        action="store_true",
        help="Use every recursive SKILL.md parent directory as a skill folder.",
    )
    parser.add_argument(
        "--out-prefix",
        type=Path,
        default=Path(__file__).with_name("base_describe_index"),
        help="Output prefix for aggregate JSONL file.",
    )
    args = parser.parse_args()

    common_base = read_key_values(args.base_describe) if args.base_describe else {}

    if args.discover_by_skill_md:
        skill_dirs = sorted(
            {path.parent for path in args.skills_dir.rglob("SKILL.md")},
            key=lambda path: path.relative_to(args.skills_dir).as_posix().lower(),
        )
    else:
        skill_dirs = sorted(
            [path for path in args.skills_dir.iterdir() if path.is_dir()],
            key=lambda path: path.name.lower(),
        )

    rows: list[dict[str, str]] = []

    for index, skill_dir in enumerate(skill_dirs, start=1):
        base_describe = skill_dir / "Base Describe.md"
        existing = read_key_values(base_describe)
        source_fields = {**existing, **common_base}
        skill_md = skill_dir / "SKILL.md"
        stats = collect_stats(skill_dir)

        row = {
            "skill_id": f"{args.skill_id_prefix}-{index}",
            "skill_name": get_skill_name(skill_dir, skill_md),
            "skill_dir_name": skill_dir.name,
            "source_platform": source_fields.get("source_platform", "Github"),
            "source_type": source_fields.get("source_type", "community"),
            "source_url": source_fields.get(
                "source_url", source_fields.get("source_repository_http", "")
            ),
            "license": source_fields.get("license", "UNKNOWN"),
            "num_files": str(stats["num_files"]),
            "num_scripts": str(stats["num_scripts"]),
            "total_size_kb": str(stats["total_size_kb"]),
            "source_files_included": str(stats["source_files_included"]),
            "source_files_path": str(stats["source_files_path"]),
            "execution_type": str(stats["execution_type"]),
            "redistribution_status": "source-included",
            "has_skill_md": "yes" if skill_md.is_file() else "no",
            "frontmatter_description": extract_frontmatter_field(skill_md, "description"),
        }
        write_base_describe(base_describe, row)
        rows.append(row)

    write_jsonl(args.out_prefix.with_suffix(".jsonl"), rows)

    summary = {
        "skill_count": len(rows),
        "with_skill_md": sum(1 for row in rows if row["has_skill_md"] == "yes"),
        "with_source_files": sum(
            1 for row in rows if row["source_files_included"] == "yes"
        ),
        "output_jsonl": str(args.out_prefix.with_suffix(".jsonl")),
    }
    print(json.dumps(summary, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
