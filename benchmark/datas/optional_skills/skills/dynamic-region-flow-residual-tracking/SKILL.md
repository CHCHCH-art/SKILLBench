---
name: dynamic-region-flow-residual-tracking
description: "Detect dynamic-object pixels as dense-flow residuals against homography motion, apply the reference spatial weighting/morphology, and temporally propagate masks by optical-flow warping."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Build a spatial weight map initialized to 1.0: bottom 30% receives factor 0.3; vertical range 50–70% factor 0.7; leftmost 20% factor 0.5. Exclude a **20-pixel** border.
2. Compute deviation magnitude between observed flow and expected homography flow (or median global flow fallback), multiply by the spatial weights, and set threshold `max(1.0, 2.5*std(weighted_deviation))`.
3. Threshold, apply 5x5 morphological OPEN then CLOSE, find 8-connected components, and keep components with area at least `0.0008*H*W`. If this filtering removes everything while the raw threshold mask was nonempty, return the raw dynamic mask.
4. Temporal tracker reference defaults: `decay=0.7`, decision threshold `0.3`. Warp previous mask/confidence with remap coordinates `(x+flow_x,y+flow_y)`, linear interpolation and constant-zero border.
5. Fuse `0.6*current + 0.4*decay*warped_previous`; confidence is `max(current, decay*warped_confidence)`. Threshold fused result at `0.3`, then apply 3x3 close. Update tracker state; do not introduce object detectors or semantic segmentation.

## Checks

Require observed flow, expected/global flow, weight map, raw mask, filtered mask, tracker mask, and confidence arrays to match the current frame dimensions. All flow/deviation/confidence values used for thresholding or warping must be finite, and the computed threshold must be finite and at least `1.0`. The excluded border must remain excluded from component acceptance. After morphology/component filtering, every retained component must satisfy the stated area rule; use the raw-mask fallback only when the filtered mask is empty while the raw threshold mask is nonempty. Warped/fused tracker arrays must remain finite and the final mask must be binary with the same frame shape. Shape mismatch, nonfinite flow, invalid remap coordinates/outputs, or an impossible tracker state aborts this step rather than switching to another motion model.
