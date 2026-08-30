---
name: parallel-dbscan-grid-pareto-frontier
description: "Grid-search task-specified DBSCAN/shape-weight parameters across expert-annotated images, filter by F1, and compute the maximize-F1/minimize-delta Pareto frontier."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Group citizen and expert annotations by the base-image key used by the reference input schema. Iterate **only images present in the expert table**; missing citizen points still contribute F1 0.
2. Bind parameter ranges from `Instruction.md`. The reference baseline enumerates the Cartesian product and evaluates with `joblib.Parallel(n_jobs=-1, verbose=10)`.
3. For each parameter tuple, mean F1 includes every image including zeros; mean delta ignores NaNs and becomes infinity if no finite delta exists. Keep only tuples whose mean F1 is **strictly greater** than the Task threshold and whose delta is finite.
4. Compute Pareto membership with `paretoset` over `(F1,delta)` with senses `(max,min)`. Sort frontier by F1 descending.
5. Bind output rounding from Instruction; the reference rounds shape weight to one decimal and requested metrics before CSV output. Abort if no valid candidate survives rather than inventing a point.

## Checks

Require the Cartesian product to enumerate every Task-specified parameter value exactly once. Each candidate must contribute one per-image F1 for every expert image; compute mean delta only from finite deltas and set it to infinity when none exist. Before Pareto filtering, require finite mean F1 and retain only candidates satisfying the strict F1 threshold and finite-delta rule. Every reported frontier point must be nondominated under maximize-F1/minimize-delta, and final rows must be sorted by descending F1. Empty valid candidate/frontier sets abort output.
