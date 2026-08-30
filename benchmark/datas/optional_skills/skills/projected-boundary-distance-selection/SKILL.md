---
name: projected-boundary-distance-selection
description: "Project candidate earthquake points and tectonic boundaries to a metric CRS, compute nearest-boundary distances, and select the farthest in-plate event with deterministic formatting."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. The reference metric CRS is **EPSG:4087**. Reproject both candidate points and the selected boundary geometry to it before distance computation.
2. Bind the boundary selector from the current task/input schema rather than hard-coding a dataset-specific plate code. Union the selected boundary geometries.
3. For every in-plate earthquake compute planar distance to the boundary union and divide meters by 1000.
4. Select the row with the largest distance using the reference dataframe `nlargest(1, distance_column)` behavior.
5. Convert epoch milliseconds to UTC and format with `%Y-%m-%dT%H:%M:%SZ`. Bind output field names and requested rounding from `Instruction.md`; the reference applies the Task-requested distance rounding at serialization.
6. Abort when no matching boundary geometry exists or distances are nonfinite.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
