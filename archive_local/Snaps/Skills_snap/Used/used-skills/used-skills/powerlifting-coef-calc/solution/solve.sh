#!/bin/bash
set -euo pipefail

WORK_DIR=/tmp/powerlifting_coef_calc_heavy
INPUT_FILE=/root/data/openipf.xlsx
OUTPUT_FILE=/root/data/openipf_filled.xlsx

mkdir -p "$WORK_DIR"

cat > "$WORK_DIR/solve_powerlifting_heavy.py" << 'PYTHON_SCRIPT'
import csv
import shutil
import sqlite3
import subprocess
import xml.etree.ElementTree as ET
from pathlib import Path

import openpyxl

INPUT_FILE = Path("/root/data/openipf.xlsx")
OUTPUT_FILE = Path("/root/data/openipf_filled.xlsx")
FODS_FILE = Path("/tmp/powerlifting_coef_calc_heavy/openipf.fods")
CSV_FILE = Path("/tmp/powerlifting_coef_calc_heavy/dots_source.csv")
ROUNDTRIP_DIR = Path("/tmp/powerlifting_coef_calc_heavy/roundtrip")

REQUIRED_COLUMNS = [
    "Name",
    "Sex",
    "BodyweightKg",
    "Best3SquatKg",
    "Best3BenchKg",
    "Best3DeadliftKg",
]
DOTS_HEADERS = REQUIRED_COLUMNS + ["TotalKg", "Dots"]

MALE = (-0.0000010930, 0.0007391293, -0.1918759221, 24.0900756, -307.75076)
FEMALE = (-0.0000010706, 0.0005158568, -0.1126655495, 13.6175032, -57.96288)

NS = {
    "office": "urn:oasis:names:tc:opendocument:xmlns:office:1.0",
    "table": "urn:oasis:names:tc:opendocument:xmlns:table:1.0",
    "text": "urn:oasis:names:tc:opendocument:xmlns:text:1.0",
}


def run(cmd):
    subprocess.run(cmd, check=True)


def excel_dots_formula(sex_cell: str, bw_cell: str, total_cell: str) -> str:
    m_a, m_b, m_c, m_d, m_e = MALE
    f_a, f_b, f_c, f_d, f_e = FEMALE

    male_bw = f"MAX(40,MIN(210,{bw_cell}))"
    female_bw = f"MAX(40,MIN(150,{bw_cell}))"

    male_poly = (
        f"({m_a}*POWER({male_bw},4)"
        f"+{m_b}*POWER({male_bw},3)"
        f"+{m_c}*POWER({male_bw},2)"
        f"+{m_d}*{male_bw}"
        f"+{m_e})"
    )
    female_poly = (
        f"({f_a}*POWER({female_bw},4)"
        f"+{f_b}*POWER({female_bw},3)"
        f"+{f_c}*POWER({female_bw},2)"
        f"+{f_d}*{female_bw}"
        f"+{f_e})"
    )

    return f'=ROUND(IF({sex_cell}="M",{total_cell}*(500/{male_poly}),{total_cell}*(500/{female_poly})),3)'


def convert_xlsx_to_fods(xlsx_path: Path, fods_path: Path):
    fods_path.parent.mkdir(parents=True, exist_ok=True)
    run([
        "libreoffice",
        "--headless",
        "--convert-to",
        "fods",
        "--outdir",
        str(fods_path.parent),
        str(xlsx_path),
    ])
    produced = fods_path.parent / f"{xlsx_path.stem}.fods"
    if not produced.exists():
        raise RuntimeError("LibreOffice did not produce FODS file")
    if produced != fods_path:
        shutil.move(str(produced), str(fods_path))


def extract_cell_value(cell):
    value_type = cell.get(f"{{{NS['office']}}}value-type")

    if value_type in {"float", "percentage", "currency"}:
        return cell.get(f"{{{NS['office']}}}value", "")
    if value_type == "boolean":
        return cell.get(f"{{{NS['office']}}}boolean-value", "")
    if value_type == "date":
        return cell.get(f"{{{NS['office']}}}date-value", "")

    paras = cell.findall("text:p", NS)
    if paras:
        return "\n".join("".join(p.itertext()) for p in paras)

    return ""


def extract_table_rows_from_fods(fods_path: Path, table_name: str):
    tree = ET.parse(fods_path)
    root = tree.getroot()

    table_elem = None
    for table in root.findall(".//table:table", NS):
        if table.get(f"{{{NS['table']}}}name") == table_name:
            table_elem = table
            break

    if table_elem is None:
        raise RuntimeError(f"sheet '{table_name}' not found in FODS")

    rows = []
    for row_elem in table_elem.findall("table:table-row", NS):
        row_repeat = int(row_elem.get(f"{{{NS['table']}}}number-rows-repeated", "1"))
        expanded_row = []

        for cell in list(row_elem):
            local_name = cell.tag.rsplit("}", 1)[-1]
            col_repeat = int(cell.get(f"{{{NS['table']}}}number-columns-repeated", "1"))

            if local_name == "covered-table-cell":
                value = ""
            elif local_name == "table-cell":
                value = extract_cell_value(cell)
            else:
                continue

            for _ in range(col_repeat):
                expanded_row.append(value)

        while expanded_row and expanded_row[-1] == "":
            expanded_row.pop()

        for _ in range(row_repeat):
            rows.append(list(expanded_row))

    return rows


def stage_rows_in_sqlite(rows):
    if not rows:
        raise RuntimeError("no rows extracted from Data sheet")

    header = rows[0]
    data_rows = rows[1:]

    header_map = {name: idx for idx, name in enumerate(header)}
    missing = [col for col in REQUIRED_COLUMNS if col not in header_map]
    if missing:
        raise RuntimeError(f"missing required columns in FODS-parsed header: {missing}")

    conn = sqlite3.connect(":memory:")
    conn.execute(
        """
        CREATE TABLE data_rows (
            source_row INTEGER PRIMARY KEY,
            Name TEXT,
            Sex TEXT,
            BodyweightKg TEXT,
            Best3SquatKg TEXT,
            Best3BenchKg TEXT,
            Best3DeadliftKg TEXT
        )
        """
    )

    for idx, row in enumerate(data_rows, start=2):
        padded = row + [""] * max(0, len(header) - len(row))
        values = [padded[header_map[col]] if header_map[col] < len(padded) else "" for col in REQUIRED_COLUMNS]
        conn.execute(
            """
            INSERT INTO data_rows (
                source_row, Name, Sex, BodyweightKg,
                Best3SquatKg, Best3BenchKg, Best3DeadliftKg
            ) VALUES (?, ?, ?, ?, ?, ?, ?)
            """,
            (idx, *values),
        )

    conn.commit()
    return conn


def export_sql_projection_to_csv(conn, csv_path: Path):
    csv_path.parent.mkdir(parents=True, exist_ok=True)

    cursor = conn.execute(
        """
        SELECT Name, Sex, BodyweightKg, Best3SquatKg, Best3BenchKg, Best3DeadliftKg
        FROM data_rows
        ORDER BY source_row
        """
    )
    rows = cursor.fetchall()

    with csv_path.open("w", newline="", encoding="utf-8") as f:
        writer = csv.writer(f)
        writer.writerow(REQUIRED_COLUMNS)
        writer.writerows(rows)


def refill_dots_sheet_from_csv(src_wb: Path, csv_path: Path, out_wb: Path):
    shutil.copy2(src_wb, out_wb)

    wb = openpyxl.load_workbook(out_wb)
    if "Dots" not in wb.sheetnames:
        wb.create_sheet("Dots")
    ws = wb["Dots"]

    for row in ws.iter_rows():
        for cell in row:
            cell.value = None

    with csv_path.open("r", newline="", encoding="utf-8") as f:
        reader = list(csv.reader(f))

    headers = reader[0]
    data_rows = reader[1:]

    for col_idx, header in enumerate(DOTS_HEADERS, start=1):
        ws.cell(row=1, column=col_idx, value=header)

    numeric_fields = {"BodyweightKg", "Best3SquatKg", "Best3BenchKg", "Best3DeadliftKg"}

    for row_idx, row_values in enumerate(data_rows, start=2):
        for col_idx, raw in enumerate(row_values, start=1):
            header = headers[col_idx - 1]
            if raw == "":
                value = None
            elif header in numeric_fields:
                value = float(raw)
            else:
                value = raw
            ws.cell(row=row_idx, column=col_idx, value=value)

        ws.cell(row=row_idx, column=7, value=f"=D{row_idx}+E{row_idx}+F{row_idx}")
        ws.cell(row=row_idx, column=8, value=excel_dots_formula(f"B{row_idx}", f"C{row_idx}", f"G{row_idx}"))

    wb.save(out_wb)
    wb.close()


def libreoffice_roundtrip_validation(xlsx_path: Path):
    ROUNDTRIP_DIR.mkdir(parents=True, exist_ok=True)

    run([
        "libreoffice",
        "--headless",
        "--convert-to",
        "ods",
        "--outdir",
        str(ROUNDTRIP_DIR),
        str(xlsx_path),
    ])

    ods_file = ROUNDTRIP_DIR / f"{xlsx_path.stem}.ods"
    if not ods_file.exists():
        raise RuntimeError("ODS roundtrip artifact missing")

    run([
        "libreoffice",
        "--headless",
        "--convert-to",
        "xlsx",
        "--outdir",
        str(ROUNDTRIP_DIR),
        str(ods_file),
    ])

    reconverted = ROUNDTRIP_DIR / f"{xlsx_path.stem}.xlsx"
    if not reconverted.exists():
        raise RuntimeError("reconverted XLSX artifact missing")


def main():
    convert_xlsx_to_fods(INPUT_FILE, FODS_FILE)
    rows = extract_table_rows_from_fods(FODS_FILE, "Data")
    conn = stage_rows_in_sqlite(rows)
    export_sql_projection_to_csv(conn, CSV_FILE)
    refill_dots_sheet_from_csv(INPUT_FILE, CSV_FILE, OUTPUT_FILE)
    libreoffice_roundtrip_validation(OUTPUT_FILE)
    shutil.move(str(OUTPUT_FILE), str(INPUT_FILE))


if __name__ == "__main__":
    main()
PYTHON_SCRIPT

python3 "$WORK_DIR/solve_powerlifting_heavy.py"