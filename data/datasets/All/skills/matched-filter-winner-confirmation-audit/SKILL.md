---
name: matched-filter-winner-confirmation-audit
description: "Select and independently confirm per-approximant matched-filter winners using SNR/mass tie order, two-stage confirmation, rerun consistency tolerances, and diagnostic export."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Within each approximant/stage, sort candidates by SNR descending, then `mass1` ascending, then `mass2` ascending; the first record is the stage winner.
2. The final reported winner is selected from the **confirmation-stage** records under the same ordering. Discovery-stage best mass/SNR remains diagnostic evidence rather than replacing confirmation.
3. Rerun filtering for every final winner directly from conditioned strain/PSD and require the rerun SNR and peak time to match the stored result within absolute **`1e-9`**.
4. Export the Task-requested result fields from the confirmation winner and preserve a diagnostics table containing discovery versus confirmation behavior and rerun evidence.

## Checks
Tie-breaking is based on unrounded values. Do not silently accept an approximant for which any grid template failed earlier.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

