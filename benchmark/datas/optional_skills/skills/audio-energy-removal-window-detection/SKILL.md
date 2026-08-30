---
name: audio-energy-removal-window-detection
description: Detect a removable leading non-content interval and long low-energy pauses in a teaching or spoken-content video using a deterministic mono-audio RMS recipe. Extract 16 kHz PCM audio, compute one-second RMS bins, detect the opening with a smoothed global threshold, detect later pauses with a local moving-average threshold, then return sorted removal and complementary keep intervals.
---

# Audio-energy removal-window detection

Use this SKILL when a video-processing workflow needs the same deterministic audio segmentation recipe rather than an adaptive or model-based silence detector. Do not add visual heuristics, VAD models, percentile thresholds, or parameter tuning unless the current task explicitly requires a different procedure.

## Dependencies

Run:

```bash
bash scripts/ensure_dependencies.sh --check || bash scripts/ensure_dependencies.sh --install
```

The procedure requires `ffmpeg`, `ffprobe`, Python 3, NumPy, and SciPy.

## Inputs and bindings

Read the input video path from the current task specification. The following values are procedure defaults chosen by this recipe, not task-supplied values:

- audio sample rate: `16000` Hz;
- RMS window duration: `1` second;
- opening threshold multiplier: `1.7`;
- opening baseline length: first `60` RMS bins, or all bins if fewer than 60 exist;
- opening smoothing width: `30` bins;
- pause threshold ratio: `0.55`;
- minimum pause duration: `2` RMS bins/seconds;
- pause local-average width: `30` bins.

Keep these defaults when reproducing this procedure. In particular, the task wording that pauses are “usually” longer than a duration is descriptive; the operational cutoff here is the explicit procedure default above.

## Procedure

### 1. Extract analysis audio

Create a temporary WAV from the input video with exactly this audio representation:

```bash
ffmpeg -loglevel error -y \
  -i "$INPUT_VIDEO" \
  -vn -acodec pcm_s16le -ar 16000 -ac 1 \
  "$TMP/audio.wav"
```

Do not analyze the compressed audio stream directly. The downstream RMS values assume mono signed 16-bit PCM.

### 2. Compute one-second RMS bins

Read all WAV samples as `int16`, convert to `float32`, and split them into consecutive windows of `sample_rate * 1` samples. Keep the final partial window if it is non-empty.

For samples `x_1,...,x_n` in a window, compute

\[
E = \sqrt{\frac{1}{n}\sum_{k=1}^{n}x_k^2}.
\]

Append one floating-point RMS value per window. Because the window is exactly one second, RMS-array index `i` is used directly as timestamp `i` seconds by the later logic; do not add half-window offsets.

Equivalent code:

```python
window_size = int(sample_rate * 1)
energies = []
for i in range(0, len(audio), window_size):
    window = audio[i:i + window_size]
    if len(window):
        energies.append(float(np.sqrt(np.mean(window ** 2))))
```

### 3. Detect the leading interval

Let `arr = np.asarray(energies)`.

1. Compute `initial_avg = mean(arr[:min(60, len(arr))])`.
2. Compute `threshold = initial_avg * 1.7`.
3. If `len(arr) >= 30`, smooth with

```python
smoothed = np.convolve(arr, np.ones(30) / 30, mode="valid")
```

   Otherwise use `smoothed = arr` unchanged.
4. Scan `smoothed` from index zero. Return the first index `i` for which `smoothed[i] > threshold`.
5. If no smoothed value is strictly above the threshold, return `0`.

The returned index itself is the opening end time. Do **not** compensate for the `valid` convolution width by adding 29 seconds or a center offset.

If the returned value `opening_end` is greater than zero, emit exactly one leading removal interval:

```python
{"start": 0, "end": opening_end, "duration": opening_end}
```

If it is zero, emit no opening interval.

### 4. Detect low-energy pauses after the opening

Compute a local average with SciPy exactly as follows:

```python
local_avg = uniform_filter1d(arr, size=30, mode="nearest")
low = arr < (local_avg * 0.55)
```

The comparison is strict `<`, not `<=`.

Starting at `i = int(opening_end)`, group consecutive `True` values in `low`:

- entering a `True` run records `segment_start = i`;
- the first subsequent `False` closes the run at exclusive end `i`;
- `duration = i - segment_start`;
- keep the run only when `duration >= 2`;
- if a run reaches the end of the array, close it at `len(arr)` and apply the same minimum-duration test.

Each accepted pause is represented as:

```python
{"start": segment_start, "end": end_index, "duration": end_index - segment_start}
```

Do not pad, merge by proximity, shift, round, or visually refine these intervals.

### 5. Form the removal and keep lists

Combine the optional opening interval with all detected pause intervals and sort by ascending `start`.

To compute keep intervals for a video of duration `T`:

```python
keep = []
current = 0.0
for seg in sorted(remove_segments, key=lambda s: s["start"]):
    start = float(seg["start"])
    end = float(seg["end"])
    if current < start:
        keep.append((current, start))
    current = max(current, end)
if current < T:
    keep.append((current, T))
```

This `max(current, end)` convention makes the complement robust to overlap without altering the emitted removal list.

## Checks

Before rendering video, verify all of the following:

- the extracted WAV reports 16 kHz mono PCM and produces at least one RMS bin;
- every energy is finite and non-negative;
- the opening endpoint is an integer in `[0, len(energies)]`;
- every emitted removal interval satisfies `0 <= start < end <= len(energies)` and `duration == end - start`;
- every pause interval after the opening has duration at least 2 seconds;
- removal intervals are sorted by `start` before the keep-complement calculation;
- keep intervals are positive-length, ordered, non-overlapping, and stay inside `[0, video_duration]`;
- at least one keep interval remains before invoking the video renderer.

If any required invariant fails, abort rather than silently changing thresholds or inventing replacement segments.

## Reusable implementation

`scripts/detect_segments.py` implements this exact segmentation recipe and prints JSON containing `energies`, `opening_end`, `remove_segments`, and `keep_segments`. Use it when a deterministic executable implementation is preferable to re-creating the algorithm inline.
