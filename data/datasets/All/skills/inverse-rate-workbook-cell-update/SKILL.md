---
name: inverse-rate-workbook-cell-update
description: "Update a direct or inverse exchange-rate cell inside an embedded workbook while preserving formulas and the reference direct-first lookup rule."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Load the embedded workbook with formulas visible (`data_only=False`). Identify the table row labels from the first column and column labels from the first row.
2. Resolve the direct cell `<from_currency>` row × `<to_currency>` column. If that cell exists and is **not** a formula string beginning with `=`, write the requested new rate there.
3. Otherwise resolve the inverse cell `<to_currency>` row × `<from_currency>` column. If it exists and is nonformula, write `1/new_rate` there.
4. If neither direction resolves to a writable nonformula cell, abort; do not overwrite a formula.
5. Save in place, run the reference recalculation helper, then reopen/read the resulting table to ensure workbook structure remains parseable.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
