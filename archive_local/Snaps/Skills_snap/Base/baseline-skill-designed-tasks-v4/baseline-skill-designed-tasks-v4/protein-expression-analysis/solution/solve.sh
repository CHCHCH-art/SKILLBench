#!/bin/bash
set -euo pipefail

EXCEL_FILE="/root/protein_expression.xlsx"
WORK_DIR="/tmp/protein_expression_formula_pipeline"
FORMULA_FILE="${WORK_DIR}/formula_source.xlsx"
RECALC_DIR="${WORK_DIR}/recalculated"
RECALC_FILE="${RECALC_DIR}/formula_source.xlsx"
FINAL_FILE="${WORK_DIR}/final.xlsx"
LO_PROFILE="${WORK_DIR}/lo_profile"

PYTHON_BIN="$(command -v python3)"

if [ ! -f "${EXCEL_FILE}" ]; then
    echo "Missing input workbook: ${EXCEL_FILE}" >&2
    exit 1
fi

/bin/rm -rf "${WORK_DIR}"
/bin/mkdir -p "${WORK_DIR}" "${RECALC_DIR}" "${LO_PROFILE}"

if command -v libreoffice >/dev/null 2>&1; then
    LIBREOFFICE_BIN="$(command -v libreoffice)"
elif command -v soffice >/dev/null 2>&1; then
    LIBREOFFICE_BIN="$(command -v soffice)"
else
    if [ ! -x /usr/bin/apt-get ]; then
        echo "LibreOffice is not installed and apt-get is unavailable." >&2
        exit 1
    fi
    /usr/bin/apt-get update
    DEBIAN_FRONTEND=noninteractive /usr/bin/apt-get install -y --no-install-recommends libreoffice-calc
    /bin/rm -rf /var/lib/apt/lists/*
    if command -v libreoffice >/dev/null 2>&1; then
        LIBREOFFICE_BIN="$(command -v libreoffice)"
    else
        LIBREOFFICE_BIN="$(command -v soffice)"
    fi
fi

"${PYTHON_BIN}" <<'PYTHON_SCRIPT'
from collections import defaultdict
from openpyxl import load_workbook
from openpyxl.utils import absolute_coordinate, get_column_letter, quote_sheetname

INPUT = "/root/protein_expression.xlsx"
OUTPUT = "/tmp/protein_expression_formula_pipeline/formula_source.xlsx"

wb = load_workbook(INPUT, data_only=False)
if "Task" not in wb.sheetnames or "Data" not in wb.sheetnames:
    raise RuntimeError("Workbook must contain both 'Task' and 'Data' sheets")

task = wb["Task"]
data = wb["Data"]

protein_rows = defaultdict(list)
for r in range(2, data.max_row + 1):
    value = data.cell(r, 1).value
    if value is not None and str(value).strip() != "":
        protein_rows[str(value)].append(r)

sample_cols = defaultdict(list)
for c in range(2, data.max_column + 1):
    value = data.cell(1, c).value
    if value is not None and str(value).strip() != "":
        sample_cols[str(value)].append(c)

target_rows = list(range(11, 21))
target_cols = list(range(3, 13))  # C:L

target_proteins = []
for r in target_rows:
    value = task.cell(r, 1).value
    if value is None or str(value).strip() == "":
        raise RuntimeError(f"Missing target protein ID at Task!A{r}")
    target_proteins.append(str(value))

sample_names = []
for c in target_cols:
    value = task.cell(10, c).value
    if value is None or str(value).strip() == "":
        raise RuntimeError(f"Missing sample name at Task!{get_column_letter(c)}10")
    sample_names.append(str(value))

group_cells = {}
for c in target_cols:
    raw = task.cell(9, c).value
    if raw is None:
        continue
    normalized = str(raw).strip().casefold()
    if normalized == "control" and "control" not in group_cells:
        group_cells["control"] = absolute_coordinate(task.cell(9, c).coordinate)
    elif normalized == "treated" and "treated" not in group_cells:
        group_cells["treated"] = absolute_coordinate(task.cell(9, c).coordinate)

if set(group_cells) != {"control", "treated"}:
    raise RuntimeError("Task row 9 must contain both Control and Treated groups")

labels = [str(task.cell(9, c).value).strip().casefold() for c in target_cols]
if labels.count("control") < 2 or labels.count("treated") < 2:
    raise RuntimeError("Control and Treated each need at least two samples for STDEV.S")

data_sheet_ref = quote_sheetname(data.title)

for task_r, protein_id in zip(target_rows, target_proteins):
    rows = protein_rows.get(protein_id, [])
    if len(rows) != 1:
        raise RuntimeError(
            f"Protein ID {protein_id!r} resolves to {len(rows)} rows in Data; expected exactly one"
        )
    data_r = rows[0]

    for task_c, sample_name in zip(target_cols, sample_names):
        cols = sample_cols.get(sample_name, [])
        if len(cols) != 1:
            raise RuntimeError(
                f"Sample {sample_name!r} resolves to {len(cols)} columns in Data; expected exactly one"
            )
        data_c = cols[0]
        source = absolute_coordinate(data.cell(data_r, data_c).coordinate)
        task.cell(task_r, task_c).value = f"={data_sheet_ref}!{source}"

group_range = "$C$9:$L$9"
control_ref = group_cells["control"]
treated_ref = group_cells["treated"]

for i, task_r in enumerate(target_rows):
    out_c = 2 + i  # B:K
    out_col = get_column_letter(out_c)
    value_range = f"$C{task_r}:$L{task_r}"

    ctrl_mean_cell = f"{out_col}24"
    treat_mean_cell = f"{out_col}26"

    ctrl_n = f"COUNTIF({group_range},{control_ref})"
    treat_n = f"COUNTIF({group_range},{treated_ref})"

    task.cell(24, out_c).value = (
        f"=SUMIF({group_range},{control_ref},{value_range})/{ctrl_n}"
    )
    task.cell(25, out_c).value = (
        f"=IF({ctrl_n}>1,"
        f"SQRT((SUMPRODUCT(--({group_range}={control_ref}),{value_range}*{value_range})"
        f"-{ctrl_n}*{ctrl_mean_cell}^2)/({ctrl_n}-1)),0)"
    )
    task.cell(26, out_c).value = (
        f"=SUMIF({group_range},{treated_ref},{value_range})/{treat_n}"
    )
    task.cell(27, out_c).value = (
        f"=IF({treat_n}>1,"
        f"SQRT((SUMPRODUCT(--({group_range}={treated_ref}),{value_range}*{value_range})"
        f"-{treat_n}*{treat_mean_cell}^2)/({treat_n}-1)),0)"
    )

def classify_fold_header(value):
    text = "" if value is None else str(value).strip().casefold()
    compact = "".join(ch for ch in text if ch.isalnum())
    if "log2" in compact and ("fold" in compact or "fc" in compact):
        return "log2fc"
    if "foldchange" in compact or compact in {"fc", "fold"}:
        return "fc"
    return None

fold_cols = {}
for c in (3, 4):
    kind = classify_fold_header(task.cell(31, c).value)
    if kind and kind not in fold_cols:
        fold_cols[kind] = c

if set(fold_cols) != {"fc", "log2fc"}:
    raise RuntimeError(
        "Task row 31 must identify one Fold Change column and one Log2 Fold Change column in C:D"
    )
fc_col = fold_cols["fc"]
log2_col = fold_cols["log2fc"]

for i, row in enumerate(range(32, 42)):
    stats_col = get_column_letter(2 + i)  # B:K
    ctrl_mean = f"{stats_col}24"
    treat_mean = f"{stats_col}26"
    log2_addr = f"{get_column_letter(log2_col)}{row}"

    task.cell(row, log2_col).value = f"={treat_mean}-{ctrl_mean}"
    task.cell(row, fc_col).value = f"=POWER(2,{log2_addr})"

calc = getattr(wb, "calculation", None)
if calc is not None:
    calc.calcMode = "auto"
    calc.fullCalcOnLoad = True
    calc.forceFullCalc = True

wb.save(OUTPUT)
wb.close()
PYTHON_SCRIPT

PROFILE_URI="file://${LO_PROFILE}"
"${LIBREOFFICE_BIN}" \
    --headless \
    --nologo \
    --nodefault \
    --nofirststartwizard \
    "-env:UserInstallation=${PROFILE_URI}" \
    --convert-to 'xlsx:Calc MS Excel 2007 XML' \
    --outdir "${RECALC_DIR}" \
    "${FORMULA_FILE}" >/tmp/protein_expression_formula_pipeline/libreoffice.log 2>&1

if [ ! -f "${RECALC_FILE}" ]; then
    /bin/cat /tmp/protein_expression_formula_pipeline/libreoffice.log >&2 || true
    echo "LibreOffice did not produce the recalculated workbook." >&2
    exit 1
fi

"${PYTHON_BIN}" <<'PYTHON_SCRIPT'
import math
import os
import re
from xml.etree import ElementTree as ET
from zipfile import ZIP_DEFLATED, ZipFile
from openpyxl import load_workbook

SOURCE = "/tmp/protein_expression_formula_pipeline/formula_source.xlsx"
RECALC = "/tmp/protein_expression_formula_pipeline/recalculated/formula_source.xlsx"
FINAL = "/tmp/protein_expression_formula_pipeline/final.xlsx"
OUTPUT = "/root/protein_expression.xlsx"
SHEET_NAME = "Task"

MAIN_NS = "http://schemas.openxmlformats.org/spreadsheetml/2006/main"
DOC_REL_NS = "http://schemas.openxmlformats.org/officeDocument/2006/relationships"
PKG_REL_NS = "http://schemas.openxmlformats.org/package/2006/relationships"


def sheet_xml_path(xlsx_path, sheet_name):
    with ZipFile(xlsx_path, "r") as zf:
        workbook_root = ET.fromstring(zf.read("xl/workbook.xml"))
        rel_id = None
        for sheet in workbook_root.findall(f".//{{{MAIN_NS}}}sheet"):
            if sheet.get("name") == sheet_name:
                rel_id = sheet.get(f"{{{DOC_REL_NS}}}id")
                break
        if rel_id is None:
            raise RuntimeError(f"Sheet {sheet_name!r} not found in {xlsx_path}")

        rel_root = ET.fromstring(zf.read("xl/_rels/workbook.xml.rels"))
        target = None
        for rel in rel_root.findall(f"{{{PKG_REL_NS}}}Relationship"):
            if rel.get("Id") == rel_id:
                target = rel.get("Target")
                break
        if target is None:
            raise RuntimeError(f"Relationship for sheet {sheet_name!r} not found")

        if target.startswith("/"):
            return target.lstrip("/")
        return "xl/" + target.lstrip("/")


def cached_values_from_sheet(xml_bytes, wanted_addresses):
    root = ET.fromstring(xml_bytes)
    values = {}
    for cell in root.findall(f".//{{{MAIN_NS}}}c"):
        addr = cell.get("r")
        if addr not in wanted_addresses:
            continue
        v = cell.find(f"{{{MAIN_NS}}}v")
        if v is None or v.text is None or v.text == "":
            raise RuntimeError(f"No cached value produced for {SHEET_NAME}!{addr}")
        values[addr] = v.text
    missing = wanted_addresses.difference(values)
    if missing:
        raise RuntimeError(f"Recalculated workbook is missing cells: {sorted(missing)}")
    return values


def patch_cached_values_preserving_xml(xml_bytes, values):
    result = xml_bytes
    for addr, numeric_text in values.items():
        addr_b = re.escape(addr.encode("ascii"))
        cell_re = re.compile(
            rb'(<c\b[^>]*\br="' + addr_b + rb'"[^>]*>)(.*?)(</c>)',
            re.DOTALL,
        )
        match = cell_re.search(result)
        if match is None:
            raise RuntimeError(f"Formula cell {SHEET_NAME}!{addr} not found in source XML")

        body = match.group(2)
        replacement_v = b"<v>" + numeric_text.encode("ascii") + b"</v>"

        if re.search(rb"<v\b[^>]*/>", body, flags=re.DOTALL):
            new_body = re.sub(rb"<v\b[^>]*/>", replacement_v, body, count=1, flags=re.DOTALL)
        elif re.search(rb"<v\b[^>]*>.*?</v>", body, flags=re.DOTALL):
            new_body = re.sub(
                rb"<v\b[^>]*>.*?</v>", replacement_v, body, count=1, flags=re.DOTALL
            )
        else:
            new_body = body + replacement_v

        start, end = match.span(2)
        result = result[:start] + new_body + result[end:]
    return result


required = set()
for row in range(11, 21):
    for col in "CDEFGHIJKL":
        required.add(f"{col}{row}")
for row in range(24, 28):
    for col in "BCDEFGHIJK":
        required.add(f"{col}{row}")
for row in range(32, 42):
    required.add(f"C{row}")
    required.add(f"D{row}")

source_sheet_path = sheet_xml_path(SOURCE, SHEET_NAME)
recalc_sheet_path = sheet_xml_path(RECALC, SHEET_NAME)

with ZipFile(RECALC, "r") as recalc_zip:
    cached = cached_values_from_sheet(recalc_zip.read(recalc_sheet_path), required)

with ZipFile(SOURCE, "r") as source_zip:
    source_task_xml = source_zip.read(source_sheet_path)
    patched_task_xml = patch_cached_values_preserving_xml(source_task_xml, cached)

    with ZipFile(FINAL, "w", compression=ZIP_DEFLATED) as out_zip:
        for info in source_zip.infolist():
            payload = patched_task_xml if info.filename == source_sheet_path else source_zip.read(info.filename)
            out_zip.writestr(info, payload)

wb_formula = load_workbook(FINAL, data_only=False, read_only=True)
wb_values = load_workbook(FINAL, data_only=True, read_only=True)
try:
    task_f = wb_formula[SHEET_NAME]
    task_v = wb_values[SHEET_NAME]
    for addr in sorted(required):
        formula = task_f[addr].value
        value = task_v[addr].value
        if not isinstance(formula, str) or not formula.startswith("="):
            raise RuntimeError(f"Expected formula at {SHEET_NAME}!{addr}, got {formula!r}")
        if not isinstance(value, (int, float)) or isinstance(value, bool) or not math.isfinite(float(value)):
            raise RuntimeError(f"Expected finite cached numeric value at {SHEET_NAME}!{addr}, got {value!r}")
finally:
    wb_formula.close()
    wb_values.close()

os.replace(FINAL, OUTPUT)
print(f"Completed formula-based protein expression analysis: {OUTPUT}")
PYTHON_SCRIPT
