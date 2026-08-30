---
name: pareto-grid-search-selection
description: "Evaluate a task-specified clustering hyperparameter grid, aggregate image-level F1/delta with NaN handling, filter by the task criterion, and compute a deterministic maximize-F1/minimize-delta Pareto frontier."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Enumerate the Cartesian product of all Task-provided `min_samples`, epsilon, and shape-weight values. Use the prebuilt per-image neighbor caches rather than recomputing distance matrices for each combination.
2. Average F1 over the complete Task image universe, including prescribed zero-F1 images. Average delta only over finite/matched deltas according to the Task rule.
3. Apply the Task-provided pre-Pareto F1 acceptance filter before frontier computation.
4. A row is dominated when another retained row is at least as good in F1 and at most as large in delta, with at least one strict improvement. Keep all nondominated rows.
5. Sort the frontier by F1 descending and delta ascending using the reference deterministic behavior, then apply Task-requested rounding/column order only for CSV serialization.

## Checks
Pareto comparisons use unrounded aggregates. Ensure every grid combination is evaluated exactly once.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

