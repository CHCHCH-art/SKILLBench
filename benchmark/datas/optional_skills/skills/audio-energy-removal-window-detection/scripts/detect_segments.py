#!/usr/bin/env python3
import argparse, json, os, subprocess, tempfile, wave
import numpy as np
from scipy.ndimage import uniform_filter1d

SAMPLE_RATE = 16000
WINDOW_SECONDS = 1

def run(cmd):
    subprocess.run(cmd, check=True)

def duration(path):
    r = subprocess.run([
        "ffprobe", "-v", "error", "-show_entries", "format=duration",
        "-of", "default=noprint_wrappers=1:nokey=1", path
    ], check=True, capture_output=True, text=True)
    return float(r.stdout.strip())

def energies_from_video(path, tmp):
    wav = os.path.join(tmp, "audio.wav")
    run(["ffmpeg", "-loglevel", "error", "-y", "-i", path, "-vn",
         "-acodec", "pcm_s16le", "-ar", str(SAMPLE_RATE), "-ac", "1", wav])
    with wave.open(wav, "rb") as f:
        sr = f.getframerate()
        raw = f.readframes(f.getnframes())
    audio = np.frombuffer(raw, dtype=np.int16).astype(np.float32)
    ws = int(sr * WINDOW_SECONDS)
    return [float(np.sqrt(np.mean(audio[i:i+ws] ** 2)))
            for i in range(0, len(audio), ws) if len(audio[i:i+ws])]

def opening_end(energies):
    arr = np.asarray(energies)
    avg = np.mean(arr[:min(60, len(arr))])
    threshold = avg * 1.7
    smoothed = np.convolve(arr, np.ones(30)/30, mode="valid") if len(arr) >= 30 else arr
    for i, v in enumerate(smoothed):
        if v > threshold:
            return i
    return 0

def pauses(energies, start_time):
    arr = np.asarray(energies)
    local = uniform_filter1d(arr, size=30, mode="nearest")
    low = arr < (local * 0.55)
    out, active, s = [], False, 0
    for i in range(int(start_time), len(low)):
        if low[i]:
            if not active:
                s, active = i, True
        elif active:
            d = i - s
            if d >= 2:
                out.append({"start": s, "end": i, "duration": d})
            active = False
    if active:
        d = len(arr) - s
        if d >= 2:
            out.append({"start": s, "end": len(arr), "duration": d})
    return out

def complement(remove, total):
    out, cur = [], 0.0
    for seg in sorted(remove, key=lambda x: x["start"]):
        s, e = float(seg["start"]), float(seg["end"])
        if cur < s:
            out.append([cur, s])
        cur = max(cur, e)
    if cur < total:
        out.append([cur, total])
    return out

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("video")
    args = ap.parse_args()
    with tempfile.TemporaryDirectory(prefix="rms-segments-") as tmp:
        e = energies_from_video(args.video, tmp)
    if not e or not np.all(np.isfinite(e)):
        raise RuntimeError("audio analysis produced no finite RMS bins")
    oe = opening_end(e)
    remove = []
    if oe > 0:
        remove.append({"start": 0, "end": oe, "duration": oe})
    remove.extend(pauses(e, oe))
    remove.sort(key=lambda x: x["start"])
    keep = complement(remove, duration(args.video))
    print(json.dumps({"energies": e, "opening_end": oe,
                      "remove_segments": remove, "keep_segments": keep}, indent=2))

if __name__ == "__main__":
    main()
