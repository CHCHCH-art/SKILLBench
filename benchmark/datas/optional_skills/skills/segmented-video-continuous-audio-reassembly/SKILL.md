---
name: segmented-video-continuous-audio-reassembly
description: Rebuild a video from keep intervals with independent accurate video seeks and encodes, packet-level concatenation of the encoded video parts, one continuous audio trim/concat pass, and a final stream-copy mux. Use when segment boundary fidelity and avoiding repeated AAC encoder delay are part of the video-removal recipe.
---

# Segmented video and continuous-audio reassembly

This SKILL consumes already-decided keep intervals. It does not detect silence and must not adjust interval boundaries.

## Dependencies

Run:

```bash
bash scripts/ensure_dependencies.sh --check || bash scripts/ensure_dependencies.sh --install
```

## Inputs

Bind `<input_video>`, `<output_video>`, and ordered `<keep_segments>` from the active workflow. Create all intermediate files in a temporary directory.

This procedure intentionally treats video and audio differently.

## Procedure

### 1. Independently encode each kept video interval

Reject an empty keep list.

For each `(start, end)`, compute `duration = end - start` and encode a video-only part with an input-side seek:

```bash
ffmpeg -hide_banner -loglevel error -y \
  -ss "<start with 6 decimals>" \
  -i "$INPUT" \
  -t "<duration with 6 decimals>" \
  -an -map 0:v:0 \
  -vf setpts=PTS-STARTPTS \
  -c:v libx264 -preset ultrafast -crf 23 -threads 1 \
  -pix_fmt yuv420p -video_track_timescale 15360 \
  "$TMP/vNNN.mp4"
```

Use zero-padded sequential part names only as an implementation convenience; ordering must follow the keep list.

### 2. Concatenate encoded video packets without another video encode

Create an FFconcat file beginning with:

```text
ffconcat version 1.0
```

Add one absolute `file '<path>'` line for each video part in keep order. Quote paths safely; a literal single quote in a path must be escaped for the concat-file syntax used by the implementation.

Then run:

```bash
ffmpeg -hide_banner -loglevel error -y \
  -f concat -safe 0 -i "$TMP/video.ffconcat" \
  -an -c:v copy "$TMP/video.mp4"
```

Do not re-encode the joined video here.

### 3. Build audio in one continuous trim/concat pass

For every keep interval, construct:

```text
[0:a]atrim=start=<s>:end=<e>,asetpts=PTS-STARTPTS[a_i]
```

Use the same six-decimal interval values and concatenate all audio labels:

```text
[a0][a1]...[aN-1]concat=n=N:v=0:a=1[outa]
```

Encode the resulting audio once:

```bash
ffmpeg -hide_banner -loglevel error -y \
  -i "$INPUT" \
  -filter_complex "$AUDIO_FILTER" \
  -map '[outa]' -c:a aac -b:a 128k -threads 1 \
  "$TMP/audio.m4a"
```

The single audio pass is important: do not AAC-encode every individual segment and then concatenate those AAC packets, because repeated encoder delay changes duration/alignment.

### 4. Final mux by stream copy

Mux the packet-concatenated video and continuous audio without re-encoding:

```bash
ffmpeg -hide_banner -loglevel error -y \
  -i "$TMP/video.mp4" -i "$TMP/audio.m4a" \
  -map 0:v:0 -map 1:a:0 \
  -c copy -shortest -movflags +faststart \
  "$OUTPUT"
```

`-shortest` is part of the procedure and prevents a small A/V tail mismatch from extending the container.

## Checks

Before rendering:

- keep intervals are ordered, non-overlapping, positive-length, and inside the source duration;
- every per-part `-t` equals `end-start` and is positive;
- video part count equals keep interval count;
- the FFconcat file lists every part exactly once and in interval order;
- audio trim count and concat `n` exactly equal the keep interval count.

After each stage:

- every encoded video part exists and is non-empty;
- packet-concatenated video contains a video stream and no required audio dependency;
- continuous audio output contains a decodable audio stream;
- final output contains both mapped streams and has positive duration;
- final duration should be close to `sum(end-start)`; do not modify the detected intervals to compensate for encoding/container drift.

Abort on stage failure. Do not silently replace this multi-stage rendering recipe with a single filtergraph render.

## Reusable implementation

`scripts/render_keep_segments.py` implements this exact multi-stage route for a JSON keep-segment list.
