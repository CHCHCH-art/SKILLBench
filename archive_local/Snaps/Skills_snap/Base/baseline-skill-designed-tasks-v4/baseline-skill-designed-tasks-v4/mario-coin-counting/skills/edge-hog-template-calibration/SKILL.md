---
name: edge-hog-template-calibration
description: "Calibrate edge-component/HOG template detectors for counting task-specified object classes in extracted gameplay-video keyframes, using the reference Canny/HOG signatures, perturbations, cosine similarities, and per-class thresholds."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Convert each Task template to grayscale. Reference constants: Canny thresholds **80/160**, HOG resize **64×64**, **4×4 cells**, **9 bins** over unsigned 0–180° orientation.
2. HOG implementation: resize to 64, Sobel derivatives with kernel 3, `cartToPolar(..., angleInDegrees=True)`, reduce angles modulo 180, hard-bin each pixel with `floor(angle/(180/9))`, accumulate magnitude per cell/bin, flatten, and global-L2 normalize.
3. Edge signatures come from Canny connected components (8-connectivity). Keep stable template components with area ≥10 and width/height ≥3; store component dimensions, area and HOG descriptor.
4. Positive perturbations are original, gain 0.9, gain 1.1, Gaussian blur 3×3 sigma 0.6, and JPEG quality 85 when encode/decode succeeds.
5. For each class, compute the 10th percentile of positive cosine similarities and the maximum similarity to every other class template resized to the class template size. Reference threshold is the average of those two values. Bind class names from Instruction; do not bake Task labels into the SKILL.

## Checks

Require every Task template to decode successfully and produce at least one retained edge signature. Each HOG descriptor must have the reference dimensionality `4*4*9`, contain only finite values, and be globally L2-normalized when its norm is nonzero. Positive perturbation similarities and cross-class negative similarities must be finite before percentile/max operations. The calibrated threshold for each class must equal `(positive_10th_percentile + negative_ceiling)/2` using the stated perturbation set and available other-class templates. Missing signatures, malformed descriptors, nonfinite similarities, or an undefined threshold aborts calibration; do not substitute a different feature extractor or hand-tuned threshold.
