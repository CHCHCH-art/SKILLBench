---
name: exact-boundary-distance-selection
description: "Select the earthquake or point event farthest from a target plate boundary after candidate pruning by computing exact projected geometry distances, deterministic source-order ties, and winner verification against the full boundary geometry."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Compute exact projected geometry distance for every candidate retained by the raster stage. Process comparison order using descending reference sample/score and then source ordinal, matching the procedure.
2. Maintain the current winner and eliminate candidates only when their bound/distance is no better than `winner + 1e-6` under the reference branch logic.
3. Select the minimum exact distance with source ordinal as the deterministic tie break. Preserve the winning source feature identity for any Task-requested plate/boundary fields.
4. Independently verify the selected distance against the minimum distance to the union or complete relevant source-feature set; require absolute agreement within **`1e-6`** before final output.
5. Apply Task-provided distance units, rounding precision, field names, and row ordering only during final serialization.

## Checks

No rounded value may participate in winner selection. If union verification fails, treat it as a computation error rather than silently returning the raster-stage candidate.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

