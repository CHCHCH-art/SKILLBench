---
name: video-iframe-grayscale-keyframes
description: "Extract only I-frame keyframes from a gameplay video with FFmpeg and convert every extracted frame to grayscale before template-based object counting."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind input video, keyframe directory and filename pattern from `Instruction.md`. Remove prior generated keyframes/results before extraction.
2. Run FFmpeg with video filter `select='eq(pict_type\,I)'` and variable-frame-rate output (`-fps_mode vfr`), using the Task-provided naming convention.
3. Convert each produced keyframe in place to grayscale. Accept either ImageMagick `convert` or `magick`; the reference uses the equivalent `-colorspace Gray` operation.
4. Require at least one extracted image and verify images are readable grayscale frames. Abort if FFmpeg/ImageMagick fails rather than substituting fixed-time sampling.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
