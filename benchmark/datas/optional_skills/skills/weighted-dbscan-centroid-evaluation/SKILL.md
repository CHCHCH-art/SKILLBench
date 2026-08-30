---
name: weighted-dbscan-centroid-evaluation
description: "Evaluate one Mars cloud annotation clustering parameter set by weighted DBSCAN, greedy expert-centroid matching, F1, and mean localization error."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind annotation coordinate fields, image-key field, max match distance and evaluation threshold from `Instruction.md`. For points `(x,y)` and shape weight `w`, precompute pairwise distance using scaled difference `(w*dx, (2-w)*dy)` and Euclidean norm.
2. Run `DBSCAN(eps=epsilon,min_samples=min_samples,metric="precomputed")`. Do **not** early-return merely because point count is below `min_samples`; let DBSCAN label all noise. Only an empty citizen-science set returns F1 0 and delta NaN directly.
3. For each non-noise label, centroid is the arithmetic mean of member `(x,y)`.
4. Match centroids to expert points greedily: compute ordinary Euclidean distance matrix, repeatedly choose the global minimum, stop when minimum is `>= <task max_distance>`, and invalidate the entire matched row/column. Then `TP=matches`, `FP=centroids-TP`, `FN=experts-TP`.
5. If TP is zero, return F1 0 and delta NaN. Otherwise compute precision, recall, harmonic F1 and mean matched distance. No Hungarian matching or alternate metric is used.

## Checks

Require finite annotation coordinates, positive `epsilon`, positive integer `min_samples`, and finite shape weight. The precomputed distance matrix must be square, symmetric, nonnegative, and zero on its diagonal before DBSCAN. Every non-noise cluster centroid must be finite. Greedy matching may use each centroid/expert point at most once and every accepted match must have distance strictly below the Task maximum. Require `TP+FP == number_of_centroids`, `TP+FN == number_of_experts`, F1 in `[0,1]`, and finite nonnegative delta when `TP>0`; otherwise reject the parameter evaluation.
