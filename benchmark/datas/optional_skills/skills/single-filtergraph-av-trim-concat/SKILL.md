---
name: single-filtergraph-av-trim-concat
description: Rebuild a video from an ordered list of keep intervals using one FFmpeg filter graph. Trim video and audio for each interval, reset timestamps, concatenate video and audio streams independently, then encode H.264/AAC with fixed rendering parameters. Use after deterministic silence or non-content interval detection.
---

# Single-filtergraph A/V trim and concat

This SKILL consumes keep intervals that have already been decided. It does not detect silence and must not modify segment boundaries.

## Dependencies

Run:

```bash
bash scripts/ensure_dependencies.sh --check || bash scripts/ensure_dependencies.sh --install
```

## Inputs

Bind from the current task/workflow:

- `<input_video>`;
- `<output_video>`;
- ordered `<keep_segments>` as `(start_seconds, end_seconds)` pairs.

The rendering procedure uses these fixed encoding choices:

- H.264 encoder: `libx264`;
- preset: `ultrafast`;
- CRF: `23`;
- audio codec: AAC;
- audio bitrate: `128k`.

## Procedure

1. Reject an empty keep list with an explicit error. Do not emit an empty video.
2. For each keep interval `(s_i, e_i)`, create two filter chains from the original input:

```text
[0:v]trim=start=s_i:end=e_i,setpts=PTS-STARTPTS[v_i]
[0:a]atrim=start=s_i:end=e_i,asetpts=PTS-STARTPTS[a_i]
```

3. Concatenate all video labels in interval order:

```text
[v0][v1]...[vN-1]concat=n=N:v=1:a=0[outv]
```

4. Concatenate all audio labels in the same order:

```text
[a0][a1]...[aN-1]concat=n=N:v=0:a=1[outa]
```

5. Join every filter chain with semicolons and run one FFmpeg command:

```bash
ffmpeg -loglevel error -y \
  -i "$INPUT" \
  -filter_complex "$FILTERGRAPH" \
  -map '[outv]' -map '[outa]' \
  -c:v libx264 -preset ultrafast -crf 23 \
  -c:a aac -b:a 128k \
  "$OUTPUT"
```

Do not independently seek and encode each keep interval in this recipe. Do not use stream copy in the final render. The defining behavior is a single filtergraph over the original input.

## Checks

Before invoking FFmpeg:

- keep intervals must be ordered and satisfy `0 <= start < end <= original_duration`;
- intervals must not overlap;
- every video and audio trim must use the same start/end pair;
- label indices must be contiguous from zero through `N-1`;
- concat `n` must equal the number of keep intervals for both streams.

After rendering:

- `<output_video>` must exist and have non-zero size;
- `ffprobe` must show one decodable video stream and one decodable audio stream;
- output duration must be positive and should be close to `sum(end-start)`; small encoder/container timing differences are acceptable, but a large discrepancy is a rendering failure;
- do not alter the keep list to make the duration check pass.

Abort on failure rather than silently switching to a different segmentation or rendering strategy.

## Reusable implementation

`scripts/render_keep_segments.py` accepts an input video, output path, and JSON keep-segment file and executes this exact filtergraph procedure.
