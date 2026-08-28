#!/bin/bash
set -euo pipefail

wd="${MARIO_ROOT:-/root}"
PYTHON=python3

rm -f "$wd"/keyframes_*.png "$wd/counting_results.csv"

echo "Extracting I-frames"
ffmpeg -loglevel error \
  -i "$wd/super-mario.mp4" \
  -vf "select='eq(pict_type\,I)'" \
  -fps_mode vfr \
  "$wd/keyframes_%03d.png"

echo "Converting keyframes to grayscale"
for img in "$wd"/keyframes_*.png; do
  [ -e "$img" ] || continue
  convert "$img" -colorspace Gray "$img"
done

cat > /tmp/mario_edge_hog.py <<'PY'
import csv
import glob
import math
import os

import cv2 as cv
import numpy as np

ROOT = os.environ.get("MARIO_ROOT", "/root")

CANNY_LOW = 80
CANNY_HIGH = 160
HOG_SIZE = 64
HOG_CELLS = 4
HOG_BINS = 9


def cosine(a, b):
    denom = float(np.linalg.norm(a) * np.linalg.norm(b))
    if denom <= 1e-12:
        return 0.0
    return float(np.dot(a, b) / denom)


def hog_descriptor(gray):
    """Small HOG descriptor implemented directly with image gradients."""
    gray = cv.resize(gray, (HOG_SIZE, HOG_SIZE), interpolation=cv.INTER_LINEAR)

    gx = cv.Sobel(gray, cv.CV_32F, 1, 0, ksize=3)
    gy = cv.Sobel(gray, cv.CV_32F, 0, 1, ksize=3)
    magnitude, angle = cv.cartToPolar(gx, gy, angleInDegrees=True)
    angle = np.mod(angle, 180.0)

    cell = HOG_SIZE // HOG_CELLS
    desc = []

    for cy in range(HOG_CELLS):
        for cx in range(HOG_CELLS):
            y1, y2 = cy * cell, (cy + 1) * cell
            x1, x2 = cx * cell, (cx + 1) * cell

            mag = magnitude[y1:y2, x1:x2].ravel()
            ang = angle[y1:y2, x1:x2].ravel()

            bins = np.floor(ang / (180.0 / HOG_BINS)).astype(np.int32)
            bins = np.clip(bins, 0, HOG_BINS - 1)

            hist = np.zeros(HOG_BINS, dtype=np.float32)
            np.add.at(hist, bins, mag)
            desc.extend(hist)

    desc = np.asarray(desc, dtype=np.float32)
    norm = float(np.linalg.norm(desc))
    if norm > 0:
        desc /= norm
    return desc


def edge_components(gray):
    """Return connected edge components from a Canny edge map."""
    edge = cv.Canny(gray, CANNY_LOW, CANNY_HIGH)
    count, labels, stats, centers = cv.connectedComponentsWithStats(edge, 8)

    components = []
    for idx in range(1, count):
        x, y, w, h, area = [int(v) for v in stats[idx]]
        if area < 8:
            continue
        components.append({
            "x": x,
            "y": y,
            "w": w,
            "h": h,
            "area": area,
            "cx": float(centers[idx][0]),
            "cy": float(centers[idx][1]),
        })
    return components


def build_model(path):
    """Learn edge-component geometry and HOG appearance from a task template."""
    image = cv.imread(path, cv.IMREAD_COLOR)
    if image is None:
        raise RuntimeError(f"Cannot read template: {path}")

    gray = cv.cvtColor(image, cv.COLOR_BGR2GRAY)
    H, W = gray.shape

    signatures = []
    for comp in edge_components(gray):
        if comp["area"] < 10 or comp["w"] < 3 or comp["h"] < 3:
            continue
        signatures.append({
            "w": comp["w"],
            "h": comp["h"],
            "area": comp["area"],
            "cx": comp["cx"],
            "cy": comp["cy"],
        })

    if not signatures:
        raise RuntimeError(f"No stable edge signatures found in {path}")

    return {
        "gray": gray,
        "H": H,
        "W": W,
        "signatures": signatures,
        "hog": hog_descriptor(gray),
    }


def perturbations(gray):
    """Generic perturbations used only to calibrate classifier tolerance."""
    result = [gray]

    for gain in (0.90, 1.10):
        result.append(np.clip(gray.astype(np.float32) * gain, 0, 255).astype(np.uint8))

    result.append(cv.GaussianBlur(gray, (3, 3), 0.6))

    ok, encoded = cv.imencode(".jpg", gray, [cv.IMWRITE_JPEG_QUALITY, 85])
    if ok:
        result.append(cv.imdecode(encoded, cv.IMREAD_GRAYSCALE))

    return result


def calibrate_threshold(model, other_models):
    """
    Calibrate a HOG acceptance threshold from the supplied templates only.

    Positives are generic perturbations of this template. Negatives are the
    other task-provided object templates resized to the same window size.
    No video labels or expected counts are used.
    """
    positives = [
        cosine(hog_descriptor(sample), model["hog"])
        for sample in perturbations(model["gray"])
    ]

    negatives = []
    for other in other_models:
        resized = cv.resize(other["gray"], (model["W"], model["H"]), interpolation=cv.INTER_LINEAR)
        negatives.append(cosine(hog_descriptor(resized), model["hog"]))

    positive_floor = float(np.percentile(positives, 10))
    negative_ceiling = max(negatives) if negatives else 0.0

    return (positive_floor + negative_ceiling) / 2.0


def candidate_windows(gray, model):
    """
    Generate object windows from connected edge components.

    Two generic proposal mechanisms are used:
      1. Match component geometry to edge-component signatures learned from
         the supplied object crop and infer the object's top-left position.
      2. Accept components whose bounding boxes are broadly object-sized.

    No pixel-wise template correlation or sliding-window template search is
    performed.
    """
    frame_h, frame_w = gray.shape
    proposals = []

    for comp in edge_components(gray):
        for sig in model["signatures"]:
            width_ok = abs(comp["w"] - sig["w"]) <= max(2.0, 0.25 * sig["w"])
            height_ok = abs(comp["h"] - sig["h"]) <= max(2.0, 0.25 * sig["h"])
            area_ok = abs(comp["area"] - sig["area"]) <= max(8.0, 0.35 * sig["area"])

            if width_ok and height_ok and area_ok:
                x = int(round(comp["cx"] - sig["cx"]))
                y = int(round(comp["cy"] - sig["cy"]))

                if 0 <= x and 0 <= y and x + model["W"] <= frame_w and y + model["H"] <= frame_h:
                    proposals.append((x, y))

        if (
            0.72 * model["W"] <= comp["w"] <= 1.30 * model["W"]
            and 0.50 * model["H"] <= comp["h"] <= 1.20 * model["H"]
            and comp["area"] >= max(12.0, 0.04 * model["W"] * model["H"])
        ):
            variants = (
                (comp["x"], comp["y"]),
                (int(round(comp["cx"] - model["W"] / 2)), int(round(comp["cy"] - model["H"] / 2))),
                (comp["x"], int(round(comp["cy"] - model["H"] / 2))),
            )

            for x, y in variants:
                if 0 <= x and 0 <= y and x + model["W"] <= frame_w and y + model["H"] <= frame_h:
                    proposals.append((x, y))

    unique = []
    for x, y in proposals:
        if not any(abs(x - ux) <= 2 and abs(y - uy) <= 2 for ux, uy in unique):
            unique.append((x, y))

    return unique


def detect(gray, model):
    accepted = []

    for x, y in candidate_windows(gray, model):
        patch = gray[y:y + model["H"], x:x + model["W"]]
        score = cosine(hog_descriptor(patch), model["hog"])

        if score >= model["threshold"]:
            accepted.append((x, y, score))

    accepted.sort(key=lambda item: item[2], reverse=True)
    kept = []
    min_distance = max(4.0, 0.40 * min(model["W"], model["H"]))

    for candidate in accepted:
        x, y, score = candidate
        if any(math.hypot(x - ox, y - oy) < min_distance for ox, oy, _ in kept):
            continue
        kept.append(candidate)

    return kept


paths = {
    "coins": os.path.join(ROOT, "coin.png"),
    "enemies": os.path.join(ROOT, "enemy.png"),
    "turtles": os.path.join(ROOT, "turtle.png"),
}

models = {name: build_model(path) for name, path in paths.items()}

for name, model in models.items():
    others = [other for other_name, other in models.items() if other_name != name]
    model["threshold"] = calibrate_threshold(model, others)
    print(name, "HOG threshold", round(model["threshold"], 4))

frames = sorted(glob.glob(os.path.join(ROOT, "keyframes_*.png")))
if not frames:
    raise RuntimeError("No keyframes extracted")

rows = []

for frame_path in frames:
    gray = cv.imread(frame_path, cv.IMREAD_GRAYSCALE)
    if gray is None:
        raise RuntimeError(f"Cannot read keyframe: {frame_path}")

    counts = {}
    for name, model in models.items():
        detections = detect(gray, model)
        counts[name] = len(detections)
        print(os.path.basename(frame_path), name, counts[name])

    rows.append([
        frame_path,
        counts["coins"],
        counts["enemies"],
        counts["turtles"],
    ])

with open(os.path.join(ROOT, "counting_results.csv"), "w", newline="") as f:
    writer = csv.writer(f)
    writer.writerow(["frame_id", "coins", "enemies", "turtles"])
    writer.writerows(rows)
PY

MARIO_ROOT="$wd" "$PYTHON" /tmp/mario_edge_hog.py
