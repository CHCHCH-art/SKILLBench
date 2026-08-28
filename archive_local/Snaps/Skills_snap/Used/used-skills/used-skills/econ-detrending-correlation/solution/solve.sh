#!/bin/bash
set -euo pipefail

ROOT="/root"
WORK="/root/alt_solution_work"
CONVERTED="${WORK}/converted"
RAW="${WORK}/raw_tsv"
NORMALIZED="${WORK}/normalized"
AUDIT="${WORK}/audit"

for input in \
  "${ROOT}/ERP-2025-table10.xls" \
  "${ROOT}/ERP-2025-table12.xls" \
  "${ROOT}/CPI.xlsx"; do
  if [ ! -f "${input}" ]; then
    echo "Missing required input: ${input}" >&2
    exit 1
  fi
done

if ! command -v libreoffice >/dev/null 2>&1; then
  apt-get update
  apt-get install -y --no-install-recommends libreoffice-calc
  rm -rf /var/lib/apt/lists/*
fi

rm -rf "${WORK}"
mkdir -p "${CONVERTED}" "${RAW}" "${NORMALIZED}" "${AUDIT}" "${WORK}/lo_profile"

libreoffice --headless --nologo --nodefault --nolockcheck --nofirststartwizard \
  "-env:UserInstallation=file://${WORK}/lo_profile" \
  --convert-to xlsx --outdir "${CONVERTED}" \
  "${ROOT}/ERP-2025-table10.xls" >/dev/null

libreoffice --headless --nologo --nodefault --nolockcheck --nofirststartwizard \
  "-env:UserInstallation=file://${WORK}/lo_profile" \
  --convert-to xlsx --outdir "${CONVERTED}" \
  "${ROOT}/ERP-2025-table12.xls" >/dev/null

cp "${ROOT}/CPI.xlsx" "${CONVERTED}/CPI.xlsx"

python3 <<'PY'
import csv
import os
import re
import zipfile
import xml.etree.ElementTree as ET

CONVERTED = "/root/alt_solution_work/converted"
RAW = "/root/alt_solution_work/raw_tsv"

NS_MAIN = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
NS_REL_DOC = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
NS_REL_PKG = "http://schemas.openxmlformats.org/package/2006/relationships"


def col_index(cell_ref: str) -> int:
    letters = re.match(r"[A-Z]+", cell_ref)
    if not letters:
        return 0
    value = 0
    for ch in letters.group(0):
        value = value * 26 + (ord(ch) - ord("A") + 1)
    return value - 1


def safe_name(text: str) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", text).strip("_")
    return cleaned or "sheet"


def all_text(node) -> str:
    return "".join((t.text or "") for t in node.findall(f".//{{{NS_MAIN}}}t"))


def parse_xlsx(path: str, out_dir: str) -> None:
    os.makedirs(out_dir, exist_ok=True)
    with zipfile.ZipFile(path) as zf:
        shared = []
        if "xl/sharedStrings.xml" in zf.namelist():
            root = ET.fromstring(zf.read("xl/sharedStrings.xml"))
            shared = [all_text(si) for si in root.findall(f"{{{NS_MAIN}}}si")]

        workbook = ET.fromstring(zf.read("xl/workbook.xml"))
        rels_root = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
        rels = {
            rel.attrib["Id"]: rel.attrib["Target"]
            for rel in rels_root.findall(f"{{{NS_REL_PKG}}}Relationship")
        }

        sheets = workbook.find(f"{{{NS_MAIN}}}sheets")
        if sheets is None:
            raise RuntimeError(f"Workbook has no sheets: {path}")

        manifest_rows = []
        for ordinal, sheet in enumerate(sheets, start=1):
            sheet_name = sheet.attrib.get("name", f"Sheet{ordinal}")
            rid = sheet.attrib[f"{{{NS_REL_DOC}}}id"]
            target = rels[rid].lstrip("/")
            if not target.startswith("xl/"):
                target = "xl/" + target
            target = os.path.normpath(target).replace("\\", "/")

            root = ET.fromstring(zf.read(target))
            output_rows = []
            for row in root.findall(f".//{{{NS_MAIN}}}sheetData/{{{NS_MAIN}}}row"):
                values = {}
                max_col = -1
                for cell in row.findall(f"{{{NS_MAIN}}}c"):
                    idx = col_index(cell.attrib.get("r", "A1"))
                    ctype = cell.attrib.get("t")
                    if ctype == "inlineStr":
                        value = all_text(cell)
                    else:
                        vnode = cell.find(f"{{{NS_MAIN}}}v")
                        raw = "" if vnode is None or vnode.text is None else vnode.text
                        if ctype == "s" and raw:
                            value = shared[int(raw)]
                        elif ctype == "b":
                            value = "TRUE" if raw == "1" else "FALSE"
                        else:
                            value = raw
                    values[idx] = value
                    max_col = max(max_col, idx)
                if max_col >= 0:
                    output_rows.append([values.get(i, "") for i in range(max_col + 1)])
                else:
                    output_rows.append([])

            out_name = f"sheet_{ordinal:02d}_{safe_name(sheet_name)}.tsv"
            out_path = os.path.join(out_dir, out_name)
            with open(out_path, "w", newline="", encoding="utf-8") as fh:
                writer = csv.writer(fh, delimiter="\t", lineterminator="\n")
                writer.writerows(output_rows)
            manifest_rows.append((ordinal, sheet_name, out_path, len(output_rows)))

        with open(os.path.join(out_dir, "manifest.tsv"), "w", newline="", encoding="utf-8") as fh:
            writer = csv.writer(fh, delimiter="\t", lineterminator="\n")
            writer.writerow(["ordinal", "sheet_name", "path", "rows"])
            writer.writerows(manifest_rows)


for filename in sorted(os.listdir(CONVERTED)):
    if filename.lower().endswith(".xlsx"):
        stem = os.path.splitext(filename)[0]
        parse_xlsx(os.path.join(CONVERTED, filename), os.path.join(RAW, stem))
PY

python3 <<'PY'
import csv
import datetime as dt
import glob
import math
import os
import re
from collections import defaultdict

RAW = "/root/alt_solution_work/raw_tsv"
OUT = "/root/alt_solution_work/normalized"
START_YEAR = 1973
END_YEAR = 2024


def read_tsv(path):
    with open(path, newline="", encoding="utf-8") as fh:
        return list(csv.reader(fh, delimiter="\t"))


def parse_number(value):
    s = str(value).strip().replace(",", "")
    if not s or s in {".", "..", "...", "—", "–", "-"}:
        return None
    negative = s.startswith("(") and s.endswith(")")
    if negative:
        s = s[1:-1].strip()
    match = re.search(r"[-+]?(?:\d+(?:\.\d*)?|\.\d+)(?:[Ee][-+]?\d+)?", s)
    if not match:
        return None
    value = float(match.group(0))
    return -value if negative else value


def candidate_sheets(book_stem):
    return sorted(glob.glob(os.path.join(RAW, book_stem, "sheet_*.tsv")))


def choose_erp_sheet(book_stem, title_phrase):
    best = None
    for path in candidate_sheets(book_stem):
        rows = read_tsv(path)
        flattened = " ".join(cell for row in rows[:12] for cell in row).lower()
        annual_hits = sum(
            1 for row in rows
            if row and re.fullmatch(r"\s*\d{4}\.\s*", row[0] or "")
        )
        quarter_hits = sum(
            1 for row in rows
            if row and re.match(r"\s*(?:\d{4}\s*:\s*)?(?:I|II|III|IV)\b", row[0] or "")
        )
        score = annual_hits * 10 + quarter_hits + (1000 if title_phrase in flattened else 0)
        if best is None or score > best[0]:
            best = (score, path, rows)
    if best is None or best[0] < 100:
        raise RuntimeError(f"Unable to identify ERP worksheet in {book_stem}")
    return best[1], best[2]


def extract_erp(book_stem, title_phrase, series_name):
    source_path, rows = choose_erp_sheet(book_stem, title_phrase)
    annual = {}
    quarters_2024 = []
    current_quarter_year = None

    for row in rows:
        label = row[0].strip() if row else ""
        value = parse_number(row[1]) if len(row) > 1 else None

        annual_match = re.fullmatch(r"\s*(\d{4})\.\s*", label)
        if annual_match and value is not None:
            year = int(annual_match.group(1))
            if START_YEAR <= year <= END_YEAR - 1:
                annual[year] = value
            current_quarter_year = None
            continue

        first_quarter = re.match(r"\s*(\d{4})\s*:\s*(I|II|III|IV)\b", label)
        if first_quarter:
            current_quarter_year = int(first_quarter.group(1))
            if current_quarter_year == END_YEAR and value is not None:
                quarters_2024.append(value)
            continue

        continuation = re.match(r"\s*(II|III|IV)\b", label)
        if continuation and current_quarter_year is not None:
            if current_quarter_year == END_YEAR and value is not None:
                quarters_2024.append(value)
            continue

        if current_quarter_year == END_YEAR and quarters_2024:
            current_quarter_year = None

    if not quarters_2024:
        raise RuntimeError(f"No available {END_YEAR} quarters found for {series_name}")
    annual[END_YEAR] = sum(quarters_2024) / len(quarters_2024)

    expected = set(range(START_YEAR, END_YEAR + 1))
    missing = sorted(expected - set(annual))
    if missing:
        raise RuntimeError(f"Missing {series_name} years: {missing}")

    output_path = os.path.join(OUT, f"{series_name.lower()}_annual.csv")
    with open(output_path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh, lineterminator="\n")
        writer.writerow(["Year", series_name])
        for year in range(START_YEAR, END_YEAR + 1):
            writer.writerow([year, format(annual[year], ".17g")])

    with open(os.path.join(OUT, f"{series_name.lower()}_source.txt"), "w", encoding="utf-8") as fh:
        fh.write(source_path + "\n")
        fh.write(f"quarters_used_for_{END_YEAR}={len(quarters_2024)}\n")


def parse_year(value):
    s = str(value).strip()
    if not s:
        return None
    direct = re.fullmatch(r"(19\d{2}|20\d{2})(?:\.0+)?", s)
    if direct:
        return int(direct.group(1))
    iso = re.match(r"(19\d{2}|20\d{2})[-/]\d{1,2}[-/]\d{1,2}", s)
    if iso:
        return int(iso.group(1))
    for fmt in ("%m/%d/%Y", "%Y-%m-%d", "%d/%m/%Y"):
        try:
            return dt.datetime.strptime(s, fmt).year
        except ValueError:
            pass
    numeric = parse_number(s)
    if numeric is not None and 20000 <= numeric <= 80000:
        return (dt.datetime(1899, 12, 30) + dt.timedelta(days=numeric)).year
    return None


def choose_cpi_sheet():
    best = None
    for path in candidate_sheets("CPI"):
        rows = read_tsv(path)
        year_hits = 0
        value_hits = 0
        for row in rows:
            if row and parse_year(row[0]) is not None:
                year_hits += 1
                if len(row) > 1 and parse_number(row[1]) is not None:
                    value_hits += 1
        score = year_hits + value_hits * 5
        if best is None or score > best[0]:
            best = (score, path, rows)
    if best is None or best[0] < 20:
        raise RuntimeError("Unable to identify CPI worksheet")
    return best[1], best[2]


def extract_cpi():
    source_path, rows = choose_cpi_sheet()
    grouped = defaultdict(list)
    for row in rows:
        if len(row) < 2:
            continue
        year = parse_year(row[0])
        value = parse_number(row[1])
        if year is not None and value is not None and START_YEAR <= year <= END_YEAR:
            grouped[year].append(value)

    annual = {year: sum(values) / len(values) for year, values in grouped.items()}
    expected = set(range(START_YEAR, END_YEAR + 1))
    missing = sorted(expected - set(annual))
    if missing:
        raise RuntimeError(f"Missing CPI years: {missing}")
    if any((not math.isfinite(v) or v <= 0) for v in annual.values()):
        raise RuntimeError("CPI must be finite and positive")

    output_path = os.path.join(OUT, "cpi_annual.csv")
    with open(output_path, "w", newline="", encoding="utf-8") as fh:
        writer = csv.writer(fh, lineterminator="\n")
        writer.writerow(["Year", "CPI"])
        for year in range(START_YEAR, END_YEAR + 1):
            writer.writerow([year, format(annual[year], ".17g")])

    with open(os.path.join(OUT, "cpi_source.txt"), "w", encoding="utf-8") as fh:
        fh.write(source_path + "\n")
        fh.write("annualization=mean_of_all_observations_within_each_year\n")


extract_erp("ERP-2025-table10", "personal consumption expenditures", "PCE")
extract_erp("ERP-2025-table12", "private fixed investment", "PFI")
extract_cpi()
PY

python3 <<'PY'
import csv
import math
import os
import numpy as np

NORMALIZED = "/root/alt_solution_work/normalized"
AUDIT = "/root/alt_solution_work/audit"
START_YEAR = 1973
END_YEAR = 2024
LAMBDA = 100.0


def load_series(filename, value_column):
    path = os.path.join(NORMALIZED, filename)
    result = {}
    with open(path, newline="", encoding="utf-8") as fh:
        for row in csv.DictReader(fh):
            result[int(row["Year"])] = float(row[value_column])
    return result


def hp_cycle(log_series, lamb):
    y = np.asarray(log_series, dtype=np.float64)
    n = y.size
    if n < 3:
        raise ValueError("HP filter needs at least three observations")

    D = np.zeros((n - 2, n), dtype=np.float64)
    indices = np.arange(n - 2)
    D[indices, indices] = 1.0
    D[indices, indices + 1] = -2.0
    D[indices, indices + 2] = 1.0

    normal_matrix = np.eye(n, dtype=np.float64) + lamb * (D.T @ D)
    trend = np.linalg.solve(normal_matrix, y)
    cycle = y - trend
    residual = normal_matrix @ trend - y
    return cycle, trend, float(np.max(np.abs(residual)))


pce = load_series("pce_annual.csv", "PCE")
pfi = load_series("pfi_annual.csv", "PFI")
cpi = load_series("cpi_annual.csv", "CPI")
years = list(range(START_YEAR, END_YEAR + 1))

for name, series in (("PCE", pce), ("PFI", pfi), ("CPI", cpi)):
    missing = [year for year in years if year not in series]
    if missing:
        raise RuntimeError(f"{name} is missing years: {missing}")

real_pce = np.array([pce[y] / cpi[y] for y in years], dtype=np.float64)
real_pfi = np.array([pfi[y] / cpi[y] for y in years], dtype=np.float64)
if np.any(real_pce <= 0) or np.any(real_pfi <= 0):
    raise RuntimeError("Real series must be positive before taking logarithms")

log_pce = np.log(real_pce)
log_pfi = np.log(real_pfi)
cycle_pce, trend_pce, residual_pce = hp_cycle(log_pce, LAMBDA)
cycle_pfi, trend_pfi, residual_pfi = hp_cycle(log_pfi, LAMBDA)

pce_centered = cycle_pce - cycle_pce.mean()
pfi_centered = cycle_pfi - cycle_pfi.mean()
denominator = math.sqrt(float(pce_centered @ pce_centered) * float(pfi_centered @ pfi_centered))
if denominator == 0.0:
    raise RuntimeError("Cannot compute correlation for a zero-variance cycle")
correlation = float((pce_centered @ pfi_centered) / denominator)

merged_path = os.path.join(AUDIT, "merged_real_log_trend_cycle.csv")
with open(merged_path, "w", newline="", encoding="utf-8") as fh:
    writer = csv.writer(fh, lineterminator="\n")
    writer.writerow([
        "Year", "Nominal_PCE", "Nominal_PFI", "CPI", "Real_PCE", "Real_PFI",
        "Log_Real_PCE", "Log_Real_PFI", "Trend_PCE", "Trend_PFI", "Cycle_PCE", "Cycle_PFI"
    ])
    for i, year in enumerate(years):
        writer.writerow([
            year, format(pce[year], ".17g"), format(pfi[year], ".17g"), format(cpi[year], ".17g"),
            format(real_pce[i], ".17g"), format(real_pfi[i], ".17g"),
            format(log_pce[i], ".17g"), format(log_pfi[i], ".17g"),
            format(trend_pce[i], ".17g"), format(trend_pfi[i], ".17g"),
            format(cycle_pce[i], ".17g"), format(cycle_pfi[i], ".17g")
        ])

with open(os.path.join(AUDIT, "normal_equation_residuals.txt"), "w", encoding="utf-8") as fh:
    fh.write(f"PCE={residual_pce:.17g}\n")
    fh.write(f"PFI={residual_pfi:.17g}\n")

if max(residual_pce, residual_pfi) > 1e-10:
    raise RuntimeError("HP normal-equation residual is unexpectedly large")

with open(os.path.join(AUDIT, "candidate_answer.txt"), "w", encoding="utf-8") as fh:
    fh.write(f"{correlation:.17g}\n")
PY

python3 <<'PY'
import csv
import math

AUDIT_CSV = "/root/alt_solution_work/audit/merged_real_log_trend_cycle.csv"
CANDIDATE = "/root/alt_solution_work/audit/candidate_answer.txt"
OUTPUT = "/root/answer.txt"

x = []
y = []
with open(AUDIT_CSV, newline="", encoding="utf-8") as fh:
    for row in csv.DictReader(fh):
        x.append(float(row["Cycle_PCE"]))
        y.append(float(row["Cycle_PFI"]))

mx = sum(x) / len(x)
my = sum(y) / len(y)
num = sum((a - mx) * (b - my) for a, b in zip(x, y))
den = math.sqrt(sum((a - mx) ** 2 for a in x) * sum((b - my) ** 2 for b in y))
verified = num / den

with open(CANDIDATE, encoding="utf-8") as fh:
    candidate = float(fh.read().strip())
if not math.isclose(verified, candidate, rel_tol=0.0, abs_tol=1e-12):
    raise RuntimeError("Independent correlation verification failed")

with open(OUTPUT, "w", encoding="utf-8") as fh:
    fh.write(f"{verified:.5f}\n")
PY