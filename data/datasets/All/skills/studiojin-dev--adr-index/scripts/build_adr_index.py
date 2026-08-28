#!/usr/bin/env python3
"""Generate docs/adr/index.json from ADR files with validation."""
# ADR format and workflow: https://github.com/studiojin-dev/adr-index-skill#usage

from __future__ import annotations

import hashlib
import json
import re
import sys
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Optional

MAX_SCAN_LINES = 40
MAX_SEQUENCE = 9999
SUGGESTION_COUNT = 3
STATUS_VALUES = {"Proposed", "Accepted", "Deprecated"}
ROOT_MARKERS = (".git", "pyproject.toml", "package.json", "go.mod", "pom.xml", ".codex")


@dataclass
class AdrMeta:
    id: str
    id_key: str
    id_date: Optional[str]
    title: str
    tags: list[str]
    status: Optional[str]
    date: Optional[str]
    tldr: Optional[str]
    path: str


@dataclass
class DuplicateIdConflict:
    duplicate_id: str
    keep_path: str
    change_path: str
    suggestions: list[str]


class AdrError(Exception):
    pass


def _parse_date(value: str, source: Path) -> str:
    try:
        parsed = date.fromisoformat(value)
    except ValueError as exc:
        raise AdrError(f"Invalid Date in {source}: {value}") from exc
    return parsed.isoformat()


def _parse_header(line: str, source: Path) -> tuple[str, str, str, str]:
    match = re.match(r"#\s+ADR-(\d{8})-(\d{4})-([A-Za-z0-9]{3}):\s+(.+)$", line.strip())
    if not match:
        raise AdrError(
            "Invalid first line in {0}. Expected '# ADR-YYYYMMDD-####-XXX: <title>'".format(
                source
            )
        )
    date_digits = match.group(1)
    seq = match.group(2)
    suffix = match.group(3)
    title = match.group(4).strip()
    if not title:
        raise AdrError(f"Empty title in {source}")
    id_date = _parse_date(f"{date_digits[:4]}-{date_digits[4:6]}-{date_digits[6:]}", source)
    id_key = f"{date_digits}-{seq}-{suffix}"
    return f"ADR-{id_key}", id_key, id_date, title


def _parse_metadata(lines: list[str], source: Path) -> tuple[list[str], Optional[str], Optional[str], Optional[str]]:
    tags: Optional[list[str]] = None
    status: Optional[str] = None
    adr_date: Optional[str] = None
    tldr: Optional[str] = None

    for raw in lines[:MAX_SCAN_LINES]:
        line = raw.strip()
        if not line:
            continue
        if line.startswith("Tags:"):
            if tags is not None:
                raise AdrError(f"Duplicate Tags in {source}")
            tag_blob = line[len("Tags:") :].strip()
            tags = [t.strip() for t in tag_blob.split(",") if t.strip()]
        elif line.startswith("Status:"):
            if status is not None:
                raise AdrError(f"Duplicate Status in {source}")
            value = line[len("Status:") :].strip()
            if value not in STATUS_VALUES:
                raise AdrError(
                    f"Invalid Status in {source}: {value}. Expected one of {sorted(STATUS_VALUES)}"
                )
            status = value
        elif line.startswith("Date:"):
            if adr_date is not None:
                raise AdrError(f"Duplicate Date in {source}")
            value = line[len("Date:") :].strip()
            adr_date = _parse_date(value, source)
        elif line.startswith("TL;DR:"):
            if tldr is not None:
                raise AdrError(f"Duplicate TL;DR in {source}")
            value = line[len("TL;DR:") :].strip()
            if not value:
                raise AdrError(f"Empty TL;DR in {source}")
            tldr = value

    if tags is None:
        tags = []

    return tags, status, adr_date, tldr


def _load_adr(path: Path, root: Path) -> AdrMeta:
    try:
        lines = path.read_text(encoding="utf-8").splitlines()
    except OSError as exc:
        raise AdrError(f"Failed to read {path}: {exc}") from exc

    if not lines:
        raise AdrError(f"Empty ADR file: {path}")

    relative_path = path.relative_to(root).as_posix()
    adr_id, id_key, id_date, title = _parse_header(lines[0], path)
    tags, status, adr_date, tldr = _parse_metadata(lines[1:], path)
    if adr_date is not None and id_date != adr_date:
        raise AdrError(
            f"Header date does not match Date in {relative_path}: "
            f"header={id_date}, Date={adr_date}"
        )

    return AdrMeta(
        id=adr_id,
        id_key=id_key,
        id_date=id_date,
        title=title,
        tags=tags,
        status=status,
        date=adr_date,
        tldr=tldr,
        path=relative_path,
    )


def _id_parts(entry: AdrMeta) -> tuple[str, int, str]:
    date_digits, seq, suffix = entry.id_key.split("-", 2)
    return date_digits, int(seq), suffix


def _suffix_for_candidate(path: str, date_digits: str, sequence: int) -> str:
    digest = hashlib.sha256(f"{path}:{date_digits}:{sequence}".encode("utf-8")).digest()
    alphabet = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    return "".join(alphabet[byte % len(alphabet)] for byte in digest[:3])


def _initial_next_sequence(entries: list[AdrMeta]) -> dict[str, int]:
    next_sequence_by_date: dict[str, int] = {}

    for entry in entries:
        date_digits, sequence, _ = _id_parts(entry)
        current = next_sequence_by_date.get(date_digits, 1)
        next_sequence_by_date[date_digits] = max(current, sequence + 1)

    return next_sequence_by_date


def _generate_suggested_ids(
    path: str,
    date_digits: str,
    next_sequence_by_date: dict[str, int],
    reserved_ids: set[str],
) -> list[str]:
    suggestions: list[str] = []

    while len(suggestions) < SUGGESTION_COUNT:
        sequence = next_sequence_by_date.get(date_digits, 1)
        if sequence > MAX_SEQUENCE:
            raise AdrError(
                f"No replacement ADR IDs available for {path}: "
                f"sequence space exhausted for date {date_digits}"
            )
        next_sequence_by_date[date_digits] = sequence + 1
        candidate = (
            f"ADR-{date_digits}-{sequence:04d}-{_suffix_for_candidate(path, date_digits, sequence)}"
        )
        if candidate in reserved_ids:
            continue
        reserved_ids.add(candidate)
        suggestions.append(candidate)

    return suggestions


def _find_duplicate_id_conflicts(entries: list[AdrMeta]) -> list[DuplicateIdConflict]:
    first_paths: dict[str, str] = {}
    reserved_ids = {entry.id for entry in entries}
    next_sequence_by_date = _initial_next_sequence(entries)
    conflicts: list[DuplicateIdConflict] = []

    for entry in entries:
        first_path = first_paths.get(entry.id)
        if first_path is None:
            first_paths[entry.id] = entry.path
            continue

        date_digits, _, _ = _id_parts(entry)
        conflicts.append(
            DuplicateIdConflict(
                duplicate_id=entry.id,
                keep_path=first_path,
                change_path=entry.path,
                suggestions=_generate_suggested_ids(
                    entry.path,
                    date_digits,
                    next_sequence_by_date,
                    reserved_ids,
                ),
            )
        )

    return conflicts


def _format_duplicate_id_conflicts(conflicts: list[DuplicateIdConflict]) -> str:
    payload = {
        "duplicateFixes": [
            {
                "duplicateId": conflict.duplicate_id,
                "keepPath": conflict.keep_path,
                "changePath": conflict.change_path,
                "suggestedIds": conflict.suggestions,
            }
            for conflict in conflicts
        ]
    }
    lines = ["Duplicate ADR IDs found:"]

    for conflict in conflicts:
        suggestions = ", ".join(conflict.suggestions)
        lines.extend(
            [
                f"- {conflict.duplicate_id}",
                f"  keep: {conflict.keep_path}",
                f"  change: {conflict.change_path}",
                f"  suggested IDs: {suggestions}",
            ]
        )

    lines.append(
        "AI next step: choose one suggested ID per 'change' path, update the ADR header,"
    )
    lines.append(
        "rename the file if it embeds the old ID, then rerun the generator."
    )
    lines.append(
        "Default choice: use the first suggested ID unless repo-specific naming"
        " conventions make another suggestion a better fit."
    )
    lines.append("Suggested duplicate fixes JSON:")
    lines.append(json.dumps(payload, indent=2, ensure_ascii=False))

    return "\n".join(lines)


def _validate_unique_ids(entries: list[AdrMeta]) -> None:
    conflicts = _find_duplicate_id_conflicts(entries)
    if conflicts:
        raise AdrError(_format_duplicate_id_conflicts(conflicts))


def _sort_key(meta: AdrMeta) -> tuple[str, str]:
    date_key = meta.date or meta.id_date or "0000-00-00"
    return (date_key, meta.id_key)


def _find_repo_root(start: Path) -> Path:
    current = start.resolve()
    # Prefer .git or .codex if present to avoid monorepo sub-root detection.
    preferred_markers = (".git", ".codex")
    fallback_markers = tuple(m for m in ROOT_MARKERS if m not in preferred_markers)

    for candidate in (current, *current.parents):
        if any((candidate / marker).exists() for marker in preferred_markers):
            return candidate

    for candidate in (current, *current.parents):
        if any((candidate / marker).exists() for marker in fallback_markers):
            return candidate

    return Path.cwd().resolve()


def main() -> int:
    script_dir = Path(__file__).resolve().parent
    root = _find_repo_root(script_dir)
    if root == Path.cwd().resolve() and not any((root / marker).exists() for marker in ROOT_MARKERS):
        print("Warning: repo root not detected; using current working directory.")

    adr_dir = root / "docs" / "adr"
    index_path = adr_dir / "index.json"

    if not adr_dir.exists():
        raise AdrError(f"ADR directory not found: {adr_dir}")

    adr_files = sorted(adr_dir.glob("*.md"))
    # Exclude non-ADR docs/templates from indexing
    excluded_names = {"readme.md", "0000-template.md", "template.md", "index.md"}
    adr_files = [p for p in adr_files if p.name.lower() not in excluded_names]
    if not adr_files:
        # No ADRs yet: generate an empty index for a smooth first-time setup.
        new_json = json.dumps([], indent=2, ensure_ascii=False) + "\n"
        old_json = index_path.read_text(encoding="utf-8") if index_path.exists() else None
        changed = old_json != new_json
        if changed:
            index_path.write_text(new_json, encoding="utf-8")
        print(f"ADRs: 0; index.json changed: {'yes' if changed else 'no'}")
        return 0

    entries = [_load_adr(path, root) for path in adr_files]
    _validate_unique_ids(entries)
    entries.sort(key=_sort_key, reverse=True)

    payload = [
        {
            "id": entry.id,
            "title": entry.title,
            "tags": entry.tags,
            "status": entry.status,
            "date": entry.date,
            "tldr": entry.tldr,
            "path": entry.path,
        }
        for entry in entries
    ]

    new_json = json.dumps(payload, indent=2, ensure_ascii=False) + "\n"
    old_json = None
    if index_path.exists():
        old_json = index_path.read_text(encoding="utf-8")

    changed = old_json != new_json
    if changed:
        index_path.write_text(new_json, encoding="utf-8")

    print(f"ADRs: {len(entries)}; index.json changed: {'yes' if changed else 'no'}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except AdrError as exc:
        print(str(exc), file=sys.stderr)
        raise SystemExit(1)
