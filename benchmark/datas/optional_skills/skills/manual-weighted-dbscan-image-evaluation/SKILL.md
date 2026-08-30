---
name: manual-weighted-dbscan-image-evaluation
description: "Evaluate citizen-science point clusters per image with a task-defined anisotropic distance using cached neighbor matrices, manual DBSCAN state machine, centroid calculation, and greedy expert matching."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Task bindings
Read image identifier field, point coordinates, full hyperparameter grids, custom distance formula/weight interpretation, expert matching cutoff, averaging rules, and metric definition from the current task specification.

## Procedure
1. Iterate the image universe defined by the Task's expert dataset, retaining images that lack citizen points so their metrics follow the Task rule.
2. For every Task shape-weight and epsilon value, cache pairwise weighted-distance neighbor masks/lists once per image. DBSCAN itself is manual: unvisited label `-99`, noise `-1`; expand clusters through core points according to Task `min_samples` with the stated queue/label behavior.
3. Compute each non-noise cluster centroid as the ordinary arithmetic mean of its original `(x,y)` coordinates.
4. Compute a full **standard Euclidean** centroid-to-expert distance matrix. Greedy matching repeatedly selects the smallest remaining pair and accepts it only under the procedure's **strict `< Task_max_distance`** comparison, removing the chosen centroid and expert point.
5. Derive per-image F1 and matched-distance delta using the Task formulas. Images with no usable matches retain the Task-defined NaN delta behavior while still contributing their Task-defined F1 value.

## Checks
Custom weighted distance is used only by DBSCAN neighborhoods; expert matching/delta uses ordinary Euclidean distance exactly as specified by the current Task.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

