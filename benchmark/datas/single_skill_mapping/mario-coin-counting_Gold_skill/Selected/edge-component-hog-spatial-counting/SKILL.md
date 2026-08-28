---
name: edge-component-hog-spatial-counting
description: "Count task-specified template objects in gameplay-video keyframes by generating edge-component spatial candidates, classifying crops with calibrated HOG cosine similarity, and suppressing duplicate detections."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Compute frame edge components with the calibrated Canny settings. For each model signature, accept component size differences only within `max(2,0.25*signature_width/height)` and area difference within `max(8,0.35*signature_area)`; infer candidate top-left by aligning component centers to signature centers.
2. Also generate broad component-alignment candidates when component width is 0.72–1.30 of template width, height 0.50–1.20 of template height, and area at least `max(12,0.04*template_area)`; propose the reference three alignments. Reject windows outside frame bounds and merge candidate origins within 2 pixels in both axes.
3. Resize each candidate crop to the model template size, compute reference HOG and cosine similarity, and keep only scores at or above the calibrated class threshold.
4. Sort detections by score descending. Suppress a candidate when its top-left is within Euclidean distance `max(4,0.40*min(template_width,template_height))` of an already kept detection.
5. Count retained detections by Task-bound class and emit rows in keyframe order using Task output schema.

## Checks

Every proposed crop must lie fully inside the frame and have the template dimensions before HOG extraction. Candidate descriptors must match the calibrated descriptor length and produce finite cosine similarities. Retained detections must meet their class threshold; after score-descending suppression, no two kept detections for the same template may violate the stated spatial suppression radius. Per-class counts must equal the number of retained detections, and emitted rows must preserve keyframe order. Out-of-bounds crops, descriptor-shape mismatch, nonfinite scores, missing calibration data, or inconsistent counts abort counting rather than triggering a sliding-window/template-correlation fallback.
