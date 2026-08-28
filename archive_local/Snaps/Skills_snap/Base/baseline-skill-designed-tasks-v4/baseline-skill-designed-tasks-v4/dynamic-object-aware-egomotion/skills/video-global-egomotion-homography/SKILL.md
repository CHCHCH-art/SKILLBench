---
name: video-global-egomotion-homography
description: "Sample video frames, estimate dense optical flow and ORB/RANSAC homographies, and derive global translation/scale signals for camera-motion analysis with dynamic objects."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. The reference main routine explicitly samples at **5.0 FPS**. Compute interval `max(1, int(original_fps/target_fps))`, read every interval-th frame, and convert selected frames to grayscale. Preserve this reference call even if the Task instruction states a conflicting sampling rate; record that conflict outside the SKILL rather than changing the algorithm.
2. Dense flow is Farneback with `pyr_scale=.5, levels=3, winsize=15, iterations=3, poly_n=5, poly_sigma=1.2, flags=0`.
3. Homography: ORB with 500 features; brute-force Hamming matcher with crossCheck enabled; require at least 10 matches; sort matches by distance; call `findHomography(..., RANSAC, 5.0)`. Return no homography on insufficient descriptors/matches or failed estimation.
4. Expected homography flow: transform the full pixel grid by `H`, divide homogeneous coordinates, and subtract original `(x,y)`. With no `H`, use the component-wise median dense flow as global-motion fallback.
5. Translation is the displacement of the image center under `H`. Scale is the mean ratio of radial distances for four quarter-offset points around the center before/after transform.

## Checks

Require a positive source FPS and at least two sampled grayscale frames before pairwise motion estimation. Dense flow must have shape `(H,W,2)` and finite components. Accept a homography only when descriptor matching satisfies the stated minimum and `findHomography` returns a finite 3x3 matrix whose homogeneous divisions are valid on the evaluation grid; otherwise use only the documented median-flow fallback. Translation and scale signals must be finite, and scale denominators at the four reference points must be nonzero. Invalid flow shapes, nonfinite transforms, or undefined derived signals abort the pair instead of introducing another motion estimator.
