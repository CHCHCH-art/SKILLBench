#!/usr/bin/env bash
set -euo pipefail

EXCEL_FILE="${EXCEL_FILE:-/root/protein_expression.xlsx}"
[[ -r "$EXCEL_FILE" ]] || { echo "Missing workbook: $EXCEL_FILE" >&2; exit 1; }

UNO_PY="${UNO_PY:-/usr/bin/python3}"
command -v libreoffice >/dev/null 2>&1 || { echo "libreoffice is required" >&2; exit 1; }
[[ -x "$UNO_PY" ]] || { echo "UNO Python not found: $UNO_PY" >&2; exit 1; }

"$UNO_PY" - "$EXCEL_FILE" <<'PY'
from __future__ import annotations

import os
import math
import shutil
import socket
import subprocess
import sys
import tempfile
import time
from pathlib import Path

import uno
from com.sun.star.beans import PropertyValue

path = os.path.abspath(sys.argv[1])


def prop(name, value):
    p = PropertyValue()
    p.Name = name
    p.Value = value
    return p


def col_name(index0: int) -> str:
    n = index0 + 1
    out = ""
    while n:
        n, r = divmod(n - 1, 26)
        out = chr(65 + r) + out
    return out


def cell_text(sheet, col0, row0):
    c = sheet.getCellByPosition(col0, row0)
    s = c.getString()
    if s != "":
        return s.strip()
    # Numeric-looking labels occasionally arrive as values.
    v = c.getValue()
    return str(int(v)) if v and float(v).is_integer() else (str(v) if v else "")


def find_open_port():
    with socket.socket() as s:
        s.bind(("127.0.0.1", 0))
        return s.getsockname()[1]


profile = tempfile.mkdtemp(prefix="lo-protein-profile-")
port = find_open_port()
accept = f"socket,host=127.0.0.1,port={port};urp;StarOffice.ServiceManager"
proc = subprocess.Popen([
    shutil.which("libreoffice"), "--headless", "--nologo", "--nodefault",
    "--nofirststartwizard", "--norestore", "--nolockcheck",
    f"-env:UserInstallation=file://{profile}", f"--accept={accept}",
], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

doc = None
try:
    local_ctx = uno.getComponentContext()
    resolver = local_ctx.ServiceManager.createInstanceWithContext(
        "com.sun.star.bridge.UnoUrlResolver", local_ctx
    )
    remote_ctx = None
    deadline = time.time() + 20
    while time.time() < deadline:
        try:
            remote_ctx = resolver.resolve(
                f"uno:socket,host=127.0.0.1,port={port};urp;StarOffice.ComponentContext"
            )
            break
        except Exception:
            if proc.poll() is not None:
                raise RuntimeError("LibreOffice exited before UNO connection")
            time.sleep(0.1)
    if remote_ctx is None:
        raise RuntimeError("Timed out connecting to LibreOffice UNO")

    smgr = remote_ctx.ServiceManager
    desktop = smgr.createInstanceWithContext("com.sun.star.frame.Desktop", remote_ctx)
    url = uno.systemPathToFileUrl(path)
    doc = desktop.loadComponentFromURL(url, "_blank", 0, (prop("Hidden", True), prop("ReadOnly", False)))
    if doc is None:
        raise RuntimeError("LibreOffice could not open workbook")

    sheets = doc.getSheets()
    if not (sheets.hasByName("Task") and sheets.hasByName("Data")):
        raise RuntimeError("Workbook must contain Task and Data sheets")
    task = sheets.getByName("Task")
    data = sheets.getByName("Data")

    proteins = [cell_text(task, 0, r) for r in range(10, 20)]
    samples = [cell_text(task, c, 9) for c in range(2, 12)]
    groups = [cell_text(task, c, 8).casefold() for c in range(2, 12)]
    if any(not x for x in proteins + samples):
        raise RuntimeError("Task target proteins or sample names are incomplete")
    if groups.count("control") < 2 or groups.count("treated") < 2:
        raise RuntimeError("Task row 9 must include at least two Control and Treated samples")

    # Discover the rectangular Data table by semantic keys; no source coordinates are assumed.
    sample_cols = {}
    blank_run = 0
    for c in range(0, 512):
        value = cell_text(data, c, 0)
        if value:
            sample_cols.setdefault(value, []).append(c)
            blank_run = 0
        else:
            blank_run += 1
            if c > 16 and blank_run >= 16:
                break
    protein_rows = {}
    blank_run = 0
    for r in range(1, 10000):
        value = cell_text(data, 0, r)
        if value:
            protein_rows.setdefault(value, []).append(r)
            blank_run = 0
        else:
            blank_run += 1
            if r > 32 and blank_run >= 32:
                break

    for p in proteins:
        if len(protein_rows.get(p, [])) != 1:
            raise RuntimeError(f"Protein {p!r} is not unique in Data")
    for s in samples:
        if len(sample_cols.get(s, [])) != 1:
            raise RuntimeError(f"Sample {s!r} is not unique in Data")

    last_data_row = max(r for rows in protein_rows.values() for r in rows) + 1
    last_data_col = max(c for cols in sample_cols.values() for c in cols)
    data_last_col_name = col_name(last_data_col)

    # Step 1: two-condition INDEX/MATCH formulas. Calc uses ';' internally and exports them to XLSX.
    for pr, task_row0 in enumerate(range(10, 20)):
        excel_row = task_row0 + 1
        for task_col0 in range(2, 12):
            sample_col = col_name(task_col0)
            formula = (
                f"=INDEX($Data.$A$1:${data_last_col_name}${last_data_row};"
                f"MATCH($A{excel_row};$Data.$A$1:$A${last_data_row};0);"
                f"MATCH({sample_col}$10;$Data.$A$1:${data_last_col_name}$1;0))"
            )
            task.getCellByPosition(task_col0, task_row0).setFormula(formula)

    control_cols = [col_name(c) for c, g in zip(range(2, 12), groups) if g == "control"]
    treated_cols = [col_name(c) for c, g in zip(range(2, 12), groups) if g == "treated"]
    if set(groups) - {"control", "treated"}:
        raise RuntimeError("Unexpected group labels in Task row 9")

    def refs(cols, row):
        return ";".join(f"{c}{row}" for c in cols)

    # Step 2: each B:K column corresponds to one target protein.
    for i in range(10):
        out_col0 = 1 + i
        source_row = 11 + i
        ctrl = refs(control_cols, source_row)
        treat = refs(treated_cols, source_row)
        task.getCellByPosition(out_col0, 23).setFormula(f"=AVERAGE({ctrl})")
        task.getCellByPosition(out_col0, 24).setFormula(f"=STDEV.S({ctrl})")
        task.getCellByPosition(out_col0, 25).setFormula(f"=AVERAGE({treat})")
        task.getCellByPosition(out_col0, 26).setFormula(f"=STDEV.S({treat})")

    def classify(header):
        compact = "".join(ch for ch in header.casefold() if ch.isalnum())
        if "log2" in compact and ("fold" in compact or "fc" in compact):
            return "log2"
        if "foldchange" in compact or compact in {"fc", "fold"}:
            return "fc"
        return None

    fold_cols = {}
    for c in (2, 3):
        kind = classify(cell_text(task, c, 30))
        if kind:
            fold_cols[kind] = c
    if set(fold_cols) != {"fc", "log2"}:
        raise RuntimeError("Could not identify Fold Change and Log2 Fold Change columns")

    for i, row0 in enumerate(range(31, 41)):
        stats_col = col_name(1 + i)
        log2_cell = f"{col_name(fold_cols['log2'])}{row0 + 1}"
        task.getCellByPosition(fold_cols["log2"], row0).setFormula(f"={stats_col}26-{stats_col}24")
        task.getCellByPosition(fold_cols["fc"], row0).setFormula(f"=POWER(2;{log2_cell})")

    doc.calculateAll()
    # Force formula evaluation before store and verify key computed cells are finite.
    for row0 in range(10, 20):
        for col0 in range(2, 12):
            v = task.getCellByPosition(col0, row0).getValue()
            if not math.isfinite(v):
                raise RuntimeError("Non-finite expression lookup result")
    doc.store()
finally:
    if doc is not None:
        try:
            doc.close(True)
        except Exception:
            pass
    try:
        proc.terminate()
        proc.wait(timeout=5)
    except Exception:
        try: proc.kill()
        except Exception: pass
    shutil.rmtree(profile, ignore_errors=True)
PY
