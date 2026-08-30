---
name: dynamic-region-motion-mask
description: "Build dynamic-object masks that exclude non-camera motion from egomotion analysis using the reference dense flow, forward/backward consistency, appearance residual, morphology, temporal voting, and optional GrabCut branch."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Use OpenCV DIS dense optical flow with the reference **MEDIUM** preset for the primary dense-motion path.
2. If that path fails, fall back to Farneback with reference parameters `pyr_scale=0.5`, `levels=5`, `winsize=21`, `iterations=5`, `poly_n=7`, `poly_sigma=1.5`.
3. Compute forward and backward flow. Mark a flow correspondence inconsistent when the forward/backward discrepancy exceeds `0.75 + 0.05 * magnitude`, subject to the reference inside-image validity test.
4. Apply the specified morphology sequence to clean the binary candidate mask. Combine temporal evidence over a **radius of 3 sampled frames** using the reference vote rule.
5. Compute the appearance-difference residual after global alignment; derive its threshold from `median + 2*MAD` with a floor of `9`. Combine this residual with motion inconsistency using the reference area-scaling, dilation, and voting logic.
6. GrabCut refinement is disabled by default. Enable the reference branch only when environment variable `ALT_ENABLE_GRABCUT=1`; do not make it the normal path.

## Checks

For every processed frame, require forward/backward flow arrays to match image dimensions and contain finite vectors at valid pixels. Retain audit values for raw flow inconsistency, appearance candidate area, and final mask area; each final mask must be binary and image-aligned. Scene-cut/reset frames must not borrow temporal votes across the reset boundary. Abort if both dense-flow paths fail, residual thresholds become non-finite, mask dimensions drift, or temporal state crosses a reset.
