#!/bin/bash
set -euo pipefail

apt-get update
apt-get install -y --no-install-recommends tesseract-ocr tesseract-ocr-eng

cat > /tmp/solve_diff_ocr_layout.py << 'PYTHON_SCRIPT'
#!/usr/bin/env python3

import json
import re
import subprocess
from pathlib import Path

import pandas as pd

PDF_FILE = Path("/root/employees_backup.pdf")
EXCEL_FILE = Path("/root/employees_current.xlsx")
IMAGE_DIR = Path("/tmp/pdf_pages_ocr")
LAYOUT_FILE = Path("/tmp/employees_backup_layout.txt")
OUTPUT_FILE = Path("/root/diff_report.json")
TEMP_OUTPUT_FILE = Path("/root/diff_report.json.tmp")

EXPECTED_COLUMNS = ["ID", "First", "Last", "Dept", "Position", "Salary", "Years", "Location", "Score"]
HEADER_WORDS = [c.lower() for c in EXPECTED_COLUMNS]
ID_RE = re.compile(r"^EMP\d{5}$")
ID_INLINE_RE = re.compile(r"EMP\d{5}", re.I)
MONEY_RE = re.compile(r"^\d{1,3}(?:,\d{3})+$")


def to_builtin(value):
    if isinstance(value, dict):
        return {k: to_builtin(v) for k, v in value.items()}
    if isinstance(value, list):
        return [to_builtin(v) for v in value]
    if isinstance(value, tuple):
        return [to_builtin(v) for v in value]
    if hasattr(value, "item") and callable(getattr(value, "item", None)):
        try:
            return value.item()
        except Exception:
            pass
    return value


def convert_scalar(value):
    if pd.isna(value):
        return None
    if hasattr(value, "item") and callable(getattr(value, "item", None)):
        try:
            return value.item()
        except Exception:
            pass
    if isinstance(value, float) and value.is_integer():
        return int(value)
    return value


def render_pdf_to_images(pdf_path: Path, out_dir: Path) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    prefix = out_dir / "page"
    subprocess.run(
        ["pdftoppm", "-r", "300", "-png", "-gray", str(pdf_path), str(prefix)],
        check=True,
    )
    return sorted(out_dir.glob("page-*.png"))


def run_tesseract_tsv(image_path: Path) -> list[dict]:
    result = subprocess.run(
        ["tesseract", str(image_path), "stdout", "-l", "eng", "--psm", "6", "tsv"],
        capture_output=True,
        text=True,
        check=True,
    )
    rows = []
    lines = result.stdout.splitlines()
    if not lines:
        return rows

    header = lines[0].split("\t")
    for line in lines[1:]:
        parts = line.split("\t")
        if len(parts) != len(header):
            continue
        row = dict(zip(header, parts))
        text = (row.get("text") or "").strip()
        if not text:
            continue
        try:
            conf = float(row.get("conf", "-1"))
        except ValueError:
            conf = -1.0
        if conf < 0:
            continue

        rows.append(
            {
                "block_num": int(row["block_num"]),
                "par_num": int(row["par_num"]),
                "line_num": int(row["line_num"]),
                "left": int(row["left"]),
                "top": int(row["top"]),
                "width": int(row["width"]),
                "height": int(row["height"]),
                "text": text,
                "conf": conf,
            }
        )
    return rows


def group_words_into_lines(words: list[dict]) -> list[dict]:
    grouped = {}
    for word in words:
        key = (word["block_num"], word["par_num"], word["line_num"])
        grouped.setdefault(key, []).append(word)

    lines = []
    for key, items in grouped.items():
        items = sorted(items, key=lambda w: w["left"])
        text = " ".join(item["text"] for item in items)
        lines.append(
            {
                "key": key,
                "text": text,
                "left": min(item["left"] for item in items),
                "top": min(item["top"] for item in items),
                "right": max(item["left"] + item["width"] for item in items),
                "bottom": max(item["top"] + item["height"] for item in items),
            }
        )
    lines.sort(key=lambda x: (x["top"], x["left"]))
    return lines


def normalize_token(tok: str) -> str:
    return re.sub(r"[^a-zA-Z]", "", tok).lower()


def ocr_validate(images: list[Path]) -> None:
    total_emp_hits = 0
    header_found = False

    for page_index, image_path in enumerate(images, start=1):
        words = run_tesseract_tsv(image_path)
        lines = group_words_into_lines(words)

        for line in lines:
            if ID_INLINE_RE.search(line["text"]):
                total_emp_hits += 1

        if page_index == 1:
            for line in lines:
                norm_tokens = [normalize_token(tok) for tok in line["text"].split()]
                matched = [tok for tok in norm_tokens if tok in HEADER_WORDS]
                if "id" in matched and "score" in matched and len(set(matched)) >= 7:
                    header_found = True
                    break

    if not header_found or total_emp_hits == 0:
        raise RuntimeError("OCR validation failed")


def convert_pdf_to_layout_text(pdf_path: Path, out_path: Path) -> None:
    subprocess.run(
        ["pdftotext", "-layout", str(pdf_path), str(out_path)],
        check=True,
    )


def parse_layout_text(text_path: Path) -> pd.DataFrame:
    rows = []

    with text_path.open("r", encoding="utf-8", errors="ignore") as f:
        for raw_line in f:
            stripped = raw_line.rstrip("\n").strip()

            if not stripped:
                continue
            if stripped.startswith("ID "):
                continue
            if not stripped.startswith("EMP"):
                continue

            tokens = stripped.split()

            if not tokens or not ID_RE.match(tokens[0]):
                continue

            salary_idx = None
            for i, tok in enumerate(tokens):
                if MONEY_RE.match(tok):
                    salary_idx = i
                    break

            if salary_idx is None or salary_idx < 5 or salary_idx + 2 >= len(tokens):
                continue

            try:
                salary = int(tokens[salary_idx].replace(",", ""))
                years = int(tokens[salary_idx + 1])
                score_token = tokens[-1]
                score = float(score_token) if "." in score_token else int(score_token)
            except ValueError:
                continue

            row = {
                "ID": tokens[0],
                "First": tokens[1],
                "Last": tokens[2],
                "Dept": tokens[3],
                "Position": " ".join(tokens[4:salary_idx]),
                "Salary": salary,
                "Years": years,
                "Location": " ".join(tokens[salary_idx + 2:-1]),
                "Score": score,
            }
            rows.append(row)

    return pd.DataFrame(rows, columns=EXPECTED_COLUMNS)


def read_excel(excel_path: Path) -> pd.DataFrame:
    return pd.read_excel(excel_path)


def compare_data(df_old: pd.DataFrame, df_new: pd.DataFrame) -> dict:
    old_ids = set(df_old["ID"].tolist())
    new_ids = set(df_new["ID"].tolist())

    deleted_ids = sorted(old_ids - new_ids)
    common_ids = sorted(old_ids & new_ids)

    old_indexed = df_old.set_index("ID")
    new_indexed = df_new.set_index("ID")

    modifications = []

    for emp_id in common_ids:
        old_row = old_indexed.loc[emp_id]
        new_row = new_indexed.loc[emp_id]

        for col in EXPECTED_COLUMNS:
            if col == "ID":
                continue

            old_val = convert_scalar(old_row[col])
            new_val = convert_scalar(new_row[col])

            if old_val != new_val:
                modifications.append(
                    {
                        "id": emp_id,
                        "field": col,
                        "old_value": old_val,
                        "new_value": new_val,
                    }
                )

    modifications = sorted(modifications, key=lambda x: (x["id"], x["field"]))

    result = to_builtin(
        {
            "deleted_employees": deleted_ids,
            "modified_employees": modifications,
        }
    )

    with TEMP_OUTPUT_FILE.open("w", encoding="utf-8") as f:
        json.dump(result, f, indent=2, ensure_ascii=False)
    TEMP_OUTPUT_FILE.replace(OUTPUT_FILE)


def main():
    images = render_pdf_to_images(PDF_FILE, IMAGE_DIR)
    ocr_validate(images)
    convert_pdf_to_layout_text(PDF_FILE, LAYOUT_FILE)
    df_old = parse_layout_text(LAYOUT_FILE)
    df_new = read_excel(EXCEL_FILE)
    compare_data(df_old, df_new)


if __name__ == "__main__":
    main()
PYTHON_SCRIPT

python3 /tmp/solve_diff_ocr_layout.py