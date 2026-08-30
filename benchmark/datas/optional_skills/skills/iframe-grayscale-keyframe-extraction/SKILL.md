---
name: iframe-grayscale-keyframe-extraction
description: "Extract video I-frames as timeline-ordered keyframes with ffmpeg and convert each extracted image in place to grayscale using ImageMagick, while binding task file paths and naming patterns from current task specification."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind input video, output keyframe directory/pattern, and required frame-ID presentation from the current task specification.
2. Run ffmpeg with video filter `select='eq(pict_type,I)'` and variable-frame-rate output (`-vsync vfr`) so only codec I-frames are written.
3. Use the Task-provided filename pattern for sequential output naming. Process the resulting shell-glob order used by the procedure.
4. Convert every keyframe **in place** to grayscale with ImageMagick `-colorspace Gray`; accept either `convert` or the equivalent `magick` command in environments where one replaces the other.

## Checks
Ensure all extracted keyframes remain readable after in-place conversion and the final frame sequence matches the reference filename/timeline ordering.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.
