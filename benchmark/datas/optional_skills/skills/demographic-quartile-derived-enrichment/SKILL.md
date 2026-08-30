---
name: demographic-quartile-derived-enrichment
description: "Enrich joined demographic rows with median-income quartile labels and a per-row derived total using the baseline quantile boundary convention."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind the metric used for quartiling, output quartile labels and derived-total operands from `Instruction.md`.
2. Compute pandas quantiles at **0.25, 0.50, 0.75** over the joined median-income metric.
3. Reference binning is inclusive at each upper boundary: NaN maps to the first quartile label; `value<=q25` first, `<=q50` second, `<=q75` third, else fourth.
4. Compute the Task's derived total row-by-row; in this workflow the formula is the product of the two source metrics specified by Instruction.
5. Preserve joined row order and do not replace pandas quantile interpolation with rank-based `qcut`.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
