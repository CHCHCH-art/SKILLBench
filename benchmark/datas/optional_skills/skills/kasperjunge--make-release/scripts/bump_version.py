#!/usr/bin/env python3
import re
import sys
from pathlib import Path


SEMVER_RE = re.compile(r"^\d+\.\d+\.\d+$")


def replace_in_file(path: Path, pattern: re.Pattern[str], replacement: str) -> None:
    text = path.read_text(encoding="utf-8")
    new_text, count = pattern.subn(replacement, text, count=1)
    if count != 1:
        raise ValueError(f"Expected one match in {path}, found {count}.")
    path.write_text(new_text, encoding="utf-8")


def main() -> int:
    if len(sys.argv) != 2:
        print("Usage: bump_version.py X.Y.Z", file=sys.stderr)
        return 1

    version = sys.argv[1].strip()
    if not SEMVER_RE.match(version):
        print("Version must be SemVer: X.Y.Z", file=sys.stderr)
        return 1

    init_path = Path("agr/__init__.py")
    pyproject_path = Path("pyproject.toml")

    if not init_path.exists():
        print("agr/__init__.py not found.", file=sys.stderr)
        return 1
    if not pyproject_path.exists():
        print("pyproject.toml not found.", file=sys.stderr)
        return 1

    replace_in_file(
        init_path,
        re.compile(r"^__version__\s*=\s*\"[^\"]+\"", re.MULTILINE),
        f'__version__ = "{version}"',
    )

    replace_in_file(
        pyproject_path,
        re.compile(r"^version\s*=\s*\"[^\"]+\"", re.MULTILINE),
        f'version = "{version}"',
    )

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
