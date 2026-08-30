---
name: video-global-egomotion-estimation
description: "Estimate frame-to-frame camera motion from sampled video using reference KLT tracks, forward/backward filtering, affine RANSAC, phase-correlation fallback, scene-cut detection, and ECC refinement, then project the transform to rotation/translation parameters."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Task binding and sampling

Read the required sampling frame rate and video path from the current task specification. The reference uses source FPS from the container and falls back to **30 FPS** if unavailable. Sample source frame indices by timestamp `i / source_fps` against the Task rate, with the reference `+1e-9` boundary epsilon.

## Reference motion estimation

1. Detect Shi-Tomasi features with reference defaults: `maxCorners=2000`, `qualityLevel=0.008`, `minDistance=6`, `blockSize=7`. The reference also distributes candidates over a `6 x 8` image grid to avoid concentration.
2. Track with pyramidal Lucas-Kanade using window `(21,21)`, `maxLevel=4`, and termination `(40 iterations, 0.01 epsilon)`. Run forward and backward tracking and retain points whose forward/backward discrepancy is `< 1.5` pixels.
3. Require at least **16** usable tracks for the normal affine path. Estimate the global affine transform with RANSAC: reprojection threshold `2.5`, `maxIters=5000`, confidence `0.995`, refinement iterations `20`.
4. When the normal track/affine estimate is unavailable, use the reference phase-correlation fallback rather than changing motion models.
5. Detect scene cuts with the combined reference conditions: histogram similarity `< 0.10`, mean absolute frame difference `> 35`, and either usable tracks `< 16` or RANSAC inlier ratio `< 0.15`. Treat a cut as a reset boundary for temporal motion state.
6. Refine accepted motion with ECC using Gaussian filter size `5`, maximum `80` iterations, epsilon `1e-5`, and the reference transform/filter path.
7. Project the affine linear block to its closest rotation via SVD, and use the reference median-scale treatment before extracting translation/rotation quantities.

## Checks

Keep track count, inlier ratio, cut diagnostics, fallback usage, and ECC success per sampled transition. Reject nonfinite transform parameters before downstream labeling.

