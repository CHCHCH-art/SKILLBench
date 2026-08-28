#!/usr/bin/env python
"""Validate first-level skill_llm_describe.json files."""

from __future__ import annotations

import argparse
import json
import re
import sys
from collections import Counter
from pathlib import Path
from typing import Any


INPUT_NAME = "skill_llm_describe.json"

REQUIRED_FIELDS = (
    "task_tags",
    "service_cost_score",
    "service_safety_score",
)

TASK_TAG_MIN_COUNT = 3
TASK_TAG_MAX_COUNT = 8
ARRAY_FIELDS = {
    "task_tags",
}

SCORE_FIELDS = {
    "service_cost_score",
    "service_safety_score",
}


def clean_input_path(raw: str) -> Path:
    raw = raw.strip().strip('"').strip("'")
    return Path(raw).expanduser().resolve()


def has_subject_action_shape(value: str) -> bool:
    match = re.fullmatch(r"<(.+)>-<(.+)>", value)
    return bool(match and match.group(1).strip() and match.group(2).strip())


def validate_task_tag_value(value: str) -> list[str]:
    issues: list[str] = []

    if value != value.strip():
        issues.append("task_tags_item_has_surrounding_whitespace")

    stripped = value.strip()
    if not has_subject_action_shape(stripped):
        issues.append("task_tags_item_invalid_subject_action_format")

    return issues


def validate_task_tags(
    data: dict[str, Any],
    errors: list[str],
) -> list[dict[str, Any]]:
    values = data.get("task_tags")
    if not isinstance(values, list):
        return []

    issues: list[dict[str, Any]] = []
    if not (TASK_TAG_MIN_COUNT <= len(values) <= TASK_TAG_MAX_COUNT):
        errors.append(f"task_tags_count_out_of_range:{len(values)}")

    seen: dict[str, int] = {}
    for idx, value in enumerate(values):
        if not isinstance(value, str):
            continue

        if value in seen:
            errors.append(f"task_tags_duplicate_value:{value}")
            issues.append(
                {
                    "index": idx,
                    "tag": value,
                    "issues": ["task_tags_duplicate_value"],
                    "first_index": seen[value],
                }
            )
            continue

        seen[value] = idx
        tag_issues = validate_task_tag_value(value)
        if not tag_issues:
            continue

        errors.extend(f"{issue}:{value}" for issue in tag_issues)
        issues.append(
            {
                "index": idx,
                "tag": value,
                "issues": tag_issues,
            }
        )

    return issues


def validate_string_list(
    data: dict[str, Any],
    field: str,
    errors: list[str],
) -> None:
    values = data.get(field)
    if not isinstance(values, list):
        return

    for idx, value in enumerate(values):
        if not isinstance(value, str):
            errors.append(f"{field}_item_not_string:{idx}")
            continue

        if not value.strip():
            errors.append(f"{field}_item_empty:{idx}")


def validate_score(
    data: dict[str, Any],
    field: str,
    errors: list[str],
) -> None:
    if field not in data:
        return

    value = data[field]
    if isinstance(value, bool):
        errors.append(f"{field}_not_integer")
        return

    if isinstance(value, int):
        score = value
    elif isinstance(value, str) and re.fullmatch(r"[1-9]\d*", value.strip()):
        score = int(value.strip())
    else:
        errors.append(f"{field}_not_positive_integer")
        return

    if not (1 <= score <= 10):
        errors.append(f"{field}_out_of_range:{score}")


def validate_record(data: Any) -> tuple[list[str], list[dict[str, Any]]]:
    errors: list[str] = []
    task_tag_issues: list[dict[str, Any]] = []

    if not isinstance(data, dict):
        return ["json_root_not_object"], task_tag_issues

    actual_fields = set(data)
    required_fields = set(REQUIRED_FIELDS)

    for field in REQUIRED_FIELDS:
        if field not in data:
            errors.append(f"missing_field:{field}")

    for field in sorted(actual_fields - required_fields):
        errors.append(f"extra_field:{field}")

    for field in ARRAY_FIELDS:
        if field in data and not isinstance(data[field], list):
            errors.append(f"{field}_not_array")

    validate_string_list(data, "task_tags", errors)
    task_tag_issues = validate_task_tags(data, errors)

    for field in SCORE_FIELDS:
        validate_score(data, field, errors)

    return errors, task_tag_issues


def iter_skill_json_files(root: Path, recursive: bool = False):
    if recursive:
        yield from sorted(root.rglob(INPUT_NAME), key=lambda p: str(p).lower())
        return

    for child in sorted(root.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir():
            continue

        json_path = child / INPUT_NAME
        if json_path.is_file():
            yield json_path


def scan(root: Path, recursive: bool = False) -> dict[str, Any]:
    error_counts: Counter[str] = Counter()
    valid_count = 0
    invalid_records: list[dict[str, Any]] = []
    json_files = list(iter_skill_json_files(root, recursive=recursive))

    for json_path in json_files:
        relative_path = str(json_path.relative_to(root))

        try:
            data = json.loads(json_path.read_text(encoding="utf-8"))
        except Exception as exc:
            reason = f"json_read_or_parse_error:{type(exc).__name__}"
            error_counts[reason] += 1
            invalid_records.append(
                {
                    "path": relative_path,
                    "skill_id": "",
                    "errors": [reason],
                }
            )
            continue

        errors, task_tag_issues = validate_record(data)
        skill_id = data.get("skill_id", "") if isinstance(data, dict) else ""

        if errors:
            for error in errors:
                error_counts[error] += 1
            invalid_record = {
                "path": relative_path,
                "skill_id": skill_id if isinstance(skill_id, str) else "",
                "errors": errors,
            }
            if task_tag_issues:
                invalid_record["task_tag_issues"] = task_tag_issues
            invalid_records.append(invalid_record)
        else:
            valid_count += 1

    return {
        "root": str(root),
        "scan_mode": "recursive" if recursive else "first-level",
        "json_files_found": len(json_files),
        "valid_count": valid_count,
        "invalid_count": len(invalid_records),
        "error_counts": dict(sorted(error_counts.items())),
        "invalid_records": invalid_records,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Scan skill_llm_describe.json files for merge-readiness."
    )
    parser.add_argument(
        "root",
        nargs="?",
        help="Root directory whose first-level child folders contain skill_llm_describe.json.",
    )
    parser.add_argument(
        "--recursive",
        action="store_true",
        help="Find skill_llm_describe.json files recursively instead of only in first-level child folders.",
    )
    parser.add_argument(
        "--report",
        help="Optional JSON report output path.",
    )
    parser.add_argument(
        "--max-examples",
        type=int,
        default=50,
        help="Maximum invalid records to print to the terminal. The JSON report always contains all records.",
    )
    parser.add_argument(
        "--fail-on-invalid",
        action="store_true",
        help="Return exit code 1 when any invalid record is found.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    root = clean_input_path(args.root or input("Please enter root directory: "))

    if not root.is_dir():
        print(f"Root directory does not exist: {root}", file=sys.stderr)
        return 2

    result = scan(root, recursive=args.recursive)

    print(f"Root: {result['root']}")
    print(f"Scan mode: {result['scan_mode']}")
    print(f"Found: {result['json_files_found']}")
    print(f"Valid: {result['valid_count']}")
    print(f"Invalid: {result['invalid_count']}")

    if result["error_counts"]:
        print("\nError counts:")
        for error, count in result["error_counts"].items():
            print(f"  {error}: {count}")

    if result["invalid_records"] and args.max_examples != 0:
        records_to_print = result["invalid_records"]
        if args.max_examples > 0:
            records_to_print = records_to_print[: args.max_examples]

        print("\nInvalid records:")
        for record in records_to_print:
            print(f"  {record['path']} ({record['skill_id']}): {', '.join(record['errors'])}")

        remaining = len(result["invalid_records"]) - len(records_to_print)
        if remaining > 0:
            print(f"  ... {remaining} more invalid records omitted; use --report for full details.")

    if args.report:
        report_path = clean_input_path(args.report)
        report_path.parent.mkdir(parents=True, exist_ok=True)
        report_path.write_text(
            json.dumps(result, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )
        print(f"\nReport written: {report_path}")

    if args.fail_on_invalid and result["invalid_count"]:
        return 1

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
