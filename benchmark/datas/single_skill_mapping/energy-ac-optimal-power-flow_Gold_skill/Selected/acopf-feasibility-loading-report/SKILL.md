---
name: acopf-feasibility-loading-report
description: "Validate and report the solved ISO day-ahead AC optimal-power-flow voltage profile by recomputing AC branch flows, nodal mismatches, thermal loading, voltage violations, and ranked branch utilization."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Recompute every branch's forward/reverse P,Q using the same pi-model equations as optimization. Loading percent is `100*max(|Sft|,|Stf|)/rating`; overload is positive excess above rating.
2. Recompute bus active/reactive power mismatch from solved generation, demand, shunts and branch flows; report maximum absolute mismatches after converting per-unit back by `baseMVA`.
3. Compute maximum voltage-bound violation. Sort branches by loading descending and retain the reference top 10 entries.
4. Bind report field names from `Instruction.md`. Preserve reference numeric rounding: summary/objective and aggregate power quantities to 2 decimals, generator/bus values to 6 decimals, loading percentage to 2, branch MVA quantities to 3, and feasibility residuals to 6.
5. The report writes status `optimal` after a successful optimization path. If feasibility recomputation is nonfinite, abort before serialization.

## Checks

Require all recomputed branch flows, bus mismatches, voltage violations, objective/report quantities and loading percentages to be finite. The maximum active/reactive mismatch and voltage-bound violation must be computed from the same solved state and equations used by the optimization. Branch ranking must be nonincreasing by loading and contain no more than the reference top-count. If recomputation reveals inconsistent dimensions or nonfinite physics, abort serialization rather than emitting `optimal`.
