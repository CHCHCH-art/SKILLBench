---
name: template-match-spatial-counting
description: "Count repeated objects in grayscale keyframes by normalized correlation template matching and spatial suppression, then serialize one row per frame with task-bound object/template/column names."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind the Task object categories, template paths, frame list, and CSV columns from the current task specification.
2. Read both frame and template and convert each to grayscale before matching, even though keyframes were already converted in place.
3. Run `cv2.matchTemplate(..., cv2.TM_CCOEFF_NORMED)`. The helper accepts a threshold argument but then **overwrites it with reference threshold `0.9`**; preserve this behavior.
4. Enumerate every correlation location with score `>=0.9` in NumPy `where` encounter order. Keep the first location; keep a later point only if its minimum Euclidean distance to all previously kept points is **strictly greater than 3 pixels**.
5. The count is the number of retained points. Repeat independently for each Task-specified template/category and append counts to the current frame row.

## Checks

For each frame/template pair, require a finite correlation map, count only points whose score meets the configured threshold, and verify every retained pair of points is separated by more than the configured suppression distance. Re-running on the same grayscale frame/template must produce the same retained-point sequence and count. Abort if a template is larger than the frame, matching returns non-finite scores, or the serialized frame/category counts are incomplete.
