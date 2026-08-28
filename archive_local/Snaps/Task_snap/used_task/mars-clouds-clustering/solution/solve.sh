#!/bin/bash
set -euo pipefail

cd /root

cat > /tmp/solve_mars_clouds.py << 'PYTHON_SCRIPT'
#!/usr/bin/env python3

from collections import deque
from itertools import product
from pathlib import Path

import numpy as np
import pandas as pd


def prepare_image_data(citsci_df, expert_df):
    image_data = []
    unique_images = expert_df["file_rad"].unique()

    for img in unique_images:
        citsci_points = citsci_df.loc[citsci_df["file_rad"] == img, ["x", "y"]].to_numpy(dtype=float)
        expert_points = expert_df.loc[expert_df["file_rad"] == img, ["x", "y"]].to_numpy(dtype=float)

        if len(citsci_points) > 0:
            dx = citsci_points[:, 0][:, None] - citsci_points[:, 0][None, :]
            dy = citsci_points[:, 1][:, None] - citsci_points[:, 1][None, :]
        else:
            dx = np.empty((0, 0), dtype=float)
            dy = np.empty((0, 0), dtype=float)

        image_data.append(
            {
                "file_rad": img,
                "citsci_points": citsci_points,
                "expert_points": expert_points,
                "dx": dx,
                "dy": dy,
            }
        )

    return image_data


def build_weight_epsilon_caches(image_data, shape_weights, eps_values):
    for item in image_data:
        points = item["citsci_points"]
        dx = item["dx"]
        dy = item["dy"]
        per_weight = {}

        if len(points) == 0:
            item["cache"] = per_weight
            continue

        for w in shape_weights:
            weighted = np.sqrt((w * dx) ** 2 + ((2.0 - w) * dy) ** 2)
            per_eps = {}

            for eps in eps_values:
                neighbors = weighted <= eps
                neighbor_lists = [np.flatnonzero(neighbors[i]).astype(np.int32) for i in range(len(points))]
                counts = np.array([len(x) for x in neighbor_lists], dtype=np.int32)
                per_eps[int(eps)] = {
                    "neighbor_lists": neighbor_lists,
                    "counts": counts,
                }

            per_weight[float(w)] = per_eps

        item["cache"] = per_weight


def dbscan_manual(neighbor_lists, counts, min_samples):
    n = len(neighbor_lists)
    if n == 0:
        return np.empty((0,), dtype=np.int32)

    UNVISITED = -99
    NOISE = -1
    labels = np.full(n, UNVISITED, dtype=np.int32)
    cluster_id = 0
    in_seed = np.zeros(n, dtype=bool)

    for i in range(n):
        if labels[i] != UNVISITED:
            continue

        if counts[i] < min_samples:
            labels[i] = NOISE
            continue

        labels[i] = cluster_id
        seeds = deque()
        in_seed[:] = False

        for q in neighbor_lists[i]:
            q = int(q)
            if q == i:
                continue
            seeds.append(q)
            in_seed[q] = True

        while seeds:
            j = seeds.popleft()
            in_seed[j] = False

            if labels[j] == NOISE:
                labels[j] = cluster_id

            if labels[j] != UNVISITED:
                continue

            labels[j] = cluster_id

            if counts[j] >= min_samples:
                for q in neighbor_lists[j]:
                    q = int(q)
                    if not in_seed[q]:
                        seeds.append(q)
                        in_seed[q] = True

        cluster_id += 1

    labels[labels == UNVISITED] = NOISE
    return labels


def centroids_from_labels(points, labels):
    unique_labels = sorted(set(labels.tolist()) - {-1})
    if not unique_labels:
        return np.empty((0, 2), dtype=float)

    return np.array(
        [points[labels == lbl].mean(axis=0) for lbl in unique_labels],
        dtype=float,
    )


def greedy_match(centroids, experts, max_distance=100.0):
    if len(centroids) == 0 or len(experts) == 0:
        return 0, len(centroids), len(experts), []

    diff = centroids[:, None, :] - experts[None, :, :]
    dist = np.sqrt((diff ** 2).sum(axis=2))

    pairs = []
    for i in range(dist.shape[0]):
        for j in range(dist.shape[1]):
            pairs.append((float(dist[i, j]), i, j))
    pairs.sort(key=lambda x: x[0])

    used_centroids = set()
    used_experts = set()
    matches = []

    for d, i, j in pairs:
        if d >= max_distance:
            break
        if i in used_centroids or j in used_experts:
            continue
        used_centroids.add(i)
        used_experts.add(j)
        matches.append((i, j, d))

    tp = len(matches)
    fp = len(centroids) - tp
    fn = len(experts) - tp
    return tp, fp, fn, matches


def compute_metrics_for_image(image_item, min_samples, epsilon, shape_weight):
    points = image_item["citsci_points"]
    experts = image_item["expert_points"]

    if len(points) == 0:
        return 0.0, np.nan

    cached = image_item["cache"][float(shape_weight)][int(epsilon)]
    labels = dbscan_manual(cached["neighbor_lists"], cached["counts"], min_samples)
    centroids = centroids_from_labels(points, labels)

    if len(centroids) == 0:
        return 0.0, np.nan

    tp, fp, fn, matches = greedy_match(centroids, experts, max_distance=100.0)

    if tp == 0:
        return 0.0, np.nan

    precision = tp / (tp + fp)
    recall = tp / (tp + fn)
    f1 = 2.0 * precision * recall / (precision + recall)
    delta = float(np.mean([m[2] for m in matches]))
    return f1, delta


def evaluate_one_combo(params, image_data):
    min_samples, epsilon, shape_weight = params

    f1_scores = []
    deltas = []

    for item in image_data:
        f1, delta = compute_metrics_for_image(item, min_samples, epsilon, shape_weight)
        f1_scores.append(f1)
        if not np.isnan(delta):
            deltas.append(delta)

    mean_f1 = float(np.mean(f1_scores)) if f1_scores else 0.0
    mean_delta = float(np.mean(deltas)) if deltas else np.inf

    if mean_f1 > 0.5 and np.isfinite(mean_delta):
        return {
            "F1": mean_f1,
            "delta": mean_delta,
            "min_samples": int(min_samples),
            "epsilon": int(epsilon),
            "shape_weight": round(float(shape_weight), 1),
        }
    return None


def pareto_frontier(df):
    keep = np.ones(len(df), dtype=bool)
    values = df[["F1", "delta"]].to_numpy()

    for i in range(len(values)):
        if not keep[i]:
            continue
        for j in range(len(values)):
            if i == j:
                continue
            dominates = (
                values[j, 0] >= values[i, 0]
                and values[j, 1] <= values[i, 1]
                and (values[j, 0] > values[i, 0] or values[j, 1] < values[i, 1])
            )
            if dominates:
                keep[i] = False
                break

    return df.loc[keep].copy()


def main():
    data_dir = Path("/root/data")
    citsci_df = pd.read_csv(data_dir / "citsci_train.csv")
    expert_df = pd.read_csv(data_dir / "expert_train.csv")

    image_data = prepare_image_data(citsci_df, expert_df)

    min_samples_range = list(range(3, 10))
    epsilon_range = list(range(4, 25, 2))
    shape_weight_range = np.round(np.arange(0.9, 2.0, 0.1), 1)

    build_weight_epsilon_caches(image_data, shape_weight_range, epsilon_range)

    all_params = list(product(min_samples_range, epsilon_range, shape_weight_range))

    results = []
    for params in all_params:
        result = evaluate_one_combo(params, image_data)
        if result is not None:
            results.append(result)

    if not results:
        raise RuntimeError("no valid parameter combinations found")

    df = pd.DataFrame(results)
    frontier = pareto_frontier(df)
    frontier = frontier.sort_values(["F1", "delta"], ascending=[False, True]).reset_index(drop=True)

    frontier["F1"] = frontier["F1"].round(5)
    frontier["delta"] = frontier["delta"].round(5)
    frontier["shape_weight"] = frontier["shape_weight"].round(1)
    frontier["min_samples"] = frontier["min_samples"].astype(int)
    frontier["epsilon"] = frontier["epsilon"].astype(int)

    output_path = Path("/root/pareto_frontier.csv")
    frontier.to_csv(output_path, index=False)


if __name__ == "__main__":
    main()
PYTHON_SCRIPT

python3 /tmp/solve_mars_clouds.py