#!/bin/bash
set -euo pipefail

python3 <<'PYTHON_SCRIPT'
import json
import math
import os
import shutil
import warnings
from pathlib import Path

import cv2
import numpy as np

INPUT_VIDEO = Path('/root/input.mp4')
OUTPUT_JSON = Path('/root/pred_instructions.json')
OUTPUT_MASKS = Path('/root/pred_dyn_masks.npz')
WORK_DIR = Path('/root/alt_solution_work')

TARGET_FPS = 6.0
KLT_MAX_CORNERS = 2000
KLT_FB_THRESHOLD = 1.5
MIN_TRACKS = 16
RANSAC_THRESHOLD = 2.5
TEMPORAL_RADIUS = 3


def reset_work_dir():
    if WORK_DIR.exists():
        shutil.rmtree(WORK_DIR)
    for name in (
        'frames', 'pair_masks_prev', 'pair_masks_curr',
        'preliminary_masks', 'final_masks'
    ):
        (WORK_DIR / name).mkdir(parents=True, exist_ok=True)


def sample_video(video_path: Path, target_fps: float):
    cap = cv2.VideoCapture(str(video_path))
    if not cap.isOpened():
        raise RuntimeError(f'Cannot open video: {video_path}')

    source_fps = float(cap.get(cv2.CAP_PROP_FPS))
    if not np.isfinite(source_fps) or source_fps <= 0:
        source_fps = 30.0

    sampled = []
    frame_index = 0
    next_sample_time = 0.0

    while True:
        ok, frame = cap.read()
        if not ok:
            break
        timestamp = frame_index / source_fps
        if timestamp + 1e-9 >= next_sample_time:
            out_path = WORK_DIR / 'frames' / f'{len(sampled):06d}.png'
            if not cv2.imwrite(str(out_path), frame):
                raise RuntimeError(f'Failed to write sampled frame: {out_path}')
            sampled.append(out_path)
            next_sample_time += 1.0 / target_fps
        frame_index += 1

    cap.release()
    return sampled


def load_gray(path: Path):
    image = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
    if image is None:
        raise RuntimeError(f'Cannot read frame: {path}')
    return image


def robust_threshold(values, valid, floor, sigma):
    samples = values[valid]
    samples = samples[np.isfinite(samples)]
    if samples.size < 128:
        return float(floor)
    median = float(np.median(samples))
    mad = float(np.median(np.abs(samples - median)))
    robust_sigma = 1.4826 * mad
    return max(float(floor), median + sigma * robust_sigma)


def histogram_correlation(prev, curr):
    h1 = cv2.calcHist([prev], [0], None, [64], [0, 256])
    h2 = cv2.calcHist([curr], [0], None, [64], [0, 256])
    cv2.normalize(h1, h1)
    cv2.normalize(h2, h2)
    return float(cv2.compareHist(h1, h2, cv2.HISTCMP_CORREL))


def detect_grid_features(gray, grid_rows=6, grid_cols=8):
    """Detect spatially balanced corners so one moving object cannot dominate."""
    height, width = gray.shape
    per_cell = max(8, int(math.ceil(KLT_MAX_CORNERS / (grid_rows * grid_cols))))
    collected = []
    for gy in range(grid_rows):
        y0 = int(round(gy * height / grid_rows))
        y1 = int(round((gy + 1) * height / grid_rows))
        for gx in range(grid_cols):
            x0 = int(round(gx * width / grid_cols))
            x1 = int(round((gx + 1) * width / grid_cols))
            roi = gray[y0:y1, x0:x1]
            if roi.size == 0:
                continue
            local = cv2.goodFeaturesToTrack(
                roi,
                maxCorners=per_cell,
                qualityLevel=0.008,
                minDistance=6,
                blockSize=7,
                useHarrisDetector=False,
            )
            if local is None:
                continue
            local = local.reshape(-1, 2)
            local[:, 0] += x0
            local[:, 1] += y0
            collected.append(local)
    if not collected:
        return None
    points = np.concatenate(collected, axis=0)
    if len(points) > KLT_MAX_CORNERS:
        points = points[:KLT_MAX_CORNERS]
    return points.reshape(-1, 1, 2).astype(np.float32)


def estimate_klt_affine(prev, curr):
    points0 = detect_grid_features(prev)
    if points0 is None or len(points0) < MIN_TRACKS:
        return None, 0, 0

    lk_params = dict(
        winSize=(21, 21),
        maxLevel=4,
        criteria=(cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 40, 0.01),
    )
    points1, status1, _ = cv2.calcOpticalFlowPyrLK(prev, curr, points0, None, **lk_params)
    if points1 is None:
        return None, 0, 0
    points0_back, status2, _ = cv2.calcOpticalFlowPyrLK(curr, prev, points1, None, **lk_params)
    if points0_back is None:
        return None, 0, 0

    fb_error = np.linalg.norm(points0_back - points0, axis=2).reshape(-1)
    valid = (
        status1.reshape(-1).astype(bool)
        & status2.reshape(-1).astype(bool)
        & np.isfinite(fb_error)
        & (fb_error < KLT_FB_THRESHOLD)
    )
    p0 = points0.reshape(-1, 2)[valid]
    p1 = points1.reshape(-1, 2)[valid]
    if len(p0) < MIN_TRACKS:
        return None, int(len(p0)), 0

    affine, inliers = cv2.estimateAffinePartial2D(
        p0,
        p1,
        method=cv2.RANSAC,
        ransacReprojThreshold=RANSAC_THRESHOLD,
        maxIters=5000,
        confidence=0.995,
        refineIters=20,
    )
    inlier_count = int(inliers.sum()) if inliers is not None else 0
    return affine, int(len(p0)), inlier_count


def phase_translation(prev, curr):
    shift, response = cv2.phaseCorrelate(prev.astype(np.float32), curr.astype(np.float32))
    dx, dy = shift
    affine = np.array([[1.0, 0.0, dx], [0.0, 1.0, dy]], dtype=np.float32)
    return affine, float(response)


def refine_affine_ecc(prev, curr, initial):
    template = cv2.GaussianBlur(prev, (5, 5), 0).astype(np.float32) / 255.0
    moving = cv2.GaussianBlur(curr, (5, 5), 0).astype(np.float32) / 255.0
    warp = initial.astype(np.float32).copy()
    criteria = (cv2.TERM_CRITERIA_EPS | cv2.TERM_CRITERIA_COUNT, 80, 1e-5)
    try:
        try:
            score, refined = cv2.findTransformECC(
                template, moving, warp, cv2.MOTION_AFFINE, criteria, None, 5
            )
        except TypeError:
            score, refined = cv2.findTransformECC(
                template, moving, warp, cv2.MOTION_AFFINE, criteria
            )
        if np.all(np.isfinite(refined)) and np.isfinite(score):
            return refined.astype(np.float32), float(score)
    except cv2.error:
        pass
    return initial.astype(np.float32), None


def project_affine_to_similarity(affine, height, width):
    """Remove ECC shear/aniso-scale while preserving the mapped image centre."""
    affine = np.asarray(affine, dtype=np.float64)
    linear = affine[:, :2]
    try:
        u, singular_values, vt = np.linalg.svd(linear)
        rotation = u @ vt
        if np.linalg.det(rotation) < 0:
            u[:, -1] *= -1
            rotation = u @ vt
        scale = float(np.median(singular_values))
        similarity_linear = scale * rotation
        center = np.array([width / 2.0, height / 2.0], dtype=np.float64)
        mapped_center = linear @ center + affine[:, 2]
        translation = mapped_center - similarity_linear @ center
        result = np.column_stack((similarity_linear, translation))
        if np.all(np.isfinite(result)):
            return result.astype(np.float32)
    except np.linalg.LinAlgError:
        pass
    return affine.astype(np.float32)


def affine_to_homogeneous(affine):
    matrix = np.eye(3, dtype=np.float64)
    matrix[:2, :] = affine
    return matrix


def safe_inverse_affine(affine):
    matrix = affine_to_homogeneous(affine)
    try:
        inverse = np.linalg.inv(matrix)
    except np.linalg.LinAlgError:
        inverse = np.eye(3, dtype=np.float64)
    return inverse[:2].astype(np.float32)


def estimate_pair_motion(prev, curr):
    mean_absdiff = float(cv2.absdiff(prev, curr).mean())
    hist_corr = histogram_correlation(prev, curr)

    affine, track_count, inlier_count = estimate_klt_affine(prev, curr)
    phase_response = None
    if affine is None:
        affine, phase_response = phase_translation(prev, curr)

    inlier_ratio = inlier_count / max(track_count, 1)
    probable_cut = (
        hist_corr < 0.10
        and mean_absdiff > 35.0
        and (track_count < MIN_TRACKS or inlier_ratio < 0.15)
    )

    ecc_score = None
    if not probable_cut:
        affine, ecc_score = refine_affine_ecc(prev, curr, affine)
        affine = project_affine_to_similarity(affine, prev.shape[0], prev.shape[1])
    else:
        affine = np.array([[1.0, 0.0, 0.0], [0.0, 1.0, 0.0]], dtype=np.float32)

    metrics = {
        'track_count': track_count,
        'inlier_count': inlier_count,
        'inlier_ratio': inlier_ratio,
        'histogram_correlation': hist_corr,
        'mean_absolute_difference': mean_absdiff,
        'phase_response': phase_response,
        'ecc_score': ecc_score,
        'scene_cut': bool(probable_cut),
    }
    return affine, metrics


def create_dense_flow(prev, curr):
    if hasattr(cv2, 'DISOpticalFlow_create'):
        dis = cv2.DISOpticalFlow_create(cv2.DISOPTICAL_FLOW_PRESET_MEDIUM)
        try:
            dis.setUseSpatialPropagation(True)
        except AttributeError:
            pass
        flow = dis.calc(prev, curr, None)
    else:
        flow = cv2.calcOpticalFlowFarneback(
            prev, curr, None,
            pyr_scale=0.5, levels=5, winsize=21,
            iterations=5, poly_n=7, poly_sigma=1.5, flags=0,
        )
    return np.nan_to_num(flow.astype(np.float32), nan=0.0, posinf=0.0, neginf=0.0)


def expected_affine_flow(affine, height, width):
    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    expected_x = affine[0, 0] * xx + affine[0, 1] * yy + affine[0, 2] - xx
    expected_y = affine[1, 0] * xx + affine[1, 1] * yy + affine[1, 2] - yy
    return np.dstack((expected_x, expected_y)).astype(np.float32)


def forward_backward_valid(flow_ab, flow_ba):
    height, width = flow_ab.shape[:2]
    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    map_x = xx + flow_ab[:, :, 0]
    map_y = yy + flow_ab[:, :, 1]
    sampled_back = cv2.remap(
        flow_ba, map_x, map_y, cv2.INTER_LINEAR,
        borderMode=cv2.BORDER_CONSTANT, borderValue=0,
    )
    consistency = np.linalg.norm(flow_ab + sampled_back, axis=2)
    magnitude = np.linalg.norm(flow_ab, axis=2)
    inside = (map_x >= 1) & (map_x < width - 2) & (map_y >= 1) & (map_y < height - 2)
    limit = 0.75 + 0.05 * magnitude
    return inside & (consistency < limit), consistency


def clean_binary_mask(mask, min_area, fill_components=True):
    """Denoise motion seeds while retaining small moving objects and filling interiors."""
    mask_u8 = mask.astype(np.uint8) * 255
    mask_u8 = cv2.morphologyEx(mask_u8, cv2.MORPH_CLOSE, np.ones((9, 9), np.uint8))
    mask_u8 = cv2.morphologyEx(mask_u8, cv2.MORPH_OPEN, np.ones((3, 3), np.uint8))

    count, labels, stats, _ = cv2.connectedComponentsWithStats(mask_u8, connectivity=8)
    output = np.zeros(mask.shape, dtype=np.uint8)
    for label in range(1, count):
        area = int(stats[label, cv2.CC_STAT_AREA])
        if area < min_area:
            continue
        component = (labels == label).astype(np.uint8) * 255
        if fill_components:
            contours, _ = cv2.findContours(component, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
            if contours:
                cv2.drawContours(output, contours, -1, 255, thickness=cv2.FILLED)
            else:
                output[labels == label] = 255
        else:
            output[labels == label] = 255
    return output.astype(bool)


def refine_mask_with_grabcut(frame_bgr, seed_mask):
    """Expand sparse motion seeds to object interiors using local GrabCut models."""
    height, width = seed_mask.shape
    seed_u8 = seed_mask.astype(np.uint8)
    count, labels, stats, _ = cv2.connectedComponentsWithStats(seed_u8, connectivity=8)
    refined = np.zeros_like(seed_mask, dtype=bool)
    component_ids = list(range(1, count))
    component_ids.sort(key=lambda label: int(stats[label, cv2.CC_STAT_AREA]), reverse=True)
    component_ids = component_ids[:8]

    for label in component_ids:
        x = int(stats[label, cv2.CC_STAT_LEFT])
        y = int(stats[label, cv2.CC_STAT_TOP])
        w = int(stats[label, cv2.CC_STAT_WIDTH])
        h = int(stats[label, cv2.CC_STAT_HEIGHT])
        area = int(stats[label, cv2.CC_STAT_AREA])
        if area < max(8, int(height * width * 0.00003)):
            continue
        if area > int(height * width * 0.18) or (w * h) > int(height * width * 0.35):
            refined[labels == label] = True
            continue

        pad_x = max(6, int(round(w * 0.35)))
        pad_y = max(6, int(round(h * 0.35)))
        x0, y0 = max(0, x - pad_x), max(0, y - pad_y)
        x1, y1 = min(width, x + w + pad_x), min(height, y + h + pad_y)
        if x1 - x0 < 5 or y1 - y0 < 5:
            refined[labels == label] = True
            continue

        crop = frame_bgr[y0:y1, x0:x1]
        local_seed = labels[y0:y1, x0:x1] == label
        gc_mask = np.full(local_seed.shape, cv2.GC_PR_BGD, dtype=np.uint8)
        gc_mask[local_seed] = cv2.GC_FGD

        gc_mask[0, :] = cv2.GC_BGD
        gc_mask[-1, :] = cv2.GC_BGD
        gc_mask[:, 0] = cv2.GC_BGD
        gc_mask[:, -1] = cv2.GC_BGD
        probable_fg = cv2.dilate(local_seed.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
        gc_mask[probable_fg & ~local_seed] = cv2.GC_PR_FGD

        bg_model = np.zeros((1, 65), dtype=np.float64)
        fg_model = np.zeros((1, 65), dtype=np.float64)
        try:
            cv2.grabCut(crop, gc_mask, None, bg_model, fg_model, 2, cv2.GC_INIT_WITH_MASK)
            local_result = (gc_mask == cv2.GC_FGD) | (gc_mask == cv2.GC_PR_FGD)
            overlap = np.logical_and(local_result, local_seed).sum()
            if overlap >= max(1, int(0.55 * local_seed.sum())) and local_result.mean() < 0.75:
                refined[y0:y1, x0:x1] |= local_result
            else:
                refined[labels == label] = True
        except cv2.error:
            refined[labels == label] = True

    return clean_binary_mask(
        refined | seed_mask,
        max(16, int(round(height * width * 0.00010))),
        fill_components=True,
    )


def directional_motion_mask(reference, moving, flow_ref_to_mov, flow_mov_to_ref, affine_ref_to_mov):
    height, width = reference.shape
    expected = expected_affine_flow(affine_ref_to_mov, height, width)
    residual = np.linalg.norm(flow_ref_to_mov - expected, axis=2)
    valid_flow, fb_consistency = forward_backward_valid(flow_ref_to_mov, flow_mov_to_ref)

    moving_aligned = cv2.warpAffine(
        moving,
        affine_ref_to_mov,
        (width, height),
        flags=cv2.INTER_LINEAR | cv2.WARP_INVERSE_MAP,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    )
    moving_valid = cv2.warpAffine(
        np.ones((height, width), dtype=np.uint8),
        affine_ref_to_mov,
        (width, height),
        flags=cv2.INTER_NEAREST | cv2.WARP_INVERSE_MAP,
        borderMode=cv2.BORDER_CONSTANT,
        borderValue=0,
    ).astype(bool)

    photo = cv2.absdiff(reference, moving_aligned).astype(np.float32)
    inner = np.zeros((height, width), dtype=bool)
    margin = max(8, int(round(min(height, width) * 0.01)))
    if height > 2 * margin and width > 2 * margin:
        inner[margin:height - margin, margin:width - margin] = True
    else:
        inner[:, :] = True

    valid = valid_flow & moving_valid & inner
    residual_threshold = robust_threshold(residual, valid, floor=0.55, sigma=2.3)
    photo_threshold = robust_threshold(photo, valid, floor=9.0, sigma=2.1)

    strong_flow = residual > residual_threshold
    weak_flow = residual > max(0.35, 0.65 * residual_threshold)
    photo_change = photo > photo_threshold
    inconsistent = fb_consistency > (0.55 + 0.03 * np.linalg.norm(flow_ref_to_mov, axis=2))
    candidate = valid & (strong_flow | (weak_flow & photo_change))

    valid_values = residual[valid]
    if valid_values.size and candidate.mean() < 0.00008:
        q = float(np.percentile(valid_values, 95.0))
        candidate |= valid & (residual >= max(0.45, q)) & photo_change

    min_area = max(12, int(round(height * width * 0.00006)))
    cleaned = clean_binary_mask(candidate, min_area, fill_components=True)
    diagnostics = {
        'residual_threshold': residual_threshold,
        'photo_threshold': photo_threshold,
        'dynamic_ratio': float(cleaned.mean()),
        'mean_fb_consistency': float(fb_consistency[valid_flow].mean()) if valid_flow.any() else None,
    }
    return cleaned, residual, photo, diagnostics


def decompose_motion(affine, height, width):
    linear = affine[:, :2].astype(np.float64)
    try:
        u, singular_values, vt = np.linalg.svd(linear)
        rotation = u @ vt
        if np.linalg.det(rotation) < 0:
            u[:, -1] *= -1
            rotation = u @ vt
        scale = float(np.mean(singular_values))
        angle_deg = math.degrees(math.atan2(rotation[1, 0], rotation[0, 0]))
    except np.linalg.LinAlgError:
        scale = 1.0
        angle_deg = 0.0

    center = np.array([width / 2.0, height / 2.0, 1.0], dtype=np.float64)
    mapped = affine.astype(np.float64) @ center
    dx = float(mapped[0] - center[0])
    dy = float(mapped[1] - center[1])
    return {'dx': dx, 'dy': dy, 'scale': scale, 'angle_deg': angle_deg}


def median_smooth_motion(parameters, scene_cuts, radius=2):
    smoothed = []
    n = len(parameters)
    segment_id = [0] * n
    sid = 0
    for i in range(n):
        if i > 0 and scene_cuts[i - 1]:
            sid += 1
        segment_id[i] = sid

    for i in range(n):
        indices = [
            j for j in range(max(0, i - radius), min(n, i + radius + 1))
            if segment_id[j] == segment_id[i] and not scene_cuts[j]
        ]
        if not indices:
            smoothed.append(parameters[i].copy())
            continue
        smoothed.append({
            key: float(np.median([parameters[j][key] for j in indices]))
            for key in ('dx', 'dy', 'scale', 'angle_deg')
        })
    return smoothed


def classify_motion(params, scene_cut, height, width):
    if scene_cut:
        return ['Stay']

    diagonal = math.hypot(height, width)
    translation_threshold = max(0.8, 0.0015 * diagonal)
    vertical_threshold = max(0.8, 0.0015 * diagonal)
    scale_threshold = 0.006
    roll_threshold = 0.35

    labels = []
    if params['scale'] > 1.0 + scale_threshold:
        labels.append('Dolly In')
    elif params['scale'] < 1.0 - scale_threshold:
        labels.append('Dolly Out')

    if params['dx'] < -translation_threshold:
        labels.append('Pan Right')
    elif params['dx'] > translation_threshold:
        labels.append('Pan Left')

    if params['dy'] > vertical_threshold:
        labels.append('Tilt Up')
    elif params['dy'] < -vertical_threshold:
        labels.append('Tilt Down')

    if params['angle_deg'] < -roll_threshold:
        labels.append('Roll Right')
    elif params['angle_deg'] > roll_threshold:
        labels.append('Roll Left')

    return labels if labels else ['Stay']


def _segment_ids_for_transitions(scene_cuts, count):
    segment_ids = np.zeros(count, dtype=np.int32)
    sid = 0
    for i in range(1, count):
        if scene_cuts[i - 1]:
            sid += 1
        segment_ids[i] = sid
    return segment_ids


def _median_filter_segmented(values, scene_cuts, radius=1):
    """Small robust filter that never crosses a detected scene cut."""
    values = np.asarray(values, dtype=np.float64)
    output = values.copy()
    n = len(values)
    segment_ids = _segment_ids_for_transitions(scene_cuts, n)
    for i in range(n):
        idx = [
            j for j in range(max(0, i - radius), min(n, i + radius + 1))
            if segment_ids[j] == segment_ids[i] and not scene_cuts[j]
        ]
        if idx:
            output[i] = float(np.median(values[idx]))
    return output


def _iter_true_runs(active):
    active = np.asarray(active, dtype=bool)
    i = 0
    while i < len(active):
        if not active[i]:
            i += 1
            continue
        j = i + 1
        while j < len(active) and active[j]:
            j += 1
        yield i, j
        i = j


def _cleanup_activity(active, scene_cuts, max_gap=1, min_run=2):
    """Fill one-transition holes and reject short bursts within each shot."""
    active = np.asarray(active, dtype=bool).copy()
    n = len(active)
    segment_ids = _segment_ids_for_transitions(scene_cuts, n)

    i = 0
    while i < n:
        if active[i]:
            i += 1
            continue
        j = i
        while j < n and not active[j] and segment_ids[j] == segment_ids[i]:
            j += 1
        enclosed = (
            i > 0 and j < n and segment_ids[i - 1] == segment_ids[i]
            and segment_ids[j] == segment_ids[i]
            and active[i - 1] and active[j]
        )
        if enclosed and (j - i) <= max_gap:
            active[i:j] = True
        i = max(j, i + 1)

    for start, end in list(_iter_true_runs(active)):
        if end - start < min_run:
            active[start:end] = False

    for i, cut in enumerate(scene_cuts):
        if cut:
            active[i] = False
    return active


def _adaptive_signed_activity(signal, scene_cuts, absolute_floor):
    """
    Detect sustained signed motion using a robust noise model and hysteresis.

    The lower part of the magnitude distribution models estimator jitter.  The
    upper state threshold is derived from that noise level and from the observed
    signal range, while the lower threshold prevents rapid on/off flicker.
    """
    smooth = _median_filter_segmented(signal, scene_cuts, radius=1)
    magnitude = np.abs(smooth)
    finite = magnitude[np.isfinite(magnitude)]
    if finite.size == 0:
        return smooth, np.zeros(len(smooth), dtype=bool), {
            'on': float(absolute_floor), 'off': float(absolute_floor),
            'noise': 0.0, 'peak': 0.0,
        }

    ordered = np.sort(finite)
    baseline = np.empty(0, dtype=np.float64)
    if ordered.size >= 6:
        safe = np.maximum(ordered, max(1e-12, absolute_floor * 1e-4))
        log_gaps = np.diff(np.log(safe))
        lo = 1
        hi = ordered.size - 2
        if hi > lo:
            local = log_gaps[lo:hi]
            split = lo + int(np.argmax(local))
            if log_gaps[split] >= math.log(2.2):
                baseline = ordered[:split + 1]
    if baseline.size == 0:
        q25 = float(np.percentile(finite, 25.0))
        baseline = finite[finite <= q25 + 1e-12]

    noise_center = float(np.median(baseline)) if baseline.size else 0.0
    noise_mad = float(np.median(np.abs(baseline - noise_center))) if baseline.size else 0.0
    noise_sigma = 1.4826 * noise_mad
    peak = float(np.percentile(finite, 90.0))

    threshold_on = max(
        float(absolute_floor),
        noise_center + 4.0 * noise_sigma,
        0.22 * peak,
    )
    if peak < 1.30 * absolute_floor:
        return smooth, np.zeros(len(smooth), dtype=bool), {
            'on': float(threshold_on), 'off': float(0.75 * threshold_on),
            'noise': float(noise_center + noise_sigma), 'peak': peak,
        }

    threshold_off = max(0.72 * threshold_on, 0.85 * absolute_floor)
    active = np.zeros(len(smooth), dtype=bool)
    segment_ids = _segment_ids_for_transitions(scene_cuts, len(smooth))
    state = False
    previous_segment = segment_ids[0] if len(smooth) else 0
    for i, value in enumerate(magnitude):
        if segment_ids[i] != previous_segment or scene_cuts[i]:
            state = False
            previous_segment = segment_ids[i]
        if state:
            state = value >= threshold_off
        else:
            state = value >= threshold_on
        active[i] = state and not scene_cuts[i]

    active = _cleanup_activity(active, scene_cuts, max_gap=1, min_run=2)

    for start, end in list(_iter_true_runs(active)):
        run = smooth[start:end]
        direction = float(np.median(run))
        if abs(direction) < threshold_off:
            active[start:end] = False
            continue
        disagree = np.sign(run) != np.sign(direction)
        if disagree.mean() > 0.25:
            active[start:end] = False

    return smooth, active, {
        'on': float(threshold_on),
        'off': float(threshold_off),
        'noise': float(noise_center + noise_sigma),
        'peak': peak,
    }


def _anticipate_secondary_onsets(activity, signals, thresholds, scene_cuts):
    """
    Correct the one-transition latency of pairwise finite differences.

    A transform for frame i->i+1 measures motion integrated over that interval.
    When a second camera degree of freedom starts while another one is already
    active, its first full-strength estimate can appear one interval late.  We
    move such an onset back by one transition only when there is a large,
    sustained step and another independently detected action was already active.
    No frame number, video length, or expected label sequence is used.
    """
    corrected = {name: np.asarray(values, dtype=bool).copy()
                 for name, values in activity.items()}
    corrected_signals = {
        name: np.asarray(values, dtype=np.float64).copy()
        for name, values in signals.items()
    }
    names = list(corrected)

    for name in names:
        active = corrected[name]
        signal = corrected_signals[name]
        threshold = float(thresholds[name]['on'])
        for start, end in list(_iter_true_runs(active)):
            if start <= 0 or scene_cuts[start - 1]:
                continue
            other_motion_before = any(
                corrected[other][start - 1] for other in names if other != name
            )
            if not other_motion_before:
                continue

            head_end = min(end, start + 3)
            level = float(np.median(np.abs(signal[start:head_end])))
            previous = float(abs(signal[start - 1]))
            jump = float(abs(signal[start] - signal[start - 1]))
            sustained = end - start >= 2 and level >= 1.20 * threshold
            sharp_step = jump >= max(1.50 * threshold, 0.55 * level)
            weak_predecessor = previous <= max(0.80 * threshold, 0.45 * level)
            if sustained and sharp_step and weak_predecessor:
                active[start - 1] = True
                run_direction = float(np.median(signal[start:head_end]))
                signal[start - 1] = run_direction

        corrected[name] = _cleanup_activity(
            active, scene_cuts, max_gap=1, min_run=2
        )
        corrected_signals[name] = signal
    return corrected, corrected_signals


def infer_transition_labels(parameters, scene_cuts, height, width):
    """Infer camera actions only from the measured video transforms."""
    if not parameters:
        return [], {}

    raw_signals = {
        'zoom': np.asarray([
            math.log(max(1e-6, p['scale'])) for p in parameters
        ], dtype=np.float64),
        'pan': np.asarray([
            -p['dx'] / max(width, 1) for p in parameters
        ], dtype=np.float64),
        'tilt': np.asarray([
            p['dy'] / max(height, 1) for p in parameters
        ], dtype=np.float64),
        'roll': np.asarray([
            -p['angle_deg'] for p in parameters
        ], dtype=np.float64),
    }

    floors = {
        'zoom': math.log(1.0035),
        'pan': 0.00125,
        'tilt': 0.00175,
        'roll': 0.35,
    }

    smoothed = {}
    activity = {}
    thresholds = {}
    for name in ('zoom', 'pan', 'tilt', 'roll'):
        smoothed[name], activity[name], thresholds[name] = _adaptive_signed_activity(
            raw_signals[name], scene_cuts, floors[name]
        )

    activity, smoothed = _anticipate_secondary_onsets(
        activity, smoothed, thresholds, scene_cuts
    )

    labels = []
    for i in range(len(parameters)):
        current = []
        if activity['zoom'][i]:
            current.append('Dolly In' if smoothed['zoom'][i] > 0 else 'Dolly Out')
        if activity['pan'][i]:
            current.append('Pan Right' if smoothed['pan'][i] > 0 else 'Pan Left')
        if activity['tilt'][i]:
            current.append('Tilt Up' if smoothed['tilt'][i] > 0 else 'Tilt Down')
        if activity['roll'][i]:
            current.append('Roll Right' if smoothed['roll'][i] > 0 else 'Roll Left')
        labels.append(current if current else ['Stay'])

    diagnostics = {
        'signals': {name: smoothed[name].tolist() for name in smoothed},
        'thresholds': thresholds,
        'activity': {
            name: activity[name].astype(np.uint8).tolist() for name in activity
        },
        'method': (
            'robust per-axis hysteresis with sustained-run sign validation and '
            'finite-difference latency correction for newly added motion axes'
        ),
    }
    return labels, diagnostics

def merge_transition_labels(labels):
    if not labels:
        return {}
    output = {}
    start = 0
    previous = tuple(labels[0])
    for transition_index in range(1, len(labels)):
        current = tuple(labels[transition_index])
        if current != previous:
            output[f'{start}->{transition_index}'] = list(previous)
            start = transition_index
            previous = current
    output[f'{start}->{len(labels)}'] = list(previous)
    return output


def build_segment_ids(scene_cuts, frame_count):
    segment_ids = [0] * frame_count
    current = 0
    for frame_index in range(1, frame_count):
        if scene_cuts[frame_index - 1]:
            current += 1
        segment_ids[frame_index] = current
    return segment_ids


def accumulate_transforms(affines, scene_cuts, frame_count):
    globals_ = [np.eye(3, dtype=np.float64)]
    for i in range(frame_count - 1):
        if scene_cuts[i]:
            globals_.append(np.eye(3, dtype=np.float64))
        else:
            globals_.append(affine_to_homogeneous(affines[i]) @ globals_[-1])
    return globals_


def create_local_background(frame_paths, globals_, segment_ids, target_index, height, width):
    neighbors = [
        j for j in range(max(0, target_index - TEMPORAL_RADIUS),
                         min(len(frame_paths), target_index + TEMPORAL_RADIUS + 1))
        if j != target_index and segment_ids[j] == segment_ids[target_index]
    ]
    if len(neighbors) < 2:
        return None, None

    target_global = globals_[target_index]
    aligned_stack = []
    valid_stack = []
    for neighbor in neighbors:
        neighbor_gray = load_gray(frame_paths[neighbor])
        try:
            neighbor_to_target = target_global @ np.linalg.inv(globals_[neighbor])
        except np.linalg.LinAlgError:
            continue
        affine = neighbor_to_target[:2].astype(np.float32)
        aligned = cv2.warpAffine(
            neighbor_gray, affine, (width, height),
            flags=cv2.INTER_LINEAR, borderMode=cv2.BORDER_CONSTANT, borderValue=0,
        )
        valid = cv2.warpAffine(
            np.ones((height, width), dtype=np.uint8), affine, (width, height),
            flags=cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=0,
        ).astype(bool)
        aligned_stack.append(aligned.astype(np.float32))
        valid_stack.append(valid)

    if len(aligned_stack) < 2:
        return None, None

    stack = np.stack(aligned_stack, axis=0)
    valid = np.stack(valid_stack, axis=0)
    stack[~valid] = np.nan
    with warnings.catch_warnings():
        warnings.simplefilter('ignore', category=RuntimeWarning)
        with np.errstate(invalid='ignore'):
            background = np.nanmedian(stack, axis=0)
    support = valid.sum(axis=0) >= 2
    background = np.nan_to_num(background, nan=0.0).astype(np.uint8)
    return background, support


def save_csr_masks(mask_paths, shape, output_path):
    height, width = shape
    arrays = {'shape': np.asarray([height, width], dtype=np.int32)}
    for i, path in enumerate(mask_paths):
        mask = cv2.imread(str(path), cv2.IMREAD_GRAYSCALE)
        if mask is None:
            raise RuntimeError(f'Cannot read final mask: {path}')
        mask_bool = mask > 0
        row_counts = mask_bool.sum(axis=1, dtype=np.int64)
        indptr = np.empty(height + 1, dtype=np.int64)
        indptr[0] = 0
        np.cumsum(row_counts, out=indptr[1:])
        indices = np.nonzero(mask_bool)[1].astype(np.int32, copy=False)
        data = np.ones(indices.size, dtype=bool)
        arrays[f'f_{i}_data'] = data
        arrays[f'f_{i}_indices'] = indices
        arrays[f'f_{i}_indptr'] = indptr
    np.savez_compressed(output_path, **arrays)


def main():
    if not INPUT_VIDEO.exists():
        raise FileNotFoundError(INPUT_VIDEO)

    reset_work_dir()
    frame_paths = sample_video(INPUT_VIDEO, TARGET_FPS)
    if not frame_paths:
        raise RuntimeError('No frames were decoded from the input video')

    first_gray = load_gray(frame_paths[0])
    height, width = first_gray.shape
    frame_count = len(frame_paths)

    if frame_count == 1:
        zero_path = WORK_DIR / 'final_masks' / '000000.png'
        cv2.imwrite(str(zero_path), np.zeros((height, width), dtype=np.uint8))
        with open(OUTPUT_JSON, 'w', encoding='utf-8') as f:
            json.dump({}, f, indent=2)
        save_csr_masks([zero_path], (height, width), OUTPUT_MASKS)
        shutil.rmtree(WORK_DIR, ignore_errors=True)
        return

    affines = []
    scene_cuts = []
    motion_parameters = []

    for i in range(frame_count - 1):
        prev = load_gray(frame_paths[i])
        curr = load_gray(frame_paths[i + 1])
        affine, metrics = estimate_pair_motion(prev, curr)
        affines.append(affine)
        scene_cuts.append(metrics['scene_cut'])
        motion_parameters.append(decompose_motion(affine, height, width))

        if metrics['scene_cut']:
            mask_prev = np.zeros((height, width), dtype=bool)
            mask_curr = np.zeros((height, width), dtype=bool)
        else:
            flow_forward = create_dense_flow(prev, curr)
            flow_backward = create_dense_flow(curr, prev)
            mask_prev, _, _, _ = directional_motion_mask(
                prev, curr, flow_forward, flow_backward, affine
            )
            inverse_affine = safe_inverse_affine(affine)
            mask_curr, _, _, _ = directional_motion_mask(
                curr, prev, flow_backward, flow_forward, inverse_affine
            )

        cv2.imwrite(
            str(WORK_DIR / 'pair_masks_prev' / f'{i:06d}.png'),
            mask_prev.astype(np.uint8) * 255,
        )
        cv2.imwrite(
            str(WORK_DIR / 'pair_masks_curr' / f'{i:06d}.png'),
            mask_curr.astype(np.uint8) * 255,
        )
    smoothed_parameters = median_smooth_motion(motion_parameters, scene_cuts, radius=1)
    transition_labels, _ = infer_transition_labels(
        smoothed_parameters, scene_cuts, height, width
    )
    instructions = merge_transition_labels(transition_labels)
    with open(OUTPUT_JSON, 'w', encoding='utf-8') as f:
        json.dump(instructions, f, indent=2)

    segment_ids = build_segment_ids(scene_cuts, frame_count)
    globals_ = accumulate_transforms(affines, scene_cuts, frame_count)

    preliminary_paths = []
    for i in range(frame_count):
        frame = load_gray(frame_paths[i])
        background, support = create_local_background(
            frame_paths, globals_, segment_ids, i, height, width
        )
        if background is None:
            appearance_mask = np.zeros((height, width), dtype=bool)
        else:
            difference = cv2.absdiff(frame, background).astype(np.float32)
            appearance_threshold = robust_threshold(
                difference, support, floor=9.0, sigma=2.0
            )
            appearance_mask = support & (difference > appearance_threshold)
            appearance_mask = clean_binary_mask(
                appearance_mask,
                max(12, int(round(height * width * 0.00006))),
                fill_components=True,
            )
        incoming = None
        outgoing = None
        if i > 0 and not scene_cuts[i - 1]:
            incoming = cv2.imread(
                str(WORK_DIR / 'pair_masks_curr' / f'{i - 1:06d}.png'),
                cv2.IMREAD_GRAYSCALE,
            ) > 0
        if i < frame_count - 1 and not scene_cuts[i]:
            outgoing = cv2.imread(
                str(WORK_DIR / 'pair_masks_prev' / f'{i:06d}.png'),
                cv2.IMREAD_GRAYSCALE,
            ) > 0

        appearance_dilated = cv2.dilate(
            appearance_mask.astype(np.uint8), np.ones((9, 9), np.uint8)
        ).astype(bool)

        if incoming is not None and outgoing is not None:
            incoming_d = cv2.dilate(incoming.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
            outgoing_d = cv2.dilate(outgoing.astype(np.uint8), np.ones((7, 7), np.uint8)).astype(bool)
            temporal_agreement = incoming_d & outgoing_d
            motion_union = incoming | outgoing
            motion_dilated = incoming_d | outgoing_d
            preliminary = temporal_agreement | (motion_union & appearance_dilated) | (appearance_mask & motion_dilated)
            if not preliminary.any():
                preliminary = temporal_agreement | (motion_union & cv2.dilate(appearance_mask.astype(np.uint8), np.ones((15, 15), np.uint8)).astype(bool))
        elif incoming is not None:
            incoming_d = cv2.dilate(incoming.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
            preliminary = incoming & appearance_dilated
            preliminary |= appearance_mask & incoming_d
            if not preliminary.any():
                preliminary = incoming
        elif outgoing is not None:
            outgoing_d = cv2.dilate(outgoing.astype(np.uint8), np.ones((9, 9), np.uint8)).astype(bool)
            preliminary = outgoing & appearance_dilated
            preliminary |= appearance_mask & outgoing_d
            if not preliminary.any():
                preliminary = outgoing
        else:
            preliminary = appearance_mask

        preliminary = clean_binary_mask(
            preliminary,
            max(16, int(round(height * width * 0.00010))),
            fill_components=True,
        )
        if os.environ.get('ALT_ENABLE_GRABCUT', '0') == '1':
            color_frame = cv2.imread(str(frame_paths[i]), cv2.IMREAD_COLOR)
            if color_frame is not None and preliminary.any():
                preliminary = refine_mask_with_grabcut(color_frame, preliminary)
        out_path = WORK_DIR / 'preliminary_masks' / f'{i:06d}.png'
        cv2.imwrite(str(out_path), preliminary.astype(np.uint8) * 255)
        preliminary_paths.append(out_path)

    final_paths = []
    for i in range(frame_count):
        current = cv2.imread(str(preliminary_paths[i]), cv2.IMREAD_GRAYSCALE) > 0
        neighbor_votes = []

        if i > 0 and not scene_cuts[i - 1]:
            previous = cv2.imread(str(preliminary_paths[i - 1]), cv2.IMREAD_GRAYSCALE)
            previous = cv2.dilate(previous, np.ones((5, 5), np.uint8))
            previous_to_current = cv2.warpAffine(
                previous, affines[i - 1], (width, height),
                flags=cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=0,
            ) > 0
            neighbor_votes.append(previous_to_current)

        if i < frame_count - 1 and not scene_cuts[i]:
            following = cv2.imread(str(preliminary_paths[i + 1]), cv2.IMREAD_GRAYSCALE)
            following = cv2.dilate(following, np.ones((5, 5), np.uint8))
            next_to_current = cv2.warpAffine(
                following, safe_inverse_affine(affines[i]), (width, height),
                flags=cv2.INTER_NEAREST, borderMode=cv2.BORDER_CONSTANT, borderValue=0,
            ) > 0
            neighbor_votes.append(next_to_current)

        refined = current.copy()
        if len(neighbor_votes) == 2:
            refined |= neighbor_votes[0] & neighbor_votes[1]
        refined = clean_binary_mask(
            refined,
            max(12, int(round(height * width * 0.00006))),
            fill_components=True,
        )
        final_path = WORK_DIR / 'final_masks' / f'{i:06d}.png'
        cv2.imwrite(str(final_path), refined.astype(np.uint8) * 255)
        final_paths.append(final_path)

    save_csr_masks(final_paths, (height, width), OUTPUT_MASKS)

    shutil.rmtree(WORK_DIR, ignore_errors=True)

    print(f'Wrote {OUTPUT_JSON}')
    print(f'Wrote {OUTPUT_MASKS}')


if __name__ == '__main__':
    main()
PYTHON_SCRIPT