---
name: uno-formula-recalc-validation
description: "Recalculate a formula-populated Excel or statistical workbook through LibreOffice UNO, verify intended formula cells retain formulas and finite cached numeric values, and store the workbook without changing sheet structure."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. After formula population call UNO `doc.calculateAll()`.
2. Bind all intended formula ranges from `Instruction.md`. For each required cell, require formula text starts with `=` and UNO numeric value is finite.
3. Call `doc.store()` only after validation. Close the document, terminate the private LibreOffice process, and remove its profile in `finally` cleanup.
4. If connection, calculation or validation fails, abort and do not store a partially populated workbook.

## Checks

Before storing, require every Task-bound formula cell to still contain formula text beginning with `=` and its UNO-evaluated numeric value to be finite. Record the workbook sheet set/order before recalculation and require it to remain unchanged. `calculateAll()` and `store()` must complete without UNO exceptions; after store, reopen or re-read the intended cells when the procedure environment permits and require formulas to remain formulas rather than being replaced by constants. Connection failure, missing formula cells, nonfinite cached results, sheet-structure mutation, or store failure aborts and triggers cleanup without accepting the workbook.
