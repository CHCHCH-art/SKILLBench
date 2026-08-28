---
name: invoice-pdf-field-normalization
description: "Extract one invoice record per PDF page with Poppler, preserve raw vendor/amount/PO/IBAN/vendor-ID values for reporting, and create separate normalized comparison keys for entity resolution and fraud checks. Use ordered field regexes, Decimal parsing, column-alias resolution, and strict page-level staging so raw output values are never accidentally replaced by normalized identifiers."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check`. If it fails, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Data model: raw values and comparison keys are different fields

Maintain both representations explicitly:

```text
vendor_name_raw     -> emitted to report when required
vendor_name_norm    -> fuzzy vendor matching only
amount_raw/text     -> parsed to Decimal for comparison
po_number_raw       -> preserved spelling/punctuation for possible output
po_number_norm      -> PO table join only
iban_raw            -> emitted to report; preserve interior punctuation such as '_' or '-'
iban_norm           -> vendor-IBAN comparison only
vendor_id_raw       -> optional source value
vendor_id_norm      -> vendor/PO comparison only
```

Never overwrite a `*_raw` field with its normalized form. In particular, removing punctuation from an IBAN is valid for comparison but not for the report field.

## PDF extraction procedure

1. Determine page count with `pdfinfo`. Extract each page separately with:

   ```text
   pdftotext -layout -enc UTF-8 -f <page> -l <page> <pdf> <page_text>
   ```

   Keep one text file/record per 1-based page and remove form-feed `\x0c` before regex matching.
2. Implement `first_group(text, patterns)` exactly as ordered first-success matching with `re.IGNORECASE | re.MULTILINE`; return capture group 1 after outer `.strip()` only.
3. Apply these parser families in order:

   - vendor name: `^\s*From\s*:\s*(.+?)\s*$`, then `^\s*Vendor\s+Name\s*:\s*(.+?)\s*$`;
   - amount: `^\s*(?:Invoice\s+)?Total\s*:?\s*(?:USD\s*)?\$?\s*([0-9][0-9,]*(?:\.[0-9]+)?)\b`, then `^\s*Amount\s+Due\s*:?\s*(?:USD\s*)?\$?\s*([0-9][0-9,]*(?:\.[0-9]+)?)\b`;
   - PO: `^\s*PO\s+Number\s*:\s*([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$`, then `^\s*PO\s+No\.?\s*:\s*([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$`, then `^\s*Purchase\s+Order(?:\s+Number)?\s*:\s*([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$`;
   - IBAN: `^\s*(?:Payment\s+)?IBAN\s*:\s*([A-Z0-9][A-Z0-9 _-]*)\s*$`;
   - vendor ID: `^\s*Vendor\s+ID\s*:\s*([A-Za-z0-9][A-Za-z0-9._/-]*)\s*$`.
4. Vendor name and amount are mandatory. PO, IBAN, and invoice vendor ID may be null. Do not infer missing values from another page.
5. Parse money with `Decimal`: strip surrounding whitespace, remove commas, remove only leading non `[digit,+,-,.]` characters and trailing nondigits, then construct `Decimal`. Invalid monetary text is an error.
6. Normalize identifiers for comparison only:
   - generic identifier: null/NaN -> null; integral float -> integer text; textual `[0-9]+\.0+` loses the decimal suffix; strip and casefold;
   - PO key: strip and uppercase;
   - IBAN key: strip, uppercase, then remove every character outside `[A-Z0-9]`;
   - vendor name: NFKD, remove combining marks, casefold, replace `&` with `and`, replace nonalphanumerics with spaces, and repeatedly remove terminal legal suffix tokens while at least one meaningful token remains.
7. Resolve vendor/PO table columns by canonicalized aliases rather than numeric column positions. Read tabular identifiers as objects/text so leading zeros or punctuation are not silently coerced.
8. Stage exactly one invoice row per PDF page with both raw and normalized fields before fuzzy matching or fraud classification.

A parser helper is provided at `scripts/parse_invoice_page.py`. It applies the field regex and normalization split above to one extracted page text file; it does not perform fraud classification.

## Checks

- page count equals staged invoice-record count and page numbers are unique/contiguous;
- mandatory vendor and amount exist on every page;
- if a recognized PO/IBAN/vendor-ID label is visibly present in extracted page text but the corresponding parser returns null, treat this as a parsing failure to investigate rather than silently converting it into a fraud condition;
- `iban_raw` is preserved exactly after outer trimming, while `iban_norm` contains only uppercase alphanumerics;
- `po_number_raw` preserves punctuation, while `po_number_norm` is only the join key;
- no output/report stage is allowed to consume normalized identifiers when a raw field is required.

Abort on page loss, mandatory-field failure, ambiguous table columns, or raw/normalized field substitution.
