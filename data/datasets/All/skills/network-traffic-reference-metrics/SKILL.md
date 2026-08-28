---
name: network-traffic-reference-metrics
description: "Compute the reference aggregate network-traffic metrics from normalized packet events, including protocol counts, time buckets, entropy, graph density, inter-arrival statistics, packet-completion ratios, and directional 5-tuple flow statistics with conventions preserved."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Inputs

Read the requested metric names, time-bucket width, packet-completion thresholds, flow definition, rounding/output requirements, and any other Task-specified values from the current task specification. Preserve packet order information `(timestamp, frame_number)` from normalization.

## Procedure

1. Accumulate protocol counts and total bytes exactly from layer-presence events used by the procedure. The reference IP total is incremented for IPv4 events. TCP/UDP protocol counts follow the parsed transport-layer event path used by the procedure; do not infer absent transport fields.
2. Compute averages and capture duration, applying the reference final rounding where requested by the output mapping.
3. Time buckets are indexed from the first packet timestamp using the Task-provided bucket width. Emit only buckets that receive packets; do not synthesize empty buckets.
4. Compute discrete Shannon entropy with `log2` over positive category probabilities and round the reference entropy result to 4 decimals. TCP port statistics use parsed TCP ports; the UDP path contributes only events that have both the expected IP context and UDP fields.
5. Build a directed endpoint graph from unique source/destination edges and compute reference density from the observed node/edge sets, rounded to 6 decimals.
6. Inter-arrival times are based on packets stably ordered by `(timestamp, frame_number)` using merge-sort semantics. Use population variance (`ddof=0`), round mean/variance to 6 decimals and coefficient of variation to 4 decimals.
7. Apply the Task-provided packet-completion-ratio thresholds to the packet-size/count statistics at the specified stage.
8. Build unique **directional** 5-tuples. For each directional key, test whether its reverse key exists. Count reverse matches and report `reverse_matches // 2`; preserve that convention for this metric convention.
9. Determine the dominant protocol using the reference protocol-count comparison and deterministic handling used by the script.

## Checks

Recompute totals from normalized events, assert bucket packet counts sum to the eligible packet count, and verify the IAT array length is one less than its ordered timestamp series when at least two events exist. Keep directional flow keys available until reverse-flow computation is complete.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

