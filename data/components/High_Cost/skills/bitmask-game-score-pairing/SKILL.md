---
name: bitmask-game-score-pairing
description: "Maximize per-game score subject to using each scoring category at most once with deterministic bitmask frontier expansion, then apply the task-specified game-pairing rule and aggregate signed match outcomes."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Assignment procedure

1. Initialize one frontier row per first-turn category with total score equal to that category score and `used_mask = 1 << category`.
2. For each subsequent turn slot, many-to-many merge the current frontier with every category option for the same game. Retain only options whose category bit is absent from `used_mask`, then OR in that bit and add the option score.
3. After all turn slots, for each game take `idxmax` of total score from the frontier. Preserve the reference first-encounter behavior for tied maxima; do not add a new tie breaker.
4. Require exactly one selected score for every sequential game identifier in the rule-derived expected range.
5. Bind `<pairing_rule>` and player-side assignment from the current task specification. Apply that rule to the ordered game scores and require complete one-to-one pairing for every game that the task says participates.
6. For each bound pair, compute the signed score margin in the task-specified player order, apply `sign` to every margin, and aggregate those signs using the task-requested output path/format.

## Checks

Ensure no chosen game assignment repeats a category. A tied match contributes zero under `sign`; do not convert it to a win/loss.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.
