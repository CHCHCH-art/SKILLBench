#!/usr/bin/env python3
from __future__ import annotations
import argparse
import math
import re
import zipfile
from pathlib import PurePosixPath
import xml.etree.ElementTree as ET

MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_DOC_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
REL_PKG_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
NS = {"m": MAIN_NS, "p": REL_PKG_NS}
CELL_RE = re.compile(r"^([A-Z]+)([1-9][0-9]*)$")
RANGE_RE = re.compile(r"^([A-Z]+[1-9][0-9]*):([A-Z]+[1-9][0-9]*)$")


def col_num(s: str) -> int:
    n = 0
    for ch in s:
        n = n * 26 + ord(ch) - 64
    return n


def col_name(n: int) -> str:
    out = ""
    while n:
        n, r = divmod(n - 1, 26)
        out = chr(65 + r) + out
    return out


def split_cell(ref: str) -> tuple[int, int]:
    m = CELL_RE.match(ref)
    if not m:
        raise ValueError(f"invalid cell reference: {ref}")
    return int(m.group(2)), col_num(m.group(1))


def expand_range(spec: str) -> list[str]:
    if CELL_RE.match(spec):
        return [spec]
    m = RANGE_RE.match(spec)
    if not m:
        raise ValueError(f"invalid range: {spec}")
    r1, c1 = split_cell(m.group(1))
    r2, c2 = split_cell(m.group(2))
    if r2 < r1 or c2 < c1:
        raise ValueError(f"reversed range: {spec}")
    return [f"{col_name(c)}{r}" for r in range(r1, r2 + 1) for c in range(c1, c2 + 1)]


def resolve_target(base: PurePosixPath, target: str) -> PurePosixPath:
    if target.startswith("/"):
        return PurePosixPath(target.lstrip("/"))
    parts: list[str] = []
    for part in (base.parent / target).parts:
        if part in ("", "."):
            continue
        if part == "..":
            if parts:
                parts.pop()
        else:
            parts.append(part)
    return PurePosixPath(*parts)


def sheet_member(archive: zipfile.ZipFile, sheet_name: str) -> str:
    wb_path = PurePosixPath("xl/workbook.xml")
    wb = ET.fromstring(archive.read(wb_path.as_posix()))
    rels = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
    targets = {r.attrib["Id"]: r.attrib["Target"] for r in rels.findall("p:Relationship", NS)}
    for sh in wb.findall(f".//{{{MAIN_NS}}}sheet"):
        if sh.attrib.get("name") == sheet_name:
            rid = sh.attrib[f"{{{REL_DOC_NS}}}id"]
            return resolve_target(wb_path, targets[rid]).as_posix()
    raise SystemExit(f"sheet not found: {sheet_name}")


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("--workbook", required=True)
    ap.add_argument("--sheet", required=True)
    ap.add_argument("--ranges", nargs="+", required=True)
    args = ap.parse_args()

    wanted: list[str] = []
    seen: set[str] = set()
    for spec in args.ranges:
        for ref in expand_range(spec.upper()):
            if ref not in seen:
                seen.add(ref)
                wanted.append(ref)

    with zipfile.ZipFile(args.workbook, "r") as z:
        bad = z.testzip()
        if bad:
            raise SystemExit(f"corrupt XLSX member: {bad}")
        member = sheet_member(z, args.sheet)
        root = ET.fromstring(z.read(member))

    cells = {c.attrib.get("r"): c for c in root.findall(f".//{{{MAIN_NS}}}c") if c.attrib.get("r")}
    failures: list[str] = []
    for ref in wanted:
        c = cells.get(ref)
        if c is None:
            failures.append(f"{ref}: missing cell")
            continue
        f = c.find(f"{{{MAIN_NS}}}f")
        v = c.find(f"{{{MAIN_NS}}}v")
        if f is None or not (f.text or "").strip():
            failures.append(f"{ref}: missing formula")
        if v is None or v.text in (None, ""):
            failures.append(f"{ref}: missing numeric cache")
        else:
            try:
                value = float(v.text)
                if not math.isfinite(value):
                    failures.append(f"{ref}: non-finite cache")
            except ValueError:
                failures.append(f"{ref}: non-numeric cache {v.text!r}")

    if failures:
        print("formula target verification failed:")
        for item in failures[:30]:
            print(" -", item)
        if len(failures) > 30:
            print(f" ... and {len(failures)-30} more")
        raise SystemExit(1)

    print(f"formula target verification passed: {len(wanted)} cells")


if __name__ == "__main__":
    main()
