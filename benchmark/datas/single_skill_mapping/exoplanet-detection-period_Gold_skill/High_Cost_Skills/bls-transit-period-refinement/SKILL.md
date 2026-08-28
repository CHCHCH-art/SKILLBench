---
name: bls-transit-period-refinement
description: "Search and refine an exoplanet transit period with two-stage Box Least Squares grid, harmonic candidate expansion, odd/even-depth alias penalty, and deterministic local frequency refinement."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference transit search

1. Reference period bounds are `period_min=max(0.60,10*cadence)` and `period_max=min(30.0,0.50*baseline)`. If `period_max <= 1.5*period_min`, replace it with `min(0.80*baseline,4.0*period_min)`; if it is still `<=period_min`, abort. Duration bounds are `max(2.5*cadence,0.018)` to `min(0.18,0.22*period_min)`; if inverted use `1.5*duration_min`. Evaluate **12** linearly spaced durations.
2. Construct period grids in frequency with step `1/(baseline*samples_per_peak)`. Preliminary BLS uses `samples_per_peak=120`; final BLS uses `300`. Both call `BoxLeastSquares.power(..., objective="likelihood", method="fast", oversample=10)`.
3. After final BLS, sort powers descending. Keep up to **7** frequency-separated peaks, requiring frequency separation `> 4*coarse_df`, where `coarse_df=1/(baseline*300)`.
4. Expand each retained peak to `(p, 0.5p, 2p)` when within search bounds and more than relative `2e-4` from an already collected candidate.
5. Around each candidate use frequency half-width `max(6*coarse_df, 2e-5/max(p^2,1e-12))`, clipped to search bounds, and evaluate exactly **12001** linearly spaced frequencies. Local BLS uses `oversample=15`.
6. Score each local winner by raw BLS power. If odd/even transit depths and uncertainties are available, compute `z=|d_odd-d_even|/hypot(sig_odd,sig_even)`; for `z>1.5`, subtract `0.5*(z-1.5)^2`. If per-transit counts show fewer than 2 observed events, subtract `1e6`.
7. Choose the highest score. If no finite refined candidate exists, fall back to the final coarse BLS maximum. Render the period with the Task-requested output precision.

## Checks

Never compare rounded periods. Keep preliminary period/duration/time for the GP transit mask and final refined score diagnostics separately.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

