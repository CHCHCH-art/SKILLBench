#!/bin/bash
set -euo pipefail

INPUT_VIDEO="${INPUT_VIDEO:-data/input_video.mp4}"
OUTPUT_VIDEO="${OUTPUT_VIDEO:-compressed_video.mp4}"
OUTPUT_REPORT="${OUTPUT_REPORT:-compression_report.json}"

python3 - "$INPUT_VIDEO" "$OUTPUT_VIDEO" "$OUTPUT_REPORT" <<'PY'
import json
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np
from scipy.ndimage import uniform_filter1d

INPUT_VIDEO, OUTPUT_VIDEO, OUTPUT_REPORT = sys.argv[1:4]
SAMPLE_RATE = 16000
WINDOW_SECONDS = 1


def run(cmd):
    subprocess.run(cmd, check=True)


def get_duration(path):
    result = subprocess.run(
        [
            "ffprobe", "-v", "error",
            "-show_entries", "format=duration",
            "-of", "default=noprint_wrappers=1:nokey=1",
            path,
        ],
        check=True,
        capture_output=True,
        text=True,
    )
    return float(result.stdout.strip())


def extract_audio(video_path, wav_path):
    run([
        "ffmpeg", "-loglevel", "error", "-y",
        "-i", video_path,
        "-vn", "-acodec", "pcm_s16le",
        "-ar", str(SAMPLE_RATE), "-ac", "1",
        wav_path,
    ])


def calculate_energies(wav_path):
    with wave.open(wav_path, "rb") as wav_file:
        sample_rate = wav_file.getframerate()
        raw = wav_file.readframes(wav_file.getnframes())
    audio = np.frombuffer(raw, dtype=np.int16).astype(np.float32)
    window_size = int(sample_rate * WINDOW_SECONDS)
    energies = []
    for i in range(0, len(audio), window_size):
        window = audio[i:i + window_size]
        if len(window):
            energies.append(float(np.sqrt(np.mean(window ** 2))))
    return energies


def detect_initial_silence(energies, threshold_multiplier=1.7, initial_window=60, smoothing_window=30):
    arr = np.asarray(energies)
    initial_avg = np.mean(arr[:min(initial_window, len(arr))])
    threshold = initial_avg * threshold_multiplier
    if len(arr) >= smoothing_window:
        smoothed = np.convolve(arr, np.ones(smoothing_window) / smoothing_window, mode="valid")
    else:
        smoothed = arr
    for i, value in enumerate(smoothed):
        if value > threshold:
            return i
    return 0


def detect_pauses(energies, start_time, threshold_ratio=0.55, min_duration=2, window_size=30):
    arr = np.asarray(energies)
    local_avg = uniform_filter1d(arr, size=window_size, mode="nearest")
    low = arr < (local_avg * threshold_ratio)

    segments = []
    in_segment = False
    segment_start = 0
    for i in range(int(start_time), len(low)):
        if low[i]:
            if not in_segment:
                segment_start = i
                in_segment = True
        elif in_segment:
            duration = i - segment_start
            if duration >= min_duration:
                segments.append({"start": segment_start, "end": i, "duration": duration})
            in_segment = False

    if in_segment:
        duration = len(arr) - segment_start
        if duration >= min_duration:
            segments.append({"start": segment_start, "end": len(arr), "duration": duration})
    return segments


def calculate_keep_segments(remove_segments, total_duration):
    keep = []
    current = 0.0
    for seg in remove_segments:
        start = float(seg["start"])
        end = float(seg["end"])
        if current < start:
            keep.append((current, start))
        current = max(current, end)
    if current < total_duration:
        keep.append((current, total_duration))
    return keep


def process_video(input_path, output_path, keep_segments):
    if not keep_segments:
        raise RuntimeError("No video content remains after silence removal")

    parts = []
    for i, (start, end) in enumerate(keep_segments):
        parts.append(f"[0:v]trim=start={start}:end={end},setpts=PTS-STARTPTS[v{i}]")
        parts.append(f"[0:a]atrim=start={start}:end={end},asetpts=PTS-STARTPTS[a{i}]")

    v_inputs = "".join(f"[v{i}]" for i in range(len(keep_segments)))
    a_inputs = "".join(f"[a{i}]" for i in range(len(keep_segments)))
    parts.append(f"{v_inputs}concat=n={len(keep_segments)}:v=1:a=0[outv]")
    parts.append(f"{a_inputs}concat=n={len(keep_segments)}:v=0:a=1[outa]")

    run([
        "ffmpeg", "-loglevel", "error", "-y",
        "-i", input_path,
        "-filter_complex", ";".join(parts),
        "-map", "[outv]", "-map", "[outa]",
        "-c:v", "libx264", "-preset", "ultrafast", "-crf", "23",
        "-c:a", "aac", "-b:a", "128k",
        output_path,
    ])


def main():
    if not os.path.isfile(INPUT_VIDEO):
        raise FileNotFoundError(f"Input video not found: {INPUT_VIDEO}")

    print("=== Video Silence Remover ===")
    with tempfile.TemporaryDirectory(prefix="video-silence-remover-") as tmpdir:
        wav_path = os.path.join(tmpdir, "audio.wav")

        print("Step 1/5: extracting audio")
        extract_audio(INPUT_VIDEO, wav_path)

        print("Step 2/5: calculating energy")
        energies = calculate_energies(wav_path)

        print("Step 3/5: detecting silence and pauses")
        silence_end = detect_initial_silence(energies)
        segments = []
        if silence_end > 0:
            segments.append({"start": 0, "end": silence_end, "duration": silence_end})
        segments.extend(detect_pauses(energies, silence_end))
        segments.sort(key=lambda s: s["start"])

        print(f"Detected {len(segments)} removal segments")
        for seg in segments:
            print(f"  {seg['start']}s -> {seg['end']}s ({seg['duration']}s)")

        print("Step 4/5: processing video")
        original_duration = get_duration(INPUT_VIDEO)
        keep_segments = calculate_keep_segments(segments, original_duration)
        process_video(INPUT_VIDEO, OUTPUT_VIDEO, keep_segments)

        print("Step 5/5: writing report")
        compressed_duration = get_duration(OUTPUT_VIDEO)
        removed_duration = original_duration - compressed_duration
        report = {
            "original_duration_seconds": round(original_duration, 2),
            "compressed_duration_seconds": round(compressed_duration, 2),
            "removed_duration_seconds": round(removed_duration, 2),
            "compression_percentage": round((removed_duration / original_duration) * 100, 2),
            "segments_removed": segments,
        }
        with open(OUTPUT_REPORT, "w", encoding="utf-8") as f:
            json.dump(report, f, indent=2)
            f.write("\n")

    print(f"Wrote {OUTPUT_VIDEO}")
    print(f"Wrote {OUTPUT_REPORT}")


if __name__ == "__main__":
    main()
PY
