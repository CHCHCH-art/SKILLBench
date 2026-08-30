---
name: geospatial-plate-membership-filter
description: "Load earthquake points and plate polygons from GeoJSON, normalize them into a shared geographic CRS, and retain only events within a task-selected tectonic plate polygon."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind earthquake GeoJSON, plate polygon GeoJSON, target plate field/value, and output requirements from `Instruction.md`; do not embed a particular plate name or file path in the SKILL.
2. Convert earthquake feature coordinates into point geometry while preserving ID, place, epoch time, magnitude, latitude, longitude and depth attributes.
3. Read plate polygons with GeoPandas and ensure both layers are in EPSG:4326 before containment testing.
4. Select the requested plate polygon(s), take their unary union, and keep earthquake points for which `point.within(union)` is true. Boundary-touching points are excluded by this reference predicate.
5. Abort if the target plate cannot be selected or no candidate earthquake remains.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
