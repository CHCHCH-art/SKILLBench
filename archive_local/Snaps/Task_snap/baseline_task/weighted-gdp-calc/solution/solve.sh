#!/usr/bin/env bash
set -euo pipefail

EXCEL_FILE="${EXCEL_FILE:-/root/gdp.xlsx}"
UNO_PY="${UNO_PY:-/usr/bin/python3}"
[[ -r "$EXCEL_FILE" ]] || { echo "Missing workbook: $EXCEL_FILE" >&2; exit 1; }
command -v libreoffice >/dev/null 2>&1 || { echo "libreoffice is required" >&2; exit 1; }
[[ -x "$UNO_PY" ]] || { echo "UNO Python not found: $UNO_PY" >&2; exit 1; }

"$UNO_PY" - "$EXCEL_FILE" <<'PY'
from __future__ import annotations

import math
import os
import re
import shutil
import socket
import subprocess
import sys
import tempfile
import time

import uno
from com.sun.star.beans import PropertyValue

path = os.path.abspath(sys.argv[1])


def prop(name, value):
    p = PropertyValue(); p.Name = name; p.Value = value; return p


def col_name(c0):
    n = c0 + 1; s = ""
    while n:
        n, r = divmod(n - 1, 26); s = chr(65 + r) + s
    return s


def text(sheet, c0, r0):
    cell = sheet.getCellByPosition(c0, r0)
    s = cell.getString().strip()
    if s:
        return s
    v = cell.getValue()
    if v and float(v).is_integer(): return str(int(v))
    return str(v) if v else ""


def open_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0)); return s.getsockname()[1]


profile = tempfile.mkdtemp(prefix="lo-gdp-profile-")
port = open_port()
proc = subprocess.Popen([
    shutil.which("libreoffice"), "--headless", "--nologo", "--nodefault",
    "--nofirststartwizard", "--norestore", "--nolockcheck",
    f"-env:UserInstallation=file://{profile}",
    f"--accept=socket,host=127.0.0.1,port={port};urp;StarOffice.ServiceManager",
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
doc = None
try:
    ctx = uno.getComponentContext()
    resolver = ctx.ServiceManager.createInstanceWithContext("com.sun.star.bridge.UnoUrlResolver", ctx)
    remote = None
    deadline = time.time() + 20
    while time.time() < deadline:
        try:
            remote = resolver.resolve(f"uno:socket,host=127.0.0.1,port={port};urp;StarOffice.ComponentContext")
            break
        except Exception:
            if proc.poll() is not None: raise RuntimeError("LibreOffice exited during startup")
            time.sleep(0.1)
    if remote is None: raise RuntimeError("UNO connection timeout")
    desktop = remote.ServiceManager.createInstanceWithContext("com.sun.star.frame.Desktop", remote)
    doc = desktop.loadComponentFromURL(uno.systemPathToFileUrl(path), "_blank", 0, (prop("Hidden", True), prop("ReadOnly", False)))
    if doc is None: raise RuntimeError("Could not open workbook")

    sheets = doc.getSheets()
    names = list(sheets.getElementNames())
    if names != ["Task", "Data"]:
        raise RuntimeError(f"Workbook must contain exactly Task, Data; got {names}")
    task = sheets.getByName("Task"); data = sheets.getByName("Data")

    # Task years are the five populated year labels in H:L. Source schema is
    # discovered from Data headers rather than fixed source columns.
    task_years = [text(task, c, 8) for c in range(7, 12)]
    if len(set(task_years)) != 5 or not all(re.fullmatch(r"\d{4}", y) for y in task_years):
        raise RuntimeError(f"Unexpected Task year headers: {task_years}")

    header_row = None; series_col = None; year_cols = {}
    for r in range(0, 20):
        row_text = [text(data, c, r) for c in range(0, 64)]
        for c, value in enumerate(row_text):
            compact = value.casefold().replace(" ", "").replace("_", "")
            if compact == "seriescode": series_col = c
        found = {value: c for c, value in enumerate(row_text) if value in task_years}
        if len(found) == len(task_years):
            header_row = r; year_cols = found
        if header_row is not None and series_col is not None:
            break
    if header_row is None or series_col is None:
        raise RuntimeError("Could not identify Data series-code/year schema")

    # Source range is explicitly constrained by the task to rows 21:40.
    source_start, source_end = 20, 39  # zero-based
    source_codes = {}
    for r in range(source_start, source_end + 1):
        code = text(data, series_col, r)
        if code:
            if code in source_codes: raise RuntimeError(f"Duplicate Data series code {code}")
            source_codes[code] = r
    required_rows = list(range(11, 17)) + list(range(18, 24)) + list(range(25, 31))  # zero-based Task
    required_codes = [text(task, 3, r) for r in required_rows]
    if any(code not in source_codes for code in required_codes):
        missing = [c for c in required_codes if c not in source_codes]
        raise RuntimeError(f"Missing required Data series codes: {missing[:5]}")

    last_source_col = max([series_col] + list(year_cols.values()))
    last_col = col_name(last_source_col)
    series_letter = col_name(series_col)
    data_header_excel = header_row + 1

    # Step 1: INDEX + two MATCH conditions (series code and year).
    for r0 in required_rows:
        excel_row = r0 + 1
        for c0 in range(7, 12):
            c = col_name(c0)
            formula = (
                f"=INDEX($Data.$A$21:${last_col}$40;"
                f"MATCH($D{excel_row};$Data.${series_letter}$21:${series_letter}$40;0);"
                f"MATCH({c}$9;$Data.$A${data_header_excel}:${last_col}${data_header_excel};0))"
            )
            task.getCellByPosition(c0, r0).setFormula(formula)

    # Step 2: net exports % and descriptive statistics.
    for offset, r0 in enumerate(range(34, 40)):
        export_row, import_row, gdp_row = 12 + offset, 19 + offset, 26 + offset
        for c0 in range(7, 12):
            c = col_name(c0)
            task.getCellByPosition(c0, r0).setFormula(
                f"=IFERROR(({c}{export_row}-{c}{import_row})/{c}{gdp_row}*100;0)"
            )

    stats = {
        41: "MIN", 42: "MAX", 43: "MEDIAN", 44: "AVERAGE",
        45: "PERCENTILE", 46: "PERCENTILE",
    }
    for c0 in range(7, 12):
        c = col_name(c0)
        task.getCellByPosition(c0, 41).setFormula(f"=MIN({c}35:{c}40)")
        task.getCellByPosition(c0, 42).setFormula(f"=MAX({c}35:{c}40)")
        task.getCellByPosition(c0, 43).setFormula(f"=MEDIAN({c}35:{c}40)")
        task.getCellByPosition(c0, 44).setFormula(f"=AVERAGE({c}35:{c}40)")
        task.getCellByPosition(c0, 45).setFormula(f"=PERCENTILE({c}35:{c}40;0.25)")
        task.getCellByPosition(c0, 46).setFormula(f"=PERCENTILE({c}35:{c}40;0.75)")
        # Step 3 must use SUMPRODUCT.
        task.getCellByPosition(c0, 49).setFormula(
            f"=IFERROR(SUMPRODUCT({c}35:{c}40;{c}26:{c}31)/SUM({c}26:{c}31);0)"
        )

    doc.calculateAll()
    # Validate the intended formula cells evaluated numerically before writing.
    check_ranges = [(11,16), (18,23), (25,30), (34,39), (41,46), (49,49)]
    for r1, r2 in check_ranges:
        for r0 in range(r1, r2 + 1):
            for c0 in range(7, 12):
                cell = task.getCellByPosition(c0, r0)
                if not cell.getFormula().startswith("="):
                    raise RuntimeError(f"Missing formula at {col_name(c0)}{r0+1}")
                if not math.isfinite(cell.getValue()):
                    raise RuntimeError(f"Non-finite value at {col_name(c0)}{r0+1}")
    doc.store()
finally:
    if doc is not None:
        try: doc.close(True)
        except Exception: pass
    try:
        proc.terminate(); proc.wait(timeout=5)
    except Exception:
        try: proc.kill()
        except Exception: pass
    shutil.rmtree(profile, ignore_errors=True)
PY
