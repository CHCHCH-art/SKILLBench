---
name: pycbc-waveform-grid-matched-filter-search
description: "Grid-search task-supplied waveform approximants and component masses with PyCBC matched filtering, then retain the highest-SNR result per approximant."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind approximant list and mass search range/step from `Instruction.md`. Enumerate only combinations with `m1 >= m2` to avoid symmetric duplicates.
2. Generate `get_td_waveform` templates with the Task approximant/masses, conditioned `delta_t`, and reference `f_lower=20 Hz`. Resize the plus polarization to the data length and cyclically shift by its `start_time` so merger aligns at time zero.
3. Call `matched_filter(..., psd=reference_psd, low_frequency_cutoff=20)`. Crop SNR by **8 s at the beginning** and **4 s at the end**. Maximize absolute complex SNR over time.
4. If a particular waveform combination raises, skip that combination and continue. For each approximant, update the winner only on strictly greater SNR.
5. Preserve Task approximant order in output. If no combination succeeds at all, emit the reference fallback row with null approximant and zero SNR/total mass, mapped to Task output schema.

## Checks

For each successful mass/approximant candidate, require a finite template, template `delta_t` matching the conditioned strain, and a resized template length equal to the data length before filtering. After the 8-second/4-second SNR crop, at least one sample must remain and the selected maximum absolute SNR must be finite. Maintain at most one winner per approximant and update only on strictly greater SNR. Candidate-specific waveform/filter exceptions are skipped as specified; if all candidates fail, emit only the documented fallback row rather than inventing a best mass.
