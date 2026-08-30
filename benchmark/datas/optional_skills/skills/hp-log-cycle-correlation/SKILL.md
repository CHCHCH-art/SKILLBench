---
name: hp-log-cycle-correlation
description: "Deflate nominal macroeconomic series, log-transform them, apply Hodrick-Prescott filtering with a task-supplied lambda, and compute Pearson correlation between cyclical components."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. For each joined year compute real series as `nominal / CPI`; no additional CPI rebasing is used.
2. Take natural logarithms of both real series.
3. Bind the HP-filter lambda from `Instruction.md` and call `statsmodels.tsa.filters.hp_filter.hpfilter(log_series, lamb=lambda)`; retain the returned cycle component.
4. Compute correlation with `numpy.corrcoef(cycle_a, cycle_b)[0,1]`.
5. Bind output precision/location from `Instruction.md`. Abort on nonpositive real values, nonfinite cycles, or a nonfinite correlation; do not silently drop extra observations after the inner join.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
