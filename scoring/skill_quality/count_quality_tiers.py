#!/usr/bin/env python
"""Count quality_tier values from first-level skill folders."""

from __future__ import annotations

import argparse
import json
import sys
from collections import Counter
from pathlib import Path


OUTPUT_NAME = "skill_llm_describe.json"
TIERS = ("A", "B", "C", "D")


def clean_input_path(raw: str) -> Path:
    raw = raw.strip().strip('"').strip("'")
    return Path(raw).expanduser().resolve()


def iter_skill_json_files(root: Path):
    for child in sorted(root.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir():
            continue

        json_path = child / OUTPUT_NAME
        if json_path.is_file():
            yield json_path


def count_quality_tiers(root: Path) -> Counter[str]:
    counts: Counter[str] = Counter()

    for json_path in iter_skill_json_files(root):
        try:
            data = json.loads(json_path.read_text(encoding="utf-8"))
        except Exception as e:
            print(f"Skip unreadable JSON: {json_path} ({type(e).__name__}: {e})", file=sys.stderr)
            continue

        tier = str(data.get("quality_tier", "")).strip().upper()
        if tier in TIERS:
            counts[tier] += 1

    return counts


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Count A/B/C/D quality_tier values from skill_llm_describe.json files."
    )
    parser.add_argument(
        "root",
        nargs="?",
        help="Root directory whose first-level child folders contain skill_llm_describe.json.",
    )
    return parser.parse_args()


def main() -> None:
    args = parse_args()
    root = clean_input_path(args.root or input("Please enter root directory: "))

    if not root.is_dir():
        raise NotADirectoryError(f"Root directory does not exist: {root}")

    counts = count_quality_tiers(root)
    for tier in TIERS:
        print(f"{tier}: {counts[tier]}")


if __name__ == "__main__":
    main()
