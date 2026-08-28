---
name: network-behavior-reference-heuristics
description: "Derive reference intrusion-behavior flags from aggregate traffic metrics plus per-source behavioral features. Use for port-scan, denial-of-service, beaconing, and benign classification when the heuristic thresholds and precedence must be reproduced exactly."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Required retained features

Do not discard source-level behavior after aggregation. Retain, per source, TCP-attempt counts, destination-port distributions, and SYN-without-ACK counts, together with the aggregate rate/IAT metrics required below.

## Procedure

1. Port-scan evidence is evaluated only for sources with at least **50 TCP attempts**. For each eligible source compute destination-port entropy, SYN-only fraction, and unique destination-port count. The reference condition is: port entropy `> 6`, SYN-only fraction `> 0.7`, and unique ports `> 100`.
2. Denial-of-service evidence uses the reference peak-to-average packets-per-time-bucket ratio and flags when `ppm_max / ppm_avg > 20` (subject to the reference handling of a zero/empty denominator).
3. Beaconing evidence uses the inter-arrival coefficient of variation and flags when `IAT_CV < 0.5` under the reference eligibility conditions.
4. Set the benign flag only when none of the malicious-behavior flags is active. Do not replace these heuristics with a classifier or adjust thresholds based on the current dataset.

## Checks

For every true behavioral flag, retain the intermediate scalar(s) that caused the threshold crossing. Re-evaluate every threshold with the same strict inequality direction used above.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

