---
name: net-export-statistics-sumproduct-formulas
description: "Populate spreadsheet formulas for net exports as percent of GDP, descriptive statistics, and GDP-weighted mean using task-bound cell ranges and SUMPRODUCT."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind export/import/GDP cell blocks and output locations from `Instruction.md`.
2. Per country/year write `IFERROR((exports-imports)/GDP*100;0)`.
3. Per year compute minimum, maximum, median, average, 25th percentile and 75th percentile with Calc `MIN`, `MAX`, `MEDIAN`, `AVERAGE`, `PERCENTILE(range;0.25)`, `PERCENTILE(range;0.75)`.
4. Weighted mean must use `IFERROR(SUMPRODUCT(net_export_pct_range; GDP_range)/SUM(GDP_range);0)`; preserve the Task requirement to use SUMPRODUCT rather than replacing it with a precomputed numeric weighted average.
5. Keep all formulas inside existing Task cells and do not change workbook formatting.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
