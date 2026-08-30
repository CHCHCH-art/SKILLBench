---
name: pycbc-reference-matched-filter-search
description: "Detect binary-black-hole gravitational-wave candidates in noisy detector strain with PyCBC matched filtering: condition the strain, grid-search component masses across task-bound waveform approximants, compute PSD/SNR with the fixed two-stage recipe, and retain each approximant's strongest candidate."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind frame/channel, waveform approximants, component-mass range/grid, output fields, and any Task thresholds from the current task specification. Construct the triangular mass grid with `m2 <= m1` and verify expected uniqueness/completeness.
2. For every stage high-pass strain at **15 Hz**, resample to the stage sample rate, then crop **2 s from both ends** before PSD estimation.
3. Reference discovery stage: sample rate **2048 Hz**, PSD segment **8 s**, matched-filter SNR crop **12 s start / 8 s end**. Reference confirmation stage: **4096 Hz**, PSD segment **4 s**, crop **8 s / 4 s**.
4. Estimate PSD by PyCBC Welch, interpolate to strain frequency grid, then apply inverse-spectrum truncation with truncation length `PSD_segment_seconds * sample_rate` and low-frequency cutoff **15 Hz**. Reject nonfinite/invalid PSD.
5. Generate each waveform template through the current Task's approximant/mass binding, resize to strain length, cyclically shift so template end aligns with time zero under the reference path, and matched-filter with lower frequency cutoff **20 Hz**.
6. Crop the resulting SNR series by the stage margins and select maximum absolute SNR with its sample time. Every approximant must successfully produce a record for every mass-grid point in each stage; missing templates make the stage invalid.

## Checks
Count records as `stages * approximants * grid_size` and require exact equality. Preserve unrounded SNR/time/masses for winner selection.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

