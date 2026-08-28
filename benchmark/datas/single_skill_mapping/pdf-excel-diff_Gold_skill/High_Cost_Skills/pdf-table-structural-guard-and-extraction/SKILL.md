---
name: pdf-table-structural-guard-and-extraction
description: "Extract authoritative old employee-style records from a PDF before comparing them with a current Excel database: validate table structure with an OCR guard, parse layout text with typed identifier/numeric fields, and reconstruct deterministic rows."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference structural guard
1. Bind the PDF path and Task-required table schema. The procedure expects nine logical fields; when applying this SKILL to another task, derive the field labels/types from the current task specification rather than reusing those names.
2. Render every page with `pdftoppm -r 300 -png -gray`, run Tesseract TSV with `--psm 6`, and group OCR words into lines.
3. Count every OCR line on every page containing the task-bound inline identifier pattern. On page 1 only, normalize each header token with `re.sub(r"[^a-zA-Z]", "", tok).lower()`, keep tokens that occur in the task-bound expected header set, and declare the header valid only when both the first/identifier semantic token and final/score semantic token are present and at least **7 distinct expected header tokens** were matched.
4. Abort OCR validation unless the first-page header condition is true **and** the total inline identifier-hit count is greater than zero. OCR is only a structural guard; its numeric values do not replace authoritative layout text.

## Authoritative layout extraction
5. Run `pdftotext -layout`. Skip blank lines and the header line; only consider lines beginning with the task-bound identifier prefix and require the first token to match the task-bound full identifier regex.
6. Split on whitespace and scan from the start for the first token matching the reference comma-grouped money pattern `^\\d{1,3}(?:,\\d{3})+$`. Accept the row only when `salary_idx >= 5` and `salary_idx + 2 < len(tokens)`.
7. Using the resolved positional fields, parse the money token after removing commas; parse the **immediately following** token as integer years; parse the **last** token as score (`float` when it contains `.`, otherwise `int`). A `ValueError` rejects the row.
8. Reconstruct fields positionally: token 0 identifier, 1 first text field, 2 second text field, 3 department-like field, tokens `4:salary_idx` joined by spaces as position/title, token `salary_idx` money, token `salary_idx+1` years, tokens `salary_idx+2:-1` joined as location-like text, and final token score. Map these positions to the task-bound schema.

## Checks

Abort if the OCR structural guard fails. During layout parsing, malformed candidate rows are rejected rather than repaired; after extraction, if the required table is empty or violates the Task schema, abort instead of backfilling values from OCR.

