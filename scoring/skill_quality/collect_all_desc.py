#!/usr/bin/env python
"""Collect first-level per-skill records into All.jsonl."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path
from typing import Any


INPUT_NAME = "All_Desc.jsonl"
OUTPUT_NAME = "All.jsonl"


def clean_input_path(raw: str) -> Path:
    raw = raw.strip().strip('"').strip("'")
    return Path(raw).expanduser().resolve()


def iter_source_files(root: Path):
    for child in sorted(root.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir():
            continue

        input_path = child / INPUT_NAME
        if input_path.is_file():
            yield input_path


def read_jsonl_records(path: Path) -> tuple[list[dict[str, Any]], list[str]]:
    records: list[dict[str, Any]] = []
    errors: list[str] = []

    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except UnicodeDecodeError:
        lines = path.read_text(encoding="utf-8-sig").splitlines()
    except Exception as exc:
        return records, [f"read_error:{type(exc).__name__}"]

    for line_number, line in enumerate(lines, start=1):
        if not line.strip():
            continue

        try:
            data = json.loads(line)
        except Exception as exc:
            errors.append(f"line_{line_number}_json_parse_error:{type(exc).__name__}")
            continue

        if not isinstance(data, dict):
            errors.append(f"line_{line_number}_not_object")
            continue

        records.append(data)

    return records, errors


def collect(roots: list[Path], output_dir: Path, dry_run: bool = False) -> dict[str, Any]:
    results: list[dict[str, Any]] = []
    all_records: list[dict[str, Any]] = []
    status_counts: Counter[str] = Counter()

    for root in roots:
        if not root.is_dir():
            result = {
                "root": str(root),
                "status": "root_missing",
                "files_found": 0,
                "records": 0,
                "errors": [f"root_not_directory:{root}"],
            }
            results.append(result)
            status_counts[result["status"]] += 1
            continue

        root_files = list(iter_source_files(root))
        root_errors: list[str] = []
        root_record_count = 0

        for input_path in root_files:
            records, errors = read_jsonl_records(input_path)
            if errors:
                relative_path = str(input_path.relative_to(root))
                root_errors.extend(f"{relative_path}:{error}" for error in errors)

            all_records.extend(records)
            root_record_count += len(records)

        status = "ok" if not root_errors else "has_errors"
        result = {
            "root": str(root),
            "status": status,
            "files_found": len(root_files),
            "records": root_record_count,
            "errors": root_errors,
        }
        results.append(result)
        status_counts[status] += 1

    output_path = output_dir / OUTPUT_NAME
    if not dry_run:
        output_dir.mkdir(parents=True, exist_ok=True)
        with output_path.open("w", encoding="utf-8", newline="\n") as f:
            for record in all_records:
                f.write(json.dumps(record, ensure_ascii=False, separators=(",", ":")) + "\n")

    return {
        "output": str(output_path),
        "dry_run": dry_run,
        "roots_seen": len(roots),
        "files_found": sum(result["files_found"] for result in results),
        "records_written": len(all_records),
        "status_counts": dict(sorted(status_counts.items())),
        "results": results,
    }


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Collect first-level All_Desc.jsonl files from multiple roots into All.jsonl."
    )
    parser.add_argument(
        "--input-dir",
        nargs="+",
        required=True,
        help="One or more roots whose first-level child folders may contain All_Desc.jsonl.",
    )
    parser.add_argument(
        "--output-dir",
        required=True,
        help="Output directory. The output filename is always All.jsonl.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Scan and validate without writing All.jsonl.",
    )
    parser.add_argument(
        "--report",
        help="Optional JSON summary report output path.",
    )
    parser.add_argument(
        "--max-errors",
        type=int,
        default=50,
        help="Maximum roots with errors to print. The JSON report contains all details.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    roots = [clean_input_path(root) for root in args.input_dir]
    output_dir = clean_input_path(args.output_dir)

    summary = collect(roots, output_dir=output_dir, dry_run=args.dry_run)

    print(f"Output: {summary['output']}")
    print(f"Roots seen: {summary['roots_seen']}")
    print(f"All_Desc.jsonl files found: {summary['files_found']}")
    print(f"Records {'found' if args.dry_run else 'written'}: {summary['records_written']}")
    print("Status counts:")
    for status, count in summary["status_counts"].items():
        print(f"  {status}: {count}")

    problem_results = [result for result in summary["results"] if result["errors"]]
    if problem_results and args.max_errors != 0:
        to_print = problem_results
        if args.max_errors > 0:
            to_print = to_print[: args.max_errors]

        print("Errors:")
        for result in to_print:
            print(f"  {result['root']}: {'; '.join(result['errors'])}")

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
