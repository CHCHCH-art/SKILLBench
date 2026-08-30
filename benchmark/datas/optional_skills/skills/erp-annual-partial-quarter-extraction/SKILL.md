---
name: erp-annual-partial-quarter-extraction
description: "Extract annual macroeconomic series from irregular Economic Report workbook tables, including a final year represented only by available quarterly rows, then join to CPI by year."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind workbook paths, target series columns and requested year range from `Instruction.md`.
2. Read each ERP workbook with `header=None`. Annual rows are detected from first-column labels that end in `.` and whose prefix is numeric; the reference path parses the fully annual range through the penultimate year.
3. For the final requested year, locate the section line containing that year and a colon, then scan following quarter rows whose labels begin with Roman-quarter markers; stop when that local quarterly block ends. Average all numeric available quarters to create the annual value.
4. Read CPI from its ordinary tabular sheet, keep its year/value columns, coerce numeric values, and filter to the requested year interval.
5. Inner-join nominal series and CPI by year. The reference warns on an unexpected row count but continues; it does not impute missing years.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
