---
name: pdf-record-table-extraction
description: "Extract keyed tabular records from a PDF backup by detecting a header row, accepting only task-valid record IDs, and normalizing designated numeric columns."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind PDF path, record-ID validation pattern and numeric columns from `Instruction.md`.
2. With `pdfplumber`, inspect every extracted table on every page. Clean cell text. A row whose first cleaned cell equals the Task ID header establishes/re-establishes column headers.
3. Subsequent rows are data only when the first cell matches the Task-provided ID format. Normalize row length to the header width.
4. For Task-designated numeric columns, strip currency markers/thousands separators as required by the source format and call numeric coercion; invalid values become NaN.
5. Concatenate records into a dataframe. Abort when no valid header/data records can be recovered; do not OCR or infer missing IDs.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
