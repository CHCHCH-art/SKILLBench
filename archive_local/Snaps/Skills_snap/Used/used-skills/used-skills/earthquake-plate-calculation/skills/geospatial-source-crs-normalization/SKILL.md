---
name: geospatial-source-crs-normalization
description: "Prepare earthquake points and tectonic plate polygon/boundary sources for finding events inside a target plate and measuring distance to its boundary: load geospatial data, normalize CRS, select geometries, and produce projected point/line inputs."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Bind all source paths, requested target names, attribute fields, and output precision from the current task specification.
2. Treat geographic source coordinates as EPSG:4326 when the reference loader must supply that CRS, then project distance work to reference metric CRS **EPSG:4087**.
3. For point-to-polygon membership, use strict `within` semantics; boundary points are not promoted to inside points by an intersects/covers substitution.
4. The reference boundary-source selection additionally applies the literal name-filter token **`"PA"`** in the relevant boundary-name matching path. This literal token is a fixed workflow default rather than a task-bound value.
5. Preserve source feature order/index metadata so later tie breaks can use source ordinal deterministically.

## Checks

Assert all geometries used for metric distance share EPSG:4087 and all membership checks use the geographic/appropriate polygon geometry under the reference strict predicate.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

