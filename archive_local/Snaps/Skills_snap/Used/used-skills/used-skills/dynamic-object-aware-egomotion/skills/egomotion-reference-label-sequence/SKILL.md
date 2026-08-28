---
name: egomotion-reference-label-sequence
description: "For dynamic-object-aware video egomotion labeling, convert masked global camera-motion estimates and scene-cut state into the reference discrete motion-label sequence, preserving threshold floors, hysteresis, smoothing, and contiguous interval merging while binding task labels/thresholds from current task specification."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Bind label names, Task-provided motion thresholds, sampling rate, and required interval format from the current task specification. Consume the filtered global transforms and dynamic masks rather than recomputing motion on unmasked pixels.
2. Compute the reference per-transition translation/rotation statistics and their robust/global scale estimates exactly as specified here. Apply its threshold floors before comparing motion values; Task thresholds remain Task-bound parameters, not SKILL constants.
3. Apply the reference stateful hysteresis rules in chronological order. Scene-cut/reset states break continuity exactly where the motion-estimation step marks them.
4. Smooth the raw label sequence with the reference temporal neighborhood/voting logic, retaining deterministic tie handling.
5. Convert the final sampled labels to contiguous time intervals and merge adjacent intervals only under the reference equality/continuity rule. Derive timestamps from sampled-frame timing rather than independently rounding frame numbers.

## Checks

Recreate labels from stored motion features and confirm deterministic equality. Intervals must be ordered, nonoverlapping, cover exactly the label sequence's represented time span, and round only at the Task-requested serialization boundary.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

