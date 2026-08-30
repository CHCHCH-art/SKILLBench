---
name: demographic-quantile-derived-enrichment
description: "Enrich an already joined demographic-style relation with linear-interpolated quartile boundaries, deterministic quartile assignment, and a task-defined multiplicative derived metric while preserving source order and unrounded numeric values for pivot-table generation."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference enrichment procedure
1. Consume the source-ordered joined relation and bind the Task income-like field, quartile labels, multiplicative derived fields, and final column order from the current task specification.
2. Sort all non-null income values numerically. For probability `p`, compute linear percentile with rank `(n-1)*p`; let `lo=floor(rank)`, `hi=ceil(rank)`. If equal, use that ordered value; otherwise linearly interpolate by the fractional rank. Compute `q1,q2,q3` at `0.25,0.50,0.75`.
3. Quartile assignment uses this exact rule: a null income value receives the first Task quartile label; otherwise assign first label for `value<=q1`, second for `<=q2`, third for `<=q3`, else fourth.
4. Compute the Task-derived total as the product of the two specified joined numeric fields; if either operand is null, the derived value is null.
5. Preserve the existing source order and export columns in the Task-required order for workbook/pivot construction.

## Checks

Abort if no non-null values exist for percentile computation. Keep unrounded values for boundary calculation/classification and derived totals; if any required enrichment field is absent, abort rather than computing from a substitute column.

