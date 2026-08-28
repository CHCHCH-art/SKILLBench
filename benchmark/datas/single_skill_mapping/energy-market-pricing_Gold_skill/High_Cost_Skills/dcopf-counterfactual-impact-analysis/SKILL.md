---
name: dcopf-counterfactual-impact-analysis
description: "Apply a task-specified transmission-limit counterfactual to the reference DC-OPF, resolve the market, and compute cost reduction, LMP drops, and congestion relief with rounding and orientation conventions."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Read the target branch endpoints, percentage capacity change, requested top-count, output fields, and any binding criterion from the current task specification.
2. Copy the base branch table. Scan in source order for the **first** branch whose endpoints match the requested pair in either orientation; multiply its limit by `1 + delta_pct/100`, then stop. Error if no branch matches.
3. Solve the base case and modified case with the same DC-OPF procedure.
4. Reference reports round each total cost to 2 decimals **before** `cost_reduction = rounded_base_cost - rounded_counterfactual_cost`; preserve that sequencing.
5. Build bus-to-LMP maps from already rounded 2-decimal LMP report entries. Compute each delta as `counterfactual - base` and round delta to 2 decimals.
6. Sort buses by ascending delta and take the Task-requested number of largest drops. Preserve Python stable ordering for equal deltas.
7. Build orientation-insensitive sets of reported binding lines. Congestion is considered relieved only when the modified target branch was binding in the base result and is not binding in the counterfactual result.

## Checks

Keep the located branch ordinal and old/new limits. Do not compute impact from unrounded costs/LMPs if reproducing this reference report, because the procedure intentionally uses its rounded report objects.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

