#!/bin/bash
set -euo pipefail

INPUT_PDF="/root/invoices.pdf"
VENDORS_XLSX="/root/vendors.xlsx"
PO_CSV="/root/purchase_orders.csv"
OUTPUT_JSON="/root/fraud_report.json"

WORK_DIR="/root/invoice_fraud_work"
PAGE_DIR="/root/invoice_fraud_work/pages"
AUDIT_DB="/root/invoice_fraud_work/audit.sqlite3"

rm -rf "${WORK_DIR}"
mkdir -p "${PAGE_DIR}"

cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

if ! command -v pdftotext >/dev/null 2>&1 || \
   ! command -v pdfinfo >/dev/null 2>&1; then
    apt-get update
    DEBIAN_FRONTEND=noninteractive apt-get install -y --no-install-recommends \
        poppler-utils
    rm -rf /var/lib/apt/lists/*
fi

PAGE_COUNT="$(
    pdfinfo "${INPUT_PDF}" |
    awk -F ':' '
        /^Pages:/ {
            gsub(/[[:space:]]/, "", $2)
            print $2
            exit
        }
    '
)"

if ! [[ "${PAGE_COUNT}" =~ ^[0-9]+$ ]] || [ "${PAGE_COUNT}" -lt 1 ]; then
    echo "Unable to determine PDF page count" >&2
    exit 1
fi

for ((PAGE=1; PAGE<=PAGE_COUNT; PAGE++)); do
    PAGE_TEXT="$(printf "${PAGE_DIR}/page_%06d.txt" "${PAGE}")"

    pdftotext \
        -layout \
        -enc UTF-8 \
        -f "${PAGE}" \
        -l "${PAGE}" \
        "${INPUT_PDF}" \
        "${PAGE_TEXT}"
done

python3 <<'PYTHON'
import glob
import json
import os
import re
import sqlite3
import unicodedata
from decimal import Decimal, InvalidOperation

import pandas as pd
from rapidfuzz import fuzz, process
from rapidfuzz.distance import Levenshtein

VENDORS_XLSX = "/root/vendors.xlsx"
PO_CSV = "/root/purchase_orders.csv"
PAGE_DIR = "/root/invoice_fraud_work/pages"
AUDIT_DB = "/root/invoice_fraud_work/audit.sqlite3"
OUTPUT_JSON = "/root/fraud_report.json"


def canonical_column_name(value):
    return re.sub(r"[^a-z0-9]+", "", str(value).casefold())


def find_column(df, aliases):
    lookup = {
        canonical_column_name(column): column
        for column in df.columns
    }

    for alias in aliases:
        key = canonical_column_name(alias)
        if key in lookup:
            return lookup[key]

    raise KeyError(
        "Could not find any of columns "
        f"{aliases!r}; available columns: {list(df.columns)!r}"
    )


def normalize_identifier(value):
    if value is None:
        return None

    try:
        if pd.isna(value):
            return None
    except TypeError:
        pass

    if isinstance(value, float) and value.is_integer():
        return str(int(value)).casefold()

    text = str(value).strip()

    if not text:
        return None

    if re.fullmatch(r"[0-9]+\.0+", text):
        text = text.split(".", 1)[0]

    return text.casefold()


def normalize_po(value):
    if value is None:
        return None

    text = str(value).strip()
    if not text:
        return None

    return text.upper()


def normalize_iban(value):
    if value is None:
        return None

    text = str(value).strip().upper()

    if not text:
        return None

    return re.sub(r"[^A-Z0-9]", "", text)


LEGAL_SUFFIXES = {
    "ltd", "limited", "inc", "incorporated", "corp", "corporation",
    "llc", "plc", "gmbh", "ag", "sa", "sarl", "bv", "nv", "pte",
    "pty", "company", "co",
}


def normalize_vendor_name(value):
    if value is None:
        return ""

    text = unicodedata.normalize("NFKD", str(value))
    text = "".join(
        char for char in text
        if not unicodedata.combining(char)
    )

    text = text.casefold()
    text = text.replace("&", " and ")
    text = re.sub(r"[^a-z0-9]+", " ", text)
    tokens = text.split()

    original_tokens = list(tokens)

    while len(tokens) > 1 and tokens[-1] in LEGAL_SUFFIXES:
        tokens.pop()

    if not tokens:
        tokens = original_tokens

    return " ".join(tokens)


def parse_decimal(value):
    if value is None:
        return None

    try:
        if pd.isna(value):
            return None
    except TypeError:
        pass

    text = str(value).strip()

    if not text:
        return None

    text = text.replace(",", "")
    text = re.sub(r"^[^\d+\-.]*", "", text)
    text = re.sub(r"[^\d]+$", "", text)

    try:
        return Decimal(text)
    except InvalidOperation as exc:
        raise ValueError(f"Invalid monetary value: {value!r}") from exc


def first_group(text, patterns):
    for pattern in patterns:
        match = re.search(pattern, text, re.IGNORECASE | re.MULTILINE)
        if match:
            value = match.group(1).strip()
            if value:
                return value
    return None


def parse_invoice_text(text, page_number):
    text = text.replace("\x0c", "")

    vendor_name = first_group(
        text,
        [
            r"^\s*From\s*:\s*(.+?)\s*$",
            r"^\s*Vendor\s+Name\s*:\s*(.+?)\s*$",
        ],
    )

    amount_raw = first_group(
        text,
        [
            r"^\s*(?:Invoice\s+)?Total\s*:?\s*"
            r"(?:USD\s*)?\$?\s*"
            r"([0-9][0-9,]*(?:\.[0-9]+)?)\b",
            r"^\s*Amount\s+Due\s*:?\s*"
            r"(?:USD\s*)?\$?\s*"
            r"([0-9][0-9,]*(?:\.[0-9]+)?)\b",
        ],
    )

    po_number_raw = first_group(
        text,
        [
            r"^\s*PO\s+Number\s*:\s*"
            r"([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$",
            r"^\s*PO\s+No\.?\s*:\s*"
            r"([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$",
            r"^\s*Purchase\s+Order(?:\s+Number)?\s*:\s*"
            r"([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$",
        ],
    )

    iban = first_group(
        text,
        [
            r"^\s*(?:Payment\s+)?IBAN\s*:\s*"
            r"([A-Z0-9][A-Z0-9 _-]*)\s*$",
        ],
    )

    invoice_vendor_id_raw = first_group(
        text,
        [
            r"^\s*Vendor\s+ID\s*:\s*"
            r"([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$",
        ],
    )

    amount = parse_decimal(amount_raw)

    if vendor_name is None:
        raise ValueError(
            f"Could not extract vendor name from page {page_number}"
        )

    if amount is None:
        raise ValueError(
            f"Could not extract invoice amount from page {page_number}"
        )

    return {
        "page_number": page_number,
        "vendor_name": vendor_name,
        "vendor_name_norm": normalize_vendor_name(vendor_name),
        "invoice_vendor_id": normalize_identifier(invoice_vendor_id_raw),
        "amount_text": format(amount, "f"),
        "po_number": normalize_po(po_number_raw),
        "po_number_raw": po_number_raw,
        "iban": iban,
        "iban_norm": normalize_iban(iban),
    }


vendors_df = pd.read_excel(VENDORS_XLSX, dtype=object)
pos_df = pd.read_csv(PO_CSV, dtype=object, keep_default_na=False)

vendor_id_col = find_column(
    vendors_df,
    ["vendor_id", "vendor id", "id"],
)
vendor_name_col = find_column(
    vendors_df,
    ["name", "vendor_name", "vendor name", "vendor"],
)
vendor_iban_col = find_column(
    vendors_df,
    ["iban", "authorized_iban", "authorized iban"],
)

po_number_col = find_column(
    pos_df,
    ["po_number", "po number", "po_no", "po no", "po"],
)
po_amount_col = find_column(
    pos_df,
    ["amount", "po_amount", "po amount"],
)
po_vendor_id_col = find_column(
    pos_df,
    ["vendor_id", "vendor id", "vendorid"],
)

vendor_rows = []

for _, row in vendors_df.iterrows():
    vendor_name = str(row[vendor_name_col]).strip()
    vendor_id = normalize_identifier(row[vendor_id_col])
    iban = normalize_iban(row[vendor_iban_col])

    vendor_rows.append(
        {
            "vendor_key": len(vendor_rows) + 1,
            "vendor_id": vendor_id,
            "vendor_name": vendor_name,
            "vendor_name_norm": normalize_vendor_name(vendor_name),
            "authorized_iban": iban,
        }
    )

po_rows = []

for _, row in pos_df.iterrows():
    po_number = normalize_po(row[po_number_col])
    amount = parse_decimal(row[po_amount_col])
    vendor_id = normalize_identifier(row[po_vendor_id_col])

    if po_number is None:
        continue

    if amount is None:
        raise ValueError(
            f"PO {po_number!r} has no valid amount"
        )

    po_rows.append(
        {
            "po_number": po_number,
            "amount_text": format(amount, "f"),
            "vendor_id": vendor_id,
        }
    )

invoice_rows = []

page_paths = sorted(
    glob.glob(os.path.join(PAGE_DIR, "page_*.txt"))
)

for page_path in page_paths:
    filename = os.path.basename(page_path)
    match = re.fullmatch(r"page_(\d+)\.txt", filename)

    if not match:
        continue

    page_number = int(match.group(1))

    with open(page_path, "r", encoding="utf-8", errors="replace") as handle:
        text = handle.read()

    invoice_rows.append(
        parse_invoice_text(text, page_number)
    )

conn = sqlite3.connect(AUDIT_DB)
conn.execute("PRAGMA journal_mode = MEMORY")
conn.execute("PRAGMA synchronous = NORMAL")

conn.executescript(
    """
    CREATE TABLE vendors (
        vendor_key          INTEGER PRIMARY KEY,
        vendor_id           TEXT,
        vendor_name         TEXT NOT NULL,
        vendor_name_norm    TEXT NOT NULL,
        authorized_iban     TEXT
    );

    CREATE TABLE purchase_orders (
        po_number           TEXT PRIMARY KEY,
        amount_text         TEXT NOT NULL,
        vendor_id           TEXT
    );

    CREATE TABLE invoices (
        page_number         INTEGER PRIMARY KEY,
        vendor_name         TEXT,
        vendor_name_norm    TEXT NOT NULL,
        invoice_vendor_id   TEXT,
        amount_text         TEXT NOT NULL,
        po_number           TEXT,
        po_number_raw       TEXT,
        iban                TEXT,
        iban_norm           TEXT
    );

    CREATE TABLE vendor_candidates (
        invoice_page        INTEGER NOT NULL,
        vendor_key          INTEGER NOT NULL,
        candidate_rank      INTEGER NOT NULL,
        fuzzy_score         REAL NOT NULL,
        edit_distance       INTEGER NOT NULL,
        PRIMARY KEY (
            invoice_page,
            candidate_rank
        )
    );

    CREATE TABLE vendor_resolution (
        invoice_page        INTEGER PRIMARY KEY,
        vendor_key          INTEGER
    );
    """
)

conn.executemany(
    """
    INSERT INTO vendors (
        vendor_key,
        vendor_id,
        vendor_name,
        vendor_name_norm,
        authorized_iban
    )
    VALUES (?, ?, ?, ?, ?)
    """,
    [
        (
            row["vendor_key"],
            row["vendor_id"],
            row["vendor_name"],
            row["vendor_name_norm"],
            row["authorized_iban"],
        )
        for row in vendor_rows
    ],
)

conn.executemany(
    """
    INSERT INTO purchase_orders (
        po_number,
        amount_text,
        vendor_id
    )
    VALUES (?, ?, ?)
    """,
    [
        (
            row["po_number"],
            row["amount_text"],
            row["vendor_id"],
        )
        for row in po_rows
    ],
)

conn.executemany(
    """
    INSERT INTO invoices (
        page_number,
        vendor_name,
        vendor_name_norm,
        invoice_vendor_id,
        amount_text,
        po_number,
        po_number_raw,
        iban,
        iban_norm
    )
    VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
    """,
    [
        (
            row["page_number"],
            row["vendor_name"],
            row["vendor_name_norm"],
            row["invoice_vendor_id"],
            row["amount_text"],
            row["po_number"],
            row["po_number_raw"],
            row["iban"],
            row["iban_norm"],
        )
        for row in invoice_rows
    ],
)

conn.commit()

vendor_name_choices = [
    row["vendor_name_norm"]
    for row in vendor_rows
]


def company_similarity(left, right, **kwargs):
    return max(
        fuzz.ratio(left, right),
        fuzz.WRatio(left, right),
        fuzz.token_set_ratio(left, right),
    )


def accept_vendor_match(query, candidate, score):
    if not query or not candidate:
        return False

    if query == candidate:
        return True

    distance = Levenshtein.distance(query, candidate)
    longest = max(len(query), len(candidate))

    if longest < 12:
        allowed_edits = 1
    elif longest < 24:
        allowed_edits = 2
    else:
        allowed_edits = 3

    if score >= 85.0:
        return True

    if score >= 70.0 and distance <= allowed_edits:
        return True

    return False


for invoice in invoice_rows:
    page_number = invoice["page_number"]
    query = invoice["vendor_name_norm"]

    if not query or not vendor_name_choices:
        conn.execute(
            """
            INSERT INTO vendor_resolution (
                invoice_page,
                vendor_key
            )
            VALUES (?, NULL)
            """,
            (page_number,),
        )
        continue

    matches = process.extract(
        query,
        vendor_name_choices,
        scorer=company_similarity,
        limit=min(5, len(vendor_name_choices)),
    )

    ranked = []

    for rank, match in enumerate(matches, start=1):
        candidate_name, score, vendor_index = match
        vendor_key = vendor_rows[vendor_index]["vendor_key"]
        edit_distance = Levenshtein.distance(
            query,
            candidate_name,
        )

        ranked.append(
            (
                page_number,
                vendor_key,
                rank,
                float(score),
                int(edit_distance),
            )
        )

    conn.executemany(
        """
        INSERT INTO vendor_candidates (
            invoice_page,
            vendor_key,
            candidate_rank,
            fuzzy_score,
            edit_distance
        )
        VALUES (?, ?, ?, ?, ?)
        """,
        ranked,
    )

    best_name, best_score, best_vendor_index = matches[0]

    if accept_vendor_match(
        query,
        best_name,
        float(best_score),
    ):
        resolved_vendor_key = vendor_rows[
            best_vendor_index
        ]["vendor_key"]
    else:
        resolved_vendor_key = None

    conn.execute(
        """
        INSERT INTO vendor_resolution (
            invoice_page,
            vendor_key
        )
        VALUES (?, ?)
        """,
        (
            page_number,
            resolved_vendor_key,
        ),
    )

conn.commit()

audit_rows = conn.execute(
    """
    SELECT
        i.page_number,
        i.vendor_name,
        i.amount_text,
        i.iban,
        i.iban_norm,
        i.po_number,
        i.po_number_raw,
        i.invoice_vendor_id,

        r.vendor_key,

        v.vendor_id AS approved_vendor_id,
        v.authorized_iban,

        po.po_number AS matched_po_number,
        po.amount_text AS po_amount_text,
        po.vendor_id AS po_vendor_id

    FROM invoices AS i

    LEFT JOIN vendor_resolution AS r
        ON r.invoice_page = i.page_number

    LEFT JOIN vendors AS v
        ON v.vendor_key = r.vendor_key

    LEFT JOIN purchase_orders AS po
        ON po.po_number = i.po_number

    ORDER BY i.page_number
    """
).fetchall()

fraud_report = []

for row in audit_rows:
    (
        page_number,
        vendor_name,
        amount_text,
        iban,
        iban_norm,
        po_number,
        po_number_raw,
        invoice_vendor_id,
        resolved_vendor_key,
        approved_vendor_id,
        authorized_iban,
        matched_po_number,
        po_amount_text,
        po_vendor_id,
    ) = row

    invoice_amount = Decimal(amount_text)
    reason = None

    if resolved_vendor_key is None:
        reason = "Unknown Vendor"

    elif iban_norm != authorized_iban:
        reason = "IBAN Mismatch"

    elif po_number is None or matched_po_number is None:
        reason = "Invalid PO"

    else:
        po_amount = Decimal(po_amount_text)

        if abs(invoice_amount - po_amount) > Decimal("0.01"):
            reason = "Amount Mismatch"

        else:
            effective_invoice_vendor_id = (
                invoice_vendor_id
                if invoice_vendor_id is not None
                else approved_vendor_id
            )

            if po_vendor_id != effective_invoice_vendor_id:
                reason = "Vendor Mismatch"

    if reason is None:
        continue

    output_po_number = (
        po_number_raw
        if matched_po_number is not None
        else None
    )

    fraud_report.append(
        {
            "invoice_page_number": int(page_number),
            "vendor_name": vendor_name,
            "invoice_amount": float(invoice_amount),
            "iban": iban,
            "po_number": output_po_number,
            "reason": reason,
        }
    )

conn.close()

with open(
    OUTPUT_JSON,
    "w",
    encoding="utf-8",
) as handle:
    json.dump(
        fraud_report,
        handle,
        ensure_ascii=False,
        indent=2,
    )
    handle.write("\n")
PYTHON
