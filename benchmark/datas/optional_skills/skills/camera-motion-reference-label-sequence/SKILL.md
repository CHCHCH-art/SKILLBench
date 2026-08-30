---
name: camera-motion-reference-label-sequence
description: "Classify homography translation/scale into camera-motion labels, smooth framewise labels temporally, and merge identical consecutive label sets into interval instructions for egomotion video tasks."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference classification
With no homography, emit the task's stationary label. Otherwise let `m=sqrt(dx^2+dy^2)` and `s=scale`:
- if `m < 3.0` and `abs(s-1)<0.02`, stationary;
- if `s>1.01`, add dolly-in; if `s<0.99`, add dolly-out;
- if `abs(dx)>8.0`, positive `dx` maps to the reference left-pan label and negative `dx` to the right-pan label;
- if `abs(dy)>12.0`, positive `dy` maps to the reference up-tilt label and negative `dy` to the down-tilt label;
- if no label was added, stationary.
Bind the actual label strings from `Instruction.md` rather than hard-coding Task vocabulary into reusable code.

## Smoothing and intervals
1. Use a centered temporal window of 3 frames. Collect labels from the clipped neighborhood.
2. Retain labels whose count is at least `neighborhood_frame_count/2`; if none qualify, use the most frequent label. Sort retained labels deterministically.
3. Merge consecutive frames with identical sorted label tuples. Emit inclusive sample-index intervals using the Task-requested key/schema format.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
