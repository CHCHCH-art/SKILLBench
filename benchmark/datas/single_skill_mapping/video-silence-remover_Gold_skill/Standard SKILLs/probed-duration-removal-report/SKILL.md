---
name: probed-duration-removal-report
description: Produce a duration-consistent JSON report after interval-based video removal. Probe original and compressed media durations, derive removed duration and compression percentage from those measured durations, preserve the detector's removal intervals unchanged, apply the task-provided output schema, and validate arithmetic and interval consistency.
---

# Probed-duration removal report

Use this SKILL after the compressed video has been successfully rendered. Reporting must describe the actual media output; it must not estimate compressed duration solely from segment lengths.

## Dependencies

Run:

```bash
bash scripts/ensure_dependencies.sh --check || bash scripts/ensure_dependencies.sh --install
```

## Inputs and schema binding

Bind from the active task/workflow:

- original video path;
- compressed video path;
- exact removal segment list produced by the detector;
- report output path;
- report field names and required JSON structure from the current task specification.

Do not rename fields based on this SKILL. Populate the schema requested by the task.

## Procedure

### 1. Probe actual media durations

For each video, obtain container duration with:

```bash
ffprobe -v error \
  -show_entries format=duration \
  -of default=noprint_wrappers=1:nokey=1 \
  "$VIDEO"
```

Parse the result as a float.

Let:

- `O` = probed original duration;
- `C` = probed compressed duration.

### 2. Derive compression metrics from probed durations

Compute on unrounded values:

\[
R = O - C
\]

\[
P = 100 \cdot \frac{R}{O}.
\]

The procedure defines removed duration from the **difference between actual media durations**, not from `sum(segment.duration)`. Encoder/container timing can make those quantities differ slightly.

Round each reported top-level duration and percentage to two decimal places only when constructing the JSON object.

### 3. Preserve detector intervals

Copy `segments_removed` from the detector output without shifting, padding, recomputing, or rounding its boundaries merely to reconcile report arithmetic. Each segment retains its existing `start`, `end`, and `duration` values.

### 4. Write JSON

Populate the task-provided report schema with:

- rounded original duration;
- rounded compressed duration;
- rounded `O-C` removed duration;
- rounded compression percentage;
- unchanged removal segments.

Write UTF-8 JSON with indentation and a trailing newline.

## Checks

Before writing:

- `O` and `C` are finite and positive;
- `C <= O` for a removal-only workflow; otherwise abort because the media result contradicts the intended transformation;
- every removal segment satisfies `start < end` and `duration == end-start` under the detector's timestamp convention;
- removal segments are ordered by start and remain inside the original media timeline;
- the task-required JSON keys are all present before serialization.

After writing:

- parse the JSON again and verify schema completeness and numeric types;
- using the reported rounded numbers, verify `original ≈ compressed + removed` within a tolerance compatible with two-decimal rounding (for example `0.02` seconds);
- verify the reported percentage is consistent with the reported/probed duration values to the requested rounding precision;
- verify the report's segment list is exactly the detector's segment list, not a renderer-derived replacement;
- verify both output files exist and are non-empty.

If a check fails, correct the reporting or rendering error; do not alter detection intervals solely to make report arithmetic pass.
