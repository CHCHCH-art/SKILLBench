---
name: raster-distance-candidate-pruning
description: "Accelerate nearest-boundary searches by rasterizing projected geometry and using an EDT-derived conservative upper bound to prune exact distance candidates, with the reference cell size, padding, and numerical safety margin."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. In the metric CRS, build a regular raster with reference cell size **5000 metres**. Refuse/guard configurations above the reference **100,000,000-cell** maximum.
2. Extend the raster domain by **2 cells** of padding around the relevant bounds. Rasterize source geometry with `all_touched=True`.
3. Compute a Euclidean distance transform on the inverse boundary raster. Sample the EDT at query points and convert cell distances to metric distance.
4. Form the conservative reference upper bound as `sampled_distance + sqrt(2)*cell_size + abs(sampled_distance)*2^-22 + 1`.
5. Establish an anchor exact distance using candidates ordered by descending sampled upper estimate and then source ordinal as the deterministic tie component.
6. Keep candidate features whose upper bound is at least `anchor_exact - 1e-7`; pass only these to the exact geometry-distance stage.

## Checks

Pruning must never discard a feature whose conservative upper bound can still beat the current anchor. Log raster dimensions and the number of retained exact candidates for auditability.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

