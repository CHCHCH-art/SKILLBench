#!/usr/bin/env python
"""Normalize and merge per-skill metadata, optionally without LLM labels."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any


SKILL_JSON_NAME = "skill_llm_describe.json"
BASE_DESCRIBE_NAME = "Base Describe.md"
OUTPUT_NAME = "All_Desc.jsonl"

SKILL_FIELDS = (
    "task_tags",
    "service_cost_score",
    "service_safety_score",
)

BASE_FIELDS = (
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
)

EXTRA_EMPTY_FIELDS = (
    "version_or_commit",
    "dataset_role",
    "notes",
)

ARRAY_FIELDS = {
    "task_tags",
}


def clean_input_path(raw: str) -> Path:
    raw = raw.strip().strip('"').strip("'")
    return Path(raw).expanduser().resolve()


def load_skill_json(path: Path) -> tuple[dict[str, Any] | None, list[str]]:
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except Exception as exc:
        return None, [f"skill_json_read_or_parse_error:{type(exc).__name__}"]

    if not isinstance(data, dict):
        return None, ["skill_json_root_not_object"]

    errors: list[str] = []
    for field in SKILL_FIELDS:
        if field not in data:
            errors.append(f"missing_skill_field:{field}")

    for field in sorted(set(data) - set(SKILL_FIELDS)):
        errors.append(f"extra_skill_field:{field}")

    for field in ARRAY_FIELDS:
        if field in data and not isinstance(data[field], list):
            errors.append(f"{field}_not_array")

    for field in ("service_cost_score", "service_safety_score"):
        if field in data and isinstance(data[field], bool):
            errors.append(f"{field}_not_integer")
        elif field in data and not isinstance(data[field], (int, str)):
            errors.append(f"{field}_not_integer_or_numeric_string")

    if errors:
        return None, errors

    return data, []


def parse_base_describe(path: Path) -> tuple[dict[str, Any], list[str]]:
    try:
        text = path.read_text(encoding="utf-8")
    except UnicodeDecodeError:
        text = path.read_text(encoding="utf-8-sig")

    parsed: dict[str, Any] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue

        key, value = line.split(":", 1)
        key = key.strip()
        if key in BASE_FIELDS:
            parsed[key] = coerce_base_value(key, value.strip())

    warnings: list[str] = []
    for field in BASE_FIELDS:
        if field not in parsed:
            warnings.append(f"missing_base_field:{field}")
            parsed[field] = ""

    return parsed, warnings


def coerce_base_value(key: str, value: str) -> Any:
    if key in {"num_files", "num_scripts"}:
        try:
            return int(value)
        except ValueError:
            return value

    if key == "total_size_kb":
        try:
            return float(value)
        except ValueError:
            return value

    return value


def normalize_score(value: Any, field: str) -> tuple[int | None, str | None, bool]:
    if isinstance(value, bool):
        return None, f"{field}_not_integer", False

    if isinstance(value, int):
        score = value
        changed = False
    elif isinstance(value, str) and re.fullmatch(r"[1-9]\d*", value.strip()):
        score = int(value.strip())
        changed = True
    else:
        return None, f"{field}_not_positive_integer", False

    if not (1 <= score <= 10):
        return None, f"{field}_out_of_range:{score}", changed

    return score, None, changed


def normalize_skill_record(data: dict[str, Any]) -> tuple[dict[str, Any], Counter[str], list[str]]:
    normalized = dict(data)
    normalization_counts: Counter[str] = Counter()
    errors: list[str] = []

    task_tags: list[str] = []
    for idx, value in enumerate(normalized["task_tags"]):
        if not isinstance(value, str):
            errors.append(f"task_tags_item_not_string:{idx}")
            continue

        clean_value = value.strip().lower()
        task_tags.append(clean_value)
        if clean_value != value:
            normalization_counts["task_tags"] += 1
    normalized["task_tags"] = task_tags

    for field in ("service_cost_score", "service_safety_score"):
        score, error, changed = normalize_score(normalized[field], field)
        if error:
            errors.append(error)
            continue
        normalized[field] = score
        if changed:
            normalization_counts[field] += 1

    return normalized, normalization_counts, errors


def build_merged_record(
    base_data: dict[str, Any],
    skill_data: dict[str, Any] | None = None,
) -> dict[str, Any]:
    record: dict[str, Any] = {}

    if skill_data is not None:
        for field in SKILL_FIELDS:
            record[field] = skill_data.get(field, "")

    for field in BASE_FIELDS:
        record[field] = base_data.get(field, "")

    for field in EXTRA_EMPTY_FIELDS:
        record[field] = ""

    return record


def iter_skill_dirs(root: Path):
    for child in sorted(root.iterdir(), key=lambda p: p.name.lower()):
        if child.is_dir():
            yield child


def process_folder(
    folder: Path,
    dry_run: bool = False,
    include_llm: bool = True,
) -> dict[str, Any]:
    skill_path = folder / SKILL_JSON_NAME
    base_path = folder / BASE_DESCRIBE_NAME
    output_path = folder / OUTPUT_NAME

    result: dict[str, Any] = {
        "folder": str(folder),
        "include_llm": include_llm,
        "status": "",
        "skill_id": "",
        "normalizations": {},
        "warnings": [],
        "errors": [],
    }

    if not base_path.is_file() or (include_llm and not skill_path.is_file()):
        result["status"] = "skipped_missing_inputs"
        if include_llm and not skill_path.is_file():
            result["warnings"].append(f"missing:{SKILL_JSON_NAME}")
        if not base_path.is_file():
            result["warnings"].append(f"missing:{BASE_DESCRIBE_NAME}")
        return result

    normalized_skill: dict[str, Any] | None = None
    normalization_counts: Counter[str] = Counter()
    if include_llm:
        skill_data, skill_errors = load_skill_json(skill_path)
        if skill_data is None:
            result["status"] = "error"
            result["errors"].extend(skill_errors)
            return result

        normalized_skill, normalization_counts, normalization_errors = normalize_skill_record(skill_data)
        if normalization_errors:
            result["status"] = "error"
            result["errors"].extend(normalization_errors)
            return result

    base_data, base_warnings = parse_base_describe(base_path)
    result["warnings"].extend(base_warnings)

    base_skill_id = str(base_data.get("skill_id", "")).strip()
    result["skill_id"] = base_skill_id

    record = build_merged_record(base_data, normalized_skill)
    result["normalizations"] = dict(normalization_counts)

    if not dry_run:
        output_path.write_text(
            json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n",
            encoding="utf-8",
        )

    if include_llm:
        result["status"] = "merged_dry_run" if dry_run else "merged"
    else:
        result["status"] = "merged_base_only_dry_run" if dry_run else "merged_base_only"
    result["output"] = str(output_path)
    return result


def process_root(
    root: Path,
    dry_run: bool = False,
    include_llm: bool = True,
) -> dict[str, Any]:
    results = [
        process_folder(folder, dry_run=dry_run, include_llm=include_llm)
        for folder in iter_skill_dirs(root)
    ]
    status_counts = Counter(result["status"] for result in results)
    normalization_counts: Counter[str] = Counter()

    for result in results:
        normalization_counts.update(result.get("normalizations", {}))

    return {
        "root": str(root),
        "dry_run": dry_run,
        "include_llm": include_llm,
        "folders_seen": len(results),
        "status_counts": dict(sorted(status_counts.items())),
        "normalization_counts": dict(sorted(normalization_counts.items())),
        "results": results,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Merge skill_llm_describe.json and Base Describe.md into All_Desc.jsonl."
    )
    parser.add_argument(
        "root",
        nargs="?",
        help=(
            "Root directory whose first-level child folders contain Base Describe.md "
            "and, unless --no_llm is used, skill_llm_describe.json."
        ),
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Validate and report what would be written without creating All_Desc.jsonl.",
    )
    parser.add_argument(
        "--no_llm",
        "--no-llm",
        dest="no_llm",
        action="store_true",
        help=(
            "Build records only from Base Describe.md. Ignore any existing "
            "skill_llm_describe.json and omit LLM label fields."
        ),
    )
    parser.add_argument(
        "--report",
        help="Optional JSON summary report output path.",
    )
    parser.add_argument(
        "--max-errors",
        type=int,
        default=50,
        help="Maximum error/warning folders to print. The JSON report contains all details.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = clean_input_path(args.root or input("Please enter root directory: "))

    if not root.is_dir():
        print(f"Root directory does not exist: {root}", file=sys.stderr)
        return 2

    summary = process_root(root, dry_run=args.dry_run, include_llm=not args.no_llm)

    print(f"Root: {summary['root']}")
    print(f"Folders seen: {summary['folders_seen']}")
    print("Status counts:")
    for status, count in summary["status_counts"].items():
        print(f"  {status}: {count}")

    if summary["normalization_counts"]:
        print("Normalization counts:")
        for field, count in summary["normalization_counts"].items():
            print(f"  {field}: {count}")

    problem_results = [
        result
        for result in summary["results"]
        if result["status"] == "error" or result["warnings"]
    ]

    if problem_results and args.max_errors != 0:
        to_print = problem_results
        if args.max_errors > 0:
            to_print = to_print[: args.max_errors]

        print("Warnings/errors:")
        for result in to_print:
            folder_name = Path(result["folder"]).name
            messages = [*result["errors"], *result["warnings"]]
            print(f"  {folder_name}: {', '.join(messages)}")

        remaining = len(problem_results) - len(to_print)
        if remaining > 0:
            print(f"  ... {remaining} more omitted; use --report for full details.")

    if args.report:
        report_path = clean_input_path(args.report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(summary, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"Report written: {report_path}")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
