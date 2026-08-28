#!/usr/bin/env python3
import re
import sys
from datetime import date
from pathlib import Path


SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: promote_changelog.py X.Y.Z", file=sys.stderr)
        return 1

    version = sys.argv[1].strip()
    if not SEMVER_RE.match(version):
        print("Version must be SemVer: X.Y.Z", file=sys.stderr)
        return 1

    changelog = Path("CHANGELOG.md")
    if not changelog.exists():
        print("CHANGELOG.md not found.", file=sys.stderr)
        return 1

    lines = changelog.read_text(encoding="utf-8").splitlines()

    unreleased_index = None
    for i, line in enumerate(lines):
        if line.strip() == "## [Unreleased]":
            unreleased_index = i
            break

    if unreleased_index is None:
        print("Missing '## [Unreleased]' section in CHANGELOG.md.", file=sys.stderr)
        return 1

    if any(line.strip().startswith(f"## [{version}]") for line in lines):
        print(f"Version {version} already exists in CHANGELOG.md.", file=sys.stderr)
        return 1

    content_lines = []
    end_index = len(lines)
    for i, line in enumerate(lines[unreleased_index + 1 :], start=unreleased_index + 1):
        if line.startswith("## "):
            end_index = i
            break
        content_lines.append(line)

    has_bullets = any(line.strip().startswith(("- ", "* ")) for line in content_lines)
    if not has_bullets:
        print(
            "'## [Unreleased]' has no bullet entries. Add changes before release.",
            file=sys.stderr,
        )
        return 1

    while content_lines and content_lines[0].strip() == "":
        content_lines.pop(0)

    release_heading = f"## [{version}] - {date.today().isoformat()}"

    new_lines = []
    new_lines.extend(lines[: unreleased_index + 1])
    new_lines.append("")
    new_lines.append(release_heading)
    new_lines.extend(content_lines)
    new_lines.append("")
    new_lines.extend(lines[end_index:])

    changelog.write_text("\n".join(new_lines).rstrip() + "\n", encoding="utf-8")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
