---
name: pycbc-strain-conditioning-psd
description: "Condition gravitational-wave strain and construct a PSD exactly as the reference PyCBC matched-filter grid search requires."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind frame path and strain channel from `Instruction.md` and read with `pycbc.frame.read_frame`.
2. High-pass at **15 Hz**, resample to **4096 Hz**, then crop **2 s** from each end; these are reference defaults.
3. Estimate PSD from the conditioned series with **4 s** segments, interpolate it to the conditioned frequency spacing, then call inverse-spectrum truncation with length `4*sample_rate` and low-frequency cutoff **15 Hz**.
4. Abort if the conditioned series is too short or PSD contains unusable values; do not switch PSD estimators.

## Checks

Require readable strain data with finite samples and sufficient duration to survive resampling, the 2-second crop on both ends, and the 4-second PSD segmentation. After resampling, require sample rate 4096 Hz and positive frequency spacing. The interpolated/truncated PSD must align with the conditioned strain frequency grid and contain finite positive values over frequencies used by matched filtering. Insufficient duration, grid mismatch, nonpositive PSD bins in the usable band, or conditioning failure aborts preprocessing rather than switching estimators.
