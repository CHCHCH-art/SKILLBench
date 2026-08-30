---
name: powerlifting-workbook-formula-population
description: "Recreate a powerlifting workbook’s data sheet and populate a derived coefficient sheet with linked source fields, lift total formulas, and Dots formulas for every input row."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind input/output workbook paths, source sheet, destination sheet, required source field mapping and output headers from `Instruction.md`/current input schema. Source column positions are dataset-specific; bind them from the current input schema instead of treating them as SKILL constants.
2. Read source rows with Polars. Create a new workbook, recreate the source sheet values, then create the derived sheet.
3. For each data row, write formulas linking name/sex/bodyweight/three lift fields from the source sheet. Compute total as the sum of the three lift cells.
4. Write the Dots formula from the coefficient SKILL using current row cell references.
5. Preserve the reference behavior of creating a fresh workbook rather than editing the original OOXML package in place. Verify every derived row contains formulas before saving.

## Checks

Require one derived output row per source data row, formulas in every Task-required calculated cell, and row-relative references that point to the same source record. Reopen the saved workbook with formulas visible and confirm formula cells still begin with `=`. Missing rows, shifted source references, overwritten input values, or formula loss aborts the workbook step rather than being repaired with hard-coded numbers.
