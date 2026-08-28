#!/bin/bash
set -euo pipefail

readonly EXCEL_FILE="/root/gdp.xlsx"
readonly WORK_ROOT="/tmp/gdp_formula_pipeline"
readonly STAGE_DIR="${WORK_ROOT}/stage"
readonly ODS_DIR="${WORK_ROOT}/ods"
readonly RECALC_DIR="${WORK_ROOT}/recalculated"
readonly UNPACK_DIR="${WORK_ROOT}/unpacked"
readonly NORMALIZED_CSV="${WORK_ROOT}/observations.csv"
readonly SQLITE_DB="${WORK_ROOT}/observations.sqlite3"
readonly MANIFEST="${WORK_ROOT}/manifest.json"
readonly STAGE_XLSX="${STAGE_DIR}/gdp_stage.xlsx"

if [[ ! -f "${EXCEL_FILE}" ]]; then
    echo "ERROR: workbook not found: ${EXCEL_FILE}" >&2
    exit 1
fi

rm -rf "${WORK_ROOT}"
mkdir -p "${WORK_ROOT}" "${STAGE_DIR}" "${ODS_DIR}" "${RECALC_DIR}" "${UNPACK_DIR}"

SOFFICE_BIN=""
if command -v libreoffice >/dev/null 2>&1; then
    SOFFICE_BIN="$(command -v libreoffice)"
elif command -v soffice >/dev/null 2>&1; then
    SOFFICE_BIN="$(command -v soffice)"
else
    export DEBIAN_FRONTEND=noninteractive
    if apt-get update && apt-get install -y --no-install-recommends libreoffice-calc; then
        rm -rf /var/lib/apt/lists/*
        if command -v libreoffice >/dev/null 2>&1; then
            SOFFICE_BIN="$(command -v libreoffice)"
        elif command -v soffice >/dev/null 2>&1; then
            SOFFICE_BIN="$(command -v soffice)"
        fi
    else
        echo "WARNING: LibreOffice is unavailable; verified SQLite/Python caches will be used." >&2
    fi
fi

export EXCEL_FILE WORK_ROOT STAGE_DIR ODS_DIR RECALC_DIR UNPACK_DIR
export NORMALIZED_CSV SQLITE_DB MANIFEST STAGE_XLSX

python3 <<'PYTHON_SCRIPT'
from __future__ import annotations

import csv
import html
import json
import math
import os
import re
import shutil
import sqlite3
import statistics
import zipfile
from pathlib import Path, PurePosixPath
from typing import Any
import xml.etree.ElementTree as ET

EXCEL_FILE = Path(os.environ["EXCEL_FILE"])
UNPACK_DIR = Path(os.environ["UNPACK_DIR"])
NORMALIZED_CSV = Path(os.environ["NORMALIZED_CSV"])
SQLITE_DB = Path(os.environ["SQLITE_DB"])
MANIFEST = Path(os.environ["MANIFEST"])
STAGE_XLSX = Path(os.environ["STAGE_XLSX"])

MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_DOC_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
REL_PKG_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
NS = {"m": MAIN_NS, "r": REL_DOC_NS, "p": REL_PKG_NS}
CELL_REF_RE = re.compile(r"^([A-Z]+)([0-9]+)$")
YEAR_RE = re.compile(r"^(19|20|21)\d{2}$")


def col_to_num(col: str) -> int:
    number = 0
    for ch in col:
        number = number * 26 + ord(ch) - 64
    return number


def num_to_col(number: int) -> str:
    result = ""
    while number:
        number, remainder = divmod(number - 1, 26)
        result = chr(65 + remainder) + result
    return result


def split_ref(ref: str) -> tuple[int, int]:
    match = CELL_REF_RE.match(ref)
    if not match:
        raise ValueError(f"Invalid cell reference: {ref}")
    return int(match.group(2)), col_to_num(match.group(1))


def normalize(value: Any) -> str:
    if value is None:
        return ""
    if isinstance(value, bool):
        return "1" if value else "0"
    if isinstance(value, (int, float)):
        number = float(value)
        if math.isfinite(number) and number.is_integer():
            return str(int(number))
        return format(number, ".15g")
    return str(value).strip()


def to_float(value: Any) -> float:
    if value is None or value == "":
        raise ValueError("empty numeric value")
    if isinstance(value, (int, float)):
        return float(value)
    return float(str(value).strip().replace(",", ""))


def unzip_xlsx(source: Path, destination: Path) -> None:
    with zipfile.ZipFile(source, "r") as archive:
        archive.extractall(destination)


def zip_xlsx(source_dir: Path, destination: Path) -> None:
    temp = destination.with_suffix(destination.suffix + ".tmp")
    if temp.exists():
        temp.unlink()
    destination.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(temp, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(source_dir.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(source_dir).as_posix())
    os.replace(temp, destination)


def resolve_package_target(base: PurePosixPath, target: str) -> PurePosixPath:
    if target.startswith("/"):
        return PurePosixPath(target.lstrip("/"))
    combined = base.parent / target
    parts: list[str] = []
    for part in combined.parts:
        if part in ("", "."):
            continue
        if part == "..":
            if parts:
                parts.pop()
        else:
            parts.append(part)
    return PurePosixPath(*parts)


def shared_strings(package_dir: Path) -> list[str]:
    path = package_dir / "xl" / "sharedStrings.xml"
    if not path.exists():
        return []
    root = ET.parse(path).getroot()
    result: list[str] = []
    for si in root.findall("m:si", NS):
        result.append("".join(node.text or "" for node in si.iter(f"{{{MAIN_NS}}}t")))
    return result


def workbook_sheet_paths(package_dir: Path) -> dict[str, Path]:
    workbook_rel = PurePosixPath("xl/workbook.xml")
    workbook_root = ET.parse(package_dir / workbook_rel).getroot()
    rels_root = ET.parse(package_dir / "xl" / "_rels" / "workbook.xml.rels").getroot()
    targets = {
        rel.attrib["Id"]: rel.attrib["Target"]
        for rel in rels_root.findall("p:Relationship", NS)
    }
    result: dict[str, Path] = {}
    for sheet in workbook_root.findall("m:sheets/m:sheet", NS):
        rel_id = sheet.attrib[f"{{{REL_DOC_NS}}}id"]
        relative = resolve_package_target(workbook_rel, targets[rel_id])
        result[sheet.attrib["name"]] = package_dir / relative.as_posix()
    return result


class SheetReader:
    def __init__(self, path: Path, strings: list[str]):
        self.path = path
        self.root = ET.parse(path).getroot()
        self.strings = strings
        self.cells = {
            cell.attrib["r"]: cell
            for cell in self.root.findall(".//m:sheetData/m:row/m:c", NS)
            if "r" in cell.attrib
        }

    def value(self, ref: str) -> Any:
        cell = self.cells.get(ref)
        if cell is None:
            return None
        cell_type = cell.attrib.get("t")
        if cell_type == "inlineStr":
            return "".join(node.text or "" for node in cell.iter(f"{{{MAIN_NS}}}t"))
        value = cell.find("m:v", NS)
        if value is None or value.text is None:
            return None
        raw = value.text
        if cell_type == "s":
            return self.strings[int(raw)]
        if cell_type in {"str", "e"}:
            return raw
        if cell_type == "b":
            return raw == "1"
        try:
            number = float(raw)
            return int(number) if number.is_integer() else number
        except ValueError:
            return raw

    def style(self, ref: str) -> str | None:
        cell = self.cells.get(ref)
        return None if cell is None else cell.attrib.get("s")


def detect_data_year_row(data: SheetReader) -> tuple[int, dict[str, int]]:
    best: tuple[int, int, int, dict[str, int]] | None = None
    for row in range(1, 21):
        years: dict[str, int] = {}
        for col in range(1, 40):
            key = normalize(data.value(f"{num_to_col(col)}{row}"))
            if YEAR_RE.match(key):
                years[key] = col
        candidate = (len(years), 1 if row == 4 else 0, -row, years)
        if best is None or candidate[:3] > best[:3]:
            best = candidate
    if best is None or best[0] < 5:
        raise RuntimeError("Could not identify a usable year-header row in Data")
    return -best[2], best[3]


def detect_task_year_row(task: SheetReader, data_years: set[str]) -> tuple[int, list[str]]:
    best: tuple[int, int, int, list[str]] | None = None
    for row in range(1, 16):
        values = [normalize(task.value(f"{col}{row}")) for col in "HIJKL"]
        score = sum(1 for value in values if value in data_years)
        contiguous = 1 if score == 5 and all(values) else 0
        proximity = -abs(row - 10)
        candidate = (score, contiguous, proximity, values)
        if best is None or candidate[:3] > best[:3]:
            best = candidate
    if best is None or best[0] != 5:
        raise RuntimeError("Could not identify the five Task year headers in columns H:L")
    for row in range(1, 16):
        values = [normalize(task.value(f"{col}{row}")) for col in "HIJKL"]
        candidate = (sum(1 for value in values if value in data_years), 1 if all(values) else 0, -abs(row - 10))
        if candidate == best[:3]:
            return row, values
    raise AssertionError("Task year-row detection became inconsistent")


def detect_series_column(data: SheetReader, required_codes: set[str]) -> int:
    best: tuple[int, int, int] | None = None
    for col in range(1, 15):
        observed = {
            normalize(data.value(f"{num_to_col(col)}{row}"))
            for row in range(21, 41)
        }
        score = len(required_codes & observed)
        candidate = (score, 1 if col == 2 else 0, -col)
        if best is None or candidate > best:
            best = candidate
    if best is None or best[0] != len(required_codes):
        found = 0 if best is None else best[0]
        raise RuntimeError(
            f"Could not match all Task series codes in Data rows 21:40; matched {found}/{len(required_codes)}"
        )
    return -best[2]


def percentile_inc(values: list[float], probability: float) -> float:
    ordered = sorted(values)
    rank = (len(ordered) - 1) * probability
    lower = math.floor(rank)
    upper = math.ceil(rank)
    if lower == upper:
        return ordered[lower]
    fraction = rank - lower
    return ordered[lower] + fraction * (ordered[upper] - ordered[lower])


def patch_cell_xml(xml_text: str, ref: str, formula: str, cached: float) -> str:
    escaped_formula = html.escape(formula, quote=False)
    cached_text = format(float(cached), ".15g")
    quoted_ref = re.escape(ref)
    self_closing = re.compile(
        rf"<c\b(?P<attrs>[^>]*?\br=([\"']){quoted_ref}\2[^>]*?)/>",
        re.DOTALL,
    )
    normal = re.compile(
        rf"<c\b(?P<attrs>[^>]*?\br=([\"']){quoted_ref}\2[^>]*?)>.*?</c>",
        re.DOTALL,
    )
    match = self_closing.search(xml_text)
    if match is None:
        match = normal.search(xml_text)
    if match is None:
        raise RuntimeError(f"Template cell {ref} is missing; expected an existing formatted target cell")
    attrs = re.sub(r"\s+t=([\"']).*?\1", "", match.group("attrs"))
    replacement = f"<c{attrs}><f>{escaped_formula}</f><v>{cached_text}</v></c>"
    return xml_text[: match.start()] + replacement + xml_text[match.end() :]


unzip_xlsx(EXCEL_FILE, UNPACK_DIR)
strings = shared_strings(UNPACK_DIR)
sheet_paths = workbook_sheet_paths(UNPACK_DIR)
if set(sheet_paths) != {"Task", "Data"}:
    raise RuntimeError(f"Workbook must retain exactly Task and Data sheets; found {sorted(sheet_paths)}")

task = SheetReader(sheet_paths["Task"], strings)
data = SheetReader(sheet_paths["Data"], strings)

lookup_rows = list(range(12, 18)) + list(range(19, 25)) + list(range(26, 32))
required_codes = {normalize(task.value(f"D{row}")) for row in lookup_rows}
required_codes.discard("")
if len(required_codes) != 18:
    raise RuntimeError(f"Expected 18 distinct Task series codes; found {len(required_codes)}")

data_year_row, all_data_year_columns = detect_data_year_row(data)
task_year_row, task_years = detect_task_year_row(task, set(all_data_year_columns))
series_col = detect_series_column(data, required_codes)
series_col_letter = num_to_col(series_col)
selected_year_columns = {year: all_data_year_columns[year] for year in task_years}
last_source_col = max(max(selected_year_columns.values()), series_col)
last_source_col_letter = num_to_col(last_source_col)

with NORMALIZED_CSV.open("w", newline="", encoding="utf-8") as handle:
    writer = csv.writer(handle)
    writer.writerow(["series_code", "year", "value", "source_row", "source_column"])
    for row in range(21, 41):
        code = normalize(data.value(f"{series_col_letter}{row}"))
        if not code:
            continue
        for year, col in selected_year_columns.items():
            raw = data.value(f"{num_to_col(col)}{row}")
            value = to_float(raw)
            writer.writerow([code, year, format(value, ".17g"), row, col])

if SQLITE_DB.exists():
    SQLITE_DB.unlink()
connection = sqlite3.connect(SQLITE_DB)
connection.execute(
    """
    CREATE TABLE observations (
        series_code TEXT NOT NULL,
        year TEXT NOT NULL,
        value REAL NOT NULL,
        source_row INTEGER NOT NULL,
        source_column INTEGER NOT NULL,
        PRIMARY KEY (series_code, year)
    )
    """
)
with NORMALIZED_CSV.open(newline="", encoding="utf-8") as handle:
    reader = csv.DictReader(handle)
    connection.executemany(
        "INSERT INTO observations VALUES (:series_code, :year, :value, :source_row, :source_column)",
        list(reader),
    )
connection.commit()

missing = connection.execute(
    """
    SELECT wanted.series_code, wanted.year
    FROM (
        SELECT c.series_code, y.year
        FROM (SELECT DISTINCT series_code FROM observations WHERE series_code IN (%s)) c
        CROSS JOIN (SELECT DISTINCT year FROM observations WHERE year IN (%s)) y
    ) wanted
    LEFT JOIN observations o
      ON o.series_code = wanted.series_code AND o.year = wanted.year
    WHERE o.value IS NULL
    """ % (
        ",".join("?" for _ in required_codes),
        ",".join("?" for _ in task_years),
    ),
    tuple(sorted(required_codes)) + tuple(task_years),
).fetchall()
if missing:
    raise RuntimeError(f"Normalized source data is incomplete: {missing[:5]}")


def lookup(code: str, year: str) -> float:
    row = connection.execute(
        "SELECT value FROM observations WHERE series_code = ? AND year = ?",
        (code, year),
    ).fetchone()
    if row is None:
        raise RuntimeError(f"Missing source observation for {code}, {year}")
    return float(row[0])


formula_map: dict[str, str] = {}
expected: dict[str, float] = {}
styles: dict[str, str | None] = {}

for row in lookup_rows:
    code = normalize(task.value(f"D{row}"))
    for col_letter, year in zip("HIJKL", task_years):
        ref = f"{col_letter}{row}"
        formula = (
            f"IFERROR(INDEX('Data'!$A$21:${last_source_col_letter}$40,"
            f"MATCH($D{row},'Data'!${series_col_letter}$21:${series_col_letter}$40,0),"
            f"MATCH({col_letter}${task_year_row},'Data'!$A${data_year_row}:${last_source_col_letter}${data_year_row},0)),0)"
        )
        formula_map[ref] = formula
        expected[ref] = lookup(code, year)
        styles[ref] = task.style(ref)

for offset, row in enumerate(range(35, 41)):
    export_row = 12 + offset
    import_row = 19 + offset
    gdp_row = 26 + offset
    for col_letter in "HIJKL":
        ref = f"{col_letter}{row}"
        exports = expected[f"{col_letter}{export_row}"]
        imports = expected[f"{col_letter}{import_row}"]
        gdp = expected[f"{col_letter}{gdp_row}"]
        value = (exports - imports) / gdp * 100.0 if gdp else 0.0
        formula_map[ref] = (
            f"IFERROR(({col_letter}{export_row}-{col_letter}{import_row})/"
            f"{col_letter}{gdp_row}*100,0)"
        )
        expected[ref] = value
        styles[ref] = task.style(ref)

for col_letter in "HIJKL":
    values = [expected[f"{col_letter}{row}"] for row in range(35, 41)]
    stat_values = {
        42: min(values),
        43: max(values),
        44: statistics.median(values),
        45: statistics.fmean(values),
        46: percentile_inc(values, 0.25),
        47: percentile_inc(values, 0.75),
    }
    stat_formulas = {
        42: f"MIN({col_letter}35:{col_letter}40)",
        43: f"MAX({col_letter}35:{col_letter}40)",
        44: f"MEDIAN({col_letter}35:{col_letter}40)",
        45: f"AVERAGE({col_letter}35:{col_letter}40)",
        46: f"PERCENTILE({col_letter}35:{col_letter}40,0.25)",
        47: f"PERCENTILE({col_letter}35:{col_letter}40,0.75)",
    }
    for row in range(42, 48):
        ref = f"{col_letter}{row}"
        formula_map[ref] = stat_formulas[row]
        expected[ref] = stat_values[row]
        styles[ref] = task.style(ref)

for col_letter in "HIJKL":
    percentages = [expected[f"{col_letter}{row}"] for row in range(35, 41)]
    gdps = [expected[f"{col_letter}{row}"] for row in range(26, 32)]
    denominator = sum(gdps)
    weighted = sum(pct * gdp for pct, gdp in zip(percentages, gdps)) / denominator if denominator else 0.0
    ref = f"{col_letter}50"
    formula_map[ref] = (
        f"IFERROR(SUMPRODUCT({col_letter}35:{col_letter}40,{col_letter}26:{col_letter}31)/"
        f"SUM({col_letter}26:{col_letter}31),0)"
    )
    expected[ref] = weighted
    styles[ref] = task.style(ref)

connection.close()

task_xml_path = sheet_paths["Task"]
task_xml = task_xml_path.read_text(encoding="utf-8")
for ref in sorted(formula_map, key=lambda r: split_ref(r)):
    task_xml = patch_cell_xml(task_xml, ref, formula_map[ref], expected[ref])
task_xml_path.write_text(task_xml, encoding="utf-8")

zip_xlsx(UNPACK_DIR, STAGE_XLSX)

manifest = {
    "task_sheet_member": task_xml_path.relative_to(UNPACK_DIR).as_posix(),
    "formula_map": formula_map,
    "expected": expected,
    "styles": styles,
    "detected": {
        "task_year_row": task_year_row,
        "data_year_row": data_year_row,
        "series_column": series_col_letter,
        "years": task_years,
        "last_source_column": last_source_col_letter,
    },
}
MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True), encoding="utf-8")
print(
    f"Detected Task years at row {task_year_row}; Data years at row {data_year_row}; "
    f"series codes in column {series_col_letter}."
)
print(f"Generated {len(formula_map)} formula cells and independent cached values.")
PYTHON_SCRIPT

RECALC_XLSX=""
if [[ -n "${SOFFICE_BIN}" ]]; then
    rm -rf /tmp/gdp_lo_profile
    mkdir -p /tmp/gdp_lo_profile

    if "${SOFFICE_BIN}" \
        -env:UserInstallation=file:///tmp/gdp_lo_profile \
        --headless --convert-to ods --outdir "${ODS_DIR}" "${STAGE_XLSX}" \
        >"${WORK_ROOT}/lo_to_ods.log" 2>&1; then
        ODS_FILE="${ODS_DIR}/gdp_stage.ods"
        if [[ -s "${ODS_FILE}" ]]; then
            rm -rf /tmp/gdp_lo_profile
            mkdir -p /tmp/gdp_lo_profile
            if "${SOFFICE_BIN}" \
                -env:UserInstallation=file:///tmp/gdp_lo_profile \
                --headless --convert-to 'xlsx:Calc MS Excel 2007 XML' \
                --outdir "${RECALC_DIR}" "${ODS_FILE}" \
                >"${WORK_ROOT}/lo_to_xlsx.log" 2>&1; then
                if [[ -s "${RECALC_DIR}/gdp_stage.xlsx" ]]; then
                    RECALC_XLSX="${RECALC_DIR}/gdp_stage.xlsx"
                fi
            fi
        fi
    fi
fi
export RECALC_XLSX

python3 <<'PYTHON_SCRIPT'
from __future__ import annotations

import html
import json
import math
import os
import re
import shutil
import zipfile
from pathlib import Path, PurePosixPath
import xml.etree.ElementTree as ET

EXCEL_FILE = Path(os.environ["EXCEL_FILE"])
UNPACK_DIR = Path(os.environ["UNPACK_DIR"])
MANIFEST = Path(os.environ["MANIFEST"])
RECALC_XLSX = Path(os.environ["RECALC_XLSX"]) if os.environ.get("RECALC_XLSX") else None

MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
REL_DOC_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
REL_PKG_NS = "http://schemas.openxmlformats.org/package/2006/relationships"
NS = {"m": MAIN_NS, "r": REL_DOC_NS, "p": REL_PKG_NS}
CELL_REF_RE = re.compile(r"^([A-Z]+)([0-9]+)$")


def split_ref(ref: str) -> tuple[int, int]:
    match = CELL_REF_RE.match(ref)
    if not match:
        raise ValueError(ref)
    col = 0
    for ch in match.group(1):
        col = col * 26 + ord(ch) - 64
    return int(match.group(2)), col


def resolve_package_target(base: PurePosixPath, target: str) -> PurePosixPath:
    if target.startswith("/"):
        return PurePosixPath(target.lstrip("/"))
    combined = base.parent / target
    parts: list[str] = []
    for part in combined.parts:
        if part in ("", "."):
            continue
        if part == "..":
            if parts:
                parts.pop()
        else:
            parts.append(part)
    return PurePosixPath(*parts)


def sheet_member_from_xlsx(xlsx_path: Path, sheet_name: str) -> str:
    with zipfile.ZipFile(xlsx_path, "r") as archive:
        workbook_rel = PurePosixPath("xl/workbook.xml")
        workbook = ET.fromstring(archive.read(workbook_rel.as_posix()))
        rels = ET.fromstring(archive.read("xl/_rels/workbook.xml.rels"))
        targets = {
            rel.attrib["Id"]: rel.attrib["Target"]
            for rel in rels.findall("p:Relationship", NS)
        }
        for sheet in workbook.findall("m:sheets/m:sheet", NS):
            if sheet.attrib["name"] == sheet_name:
                rel_id = sheet.attrib[f"{{{REL_DOC_NS}}}id"]
                return resolve_package_target(workbook_rel, targets[rel_id]).as_posix()
    raise RuntimeError(f"Sheet {sheet_name!r} not found")


def read_formula_cells(xlsx_path: Path, sheet_name: str) -> dict[str, tuple[str | None, float | None, str | None]]:
    member = sheet_member_from_xlsx(xlsx_path, sheet_name)
    with zipfile.ZipFile(xlsx_path, "r") as archive:
        root = ET.fromstring(archive.read(member))
    result: dict[str, tuple[str | None, float | None, str | None]] = {}
    for cell in root.findall(".//m:sheetData/m:row/m:c", NS):
        ref = cell.attrib.get("r")
        if not ref:
            continue
        formula_node = cell.find("m:f", NS)
        value_node = cell.find("m:v", NS)
        formula = None if formula_node is None else (formula_node.text or "")
        value = None
        if value_node is not None and value_node.text not in (None, ""):
            try:
                value = float(value_node.text)
            except ValueError:
                pass
        result[ref] = (formula, value, cell.attrib.get("s"))
    return result


def patch_cached_value(xml_text: str, ref: str, formula: str, value: float) -> str:
    escaped_formula = html.escape(formula, quote=False)
    value_text = format(float(value), ".15g")
    pattern = re.compile(
        rf"<c\b(?P<attrs>[^>]*\br=([\"']){re.escape(ref)}\2[^>]*)>.*?</c>",
        re.DOTALL,
    )
    match = pattern.search(xml_text)
    if match is None:
        raise RuntimeError(f"Final target cell missing: {ref}")
    attrs = re.sub(r"\s+t=([\"']).*?\1", "", match.group("attrs"))
    replacement = f"<c{attrs}><f>{escaped_formula}</f><v>{value_text}</v></c>"
    return xml_text[: match.start()] + replacement + xml_text[match.end() :]


def zip_xlsx(source_dir: Path, destination: Path) -> None:
    temp = destination.with_suffix(destination.suffix + ".tmp")
    if temp.exists():
        temp.unlink()
    with zipfile.ZipFile(temp, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for path in sorted(source_dir.rglob("*")):
            if path.is_file():
                archive.write(path, path.relative_to(source_dir).as_posix())
    os.replace(temp, destination)


manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
formula_map = {str(k): str(v) for k, v in manifest["formula_map"].items()}
expected = {str(k): float(v) for k, v in manifest["expected"].items()}
styles = manifest["styles"]
task_member = manifest["task_sheet_member"]

cache_source = "independent SQLite/Python evaluator"
selected_values = dict(expected)

if RECALC_XLSX is not None and RECALC_XLSX.exists():
    calc_cells = read_formula_cells(RECALC_XLSX, "Task")
    complete = all(ref in calc_cells and calc_cells[ref][1] is not None for ref in formula_map)
    if complete:
        mismatches: list[str] = []
        candidate: dict[str, float] = {}
        for ref, expected_value in expected.items():
            actual = float(calc_cells[ref][1])
            candidate[ref] = actual
            tolerance = max(1e-7, abs(expected_value) * 1e-8)
            if not math.isfinite(actual) or abs(actual - expected_value) > tolerance:
                mismatches.append(f"{ref}: independent={expected_value}, Calc={actual}")
        if not mismatches:
            selected_values = candidate
            cache_source = "LibreOffice Calc, cross-checked against SQLite/Python"
        else:
            print("WARNING: LibreOffice cache comparison failed; " + "; ".join(mismatches[:5]))
    else:
        print("WARNING: LibreOffice did not return all formula caches; independent values retained.")

task_path = UNPACK_DIR / task_member
task_xml = task_path.read_text(encoding="utf-8")
for ref in sorted(formula_map, key=split_ref):
    task_xml = patch_cached_value(task_xml, ref, formula_map[ref], selected_values[ref])
task_path.write_text(task_xml, encoding="utf-8")
zip_xlsx(UNPACK_DIR, EXCEL_FILE)

with zipfile.ZipFile(EXCEL_FILE, "r") as archive:
    corrupt = archive.testzip()
    if corrupt is not None:
        raise RuntimeError(f"Corrupt XLSX member: {corrupt}")
    if any(name.endswith("vbaProject.bin") or name.endswith(".bin") for name in archive.namelist()):
        raise RuntimeError("Macro/binary project content was introduced")

final_cells = read_formula_cells(EXCEL_FILE, "Task")
for ref, formula in formula_map.items():
    actual_formula, actual_value, actual_style = final_cells.get(ref, (None, None, None))
    if actual_formula != formula:
        raise RuntimeError(f"Formula mismatch at {ref}: {actual_formula!r}")
    if actual_value is None or not math.isfinite(actual_value):
        raise RuntimeError(f"Missing numeric cache at {ref}")
    tolerance = max(1e-7, abs(expected[ref]) * 1e-8)
    if abs(actual_value - expected[ref]) > tolerance:
        raise RuntimeError(f"Cached value mismatch at {ref}: {actual_value} vs {expected[ref]}")
    if actual_style != styles.get(ref):
        raise RuntimeError(f"Style changed at {ref}: {actual_style!r} vs {styles.get(ref)!r}")

with zipfile.ZipFile(EXCEL_FILE, "r") as archive:
    workbook = ET.fromstring(archive.read("xl/workbook.xml"))
    sheet_names = [sheet.attrib["name"] for sheet in workbook.findall("m:sheets/m:sheet", NS)]
if sheet_names != ["Task", "Data"]:
    raise RuntimeError(f"Unexpected final sheets: {sheet_names}")

print(f"Validated {len(formula_map)} formulas and numeric caches.")
print(f"Cache source: {cache_source}.")
print(f"Output workbook: {EXCEL_FILE}")
PYTHON_SCRIPT

echo "Solution complete."
