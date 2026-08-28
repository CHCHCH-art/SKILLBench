---
name: dispatch-loading-operating-margin-report
description: "Report solved DC dispatch generation, reserve, branch loading and operating margin using the reference ranking and rounding conventions."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Require finite numerical CVXPY variable values before reporting; if the solver has no usable solution, abort.
2. Convert generation back to MW. Recompute branch MW flow from solved angles with the same `1/x` branch equation used in constraints and compute loading ratio against positive ratings.
3. Sort branch records by loading descending and retain the reference top **3** most-loaded lines.
4. Operating margin is `sum(Pmax - Pg_MW - Rg_MW)`.
5. Bind report field names from `Instruction.md` and preserve the procedure's explicit numeric rounding at serialization. Do not perform a second economic-dispatch solve in the reporting step.

## Checks

Require finite solved generation, reserve and angle arrays with lengths matching generator/bus counts. Recomputed branch flows must use the same branch susceptances as the optimization; loading percentages for positive-rated lines must be finite and nonnegative. The most-loaded list must be sorted descending by loading and contain at most the reference top 3 entries. Report totals must equal sums of the underlying generation/load/reserve arrays before serialization rounding, and operating margin must equal `sum(Pmax - Pg_MW - Rg_MW)`. Dimension mismatch, nonfinite values, inconsistent totals/ranking, or an operating-margin mismatch aborts reporting.
