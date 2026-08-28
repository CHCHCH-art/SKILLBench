#!/usr/bin/env python3
"""Validate that agent directories have corresponding README.md index entries.

Scans agent directories and checks that each agent file is listed
in the corresponding README.md index table.

Usage:
    python validate-agent-index.py [--dir AGENTS_DIR]

Output: JSON with validation results to stdout.
"""
from __future__ import annotations

import argparse
import json
import re
import sys
from pathlib import Path


def find_agents(agents_dir: Path) -> list[str]:
    """Return sorted list of agent names from .md files in directory."""
    if not agents_dir.is_dir():
        return []
    return sorted(
        p.stem
        for p in agents_dir.glob("*.md")
        if p.stem.lower() != "readme" and not p.name.startswith(".")
    )


def find_readme_entries(agents_dir: Path) -> list[str]:
    """Extract agent names from the README.md index table."""
    readme = agents_dir / "README.md"
    if not readme.is_file():
        return []
    content = readme.read_text(encoding="utf-8", errors="replace")
    entries = []
    for line in content.splitlines():
        m = re.match(r"^\|\s*`?([a-z0-9][a-z0-9-]*)`?\s*\|", line)
        if m:
            name = m.group(1).strip()
            if name and name != "name" and not re.match(r"^[-:]+$", name):
                entries.append(name)
    return sorted(entries)


def validate(agents_dir: Path) -> dict:
    """Validate agents against README index."""
    agents = find_agents(agents_dir)
    entries = find_readme_entries(agents_dir)

    missing_from_readme = [a for a in agents if a not in entries]
    orphan_entries = [e for e in entries if e not in agents]

    return {
        "directory": str(agents_dir),
        "agents_found": len(agents),
        "readme_entries": len(entries),
        "missing_from_readme": missing_from_readme,
        "orphan_entries": orphan_entries,
        "valid": len(missing_from_readme) == 0 and len(orphan_entries) == 0,
    }


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Validate agent directories have README.md index entries"
    )
    parser.add_argument(
        "--dir",
        default="agents",
        help="Path to agents directory (default: agents)",
    )
    args = parser.parse_args()

    agents_dir = Path(args.dir).resolve()
    result = validate(agents_dir)
    json.dump(result, sys.stdout, indent=2)
    sys.stdout.write("\n")

    if not result["valid"]:
        sys.exit(1)


if __name__ == "__main__":
    main()
