---
name: network-traffic-reference-behavior-flags
description: "Derive benign, port-scan, DoS-spike, and beaconing flags from streaming network metrics plus per-source behavioral features using the reference traffic heuristic."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Required features
Consume both final aggregate metrics and the retained per-source TCP attempt features. Do not discard per-source destination-port sets or SYN-without-ACK counts before this step.

## Reference procedure
1. Port scan: evaluate each source with at least **50** parsed TCP attempts. Flag a scan when destination-port entropy is `> 6.0`, SYN-without-ACK ratio is `> 0.7`, and unique destination ports are `> 100`.
2. DoS pattern: compute `packets_per_minute_max / packets_per_minute_avg`; flag when the average is positive and the ratio is `> 20`.
3. Beaconing: require at least one IAT and flag when the global IAT CV is `< 0.5`.
4. Benign is the logical negation of the three malicious-pattern flags.
5. These numerical values are reference defaults, not Task-provided traffic thresholds.

## Checks

Require per-source TCP attempt counts, per-source destination-port distributions, SYN-without-ACK counts, packet-rate aggregates, and IAT statistics to be present before classification. For every source with TCP attempts, require `0 <= syn_only/attempts <= 1` and finite nonnegative port entropy. DoS ratio is evaluated only when average packet rate is positive; beaconing is false when no IAT exists. Finally require `is_traffic_benign == not(has_port_scan or has_dos_pattern or has_beaconing)`. Missing behavioral features or nonfinite ratios abort classification instead of treating missing data as benign.
