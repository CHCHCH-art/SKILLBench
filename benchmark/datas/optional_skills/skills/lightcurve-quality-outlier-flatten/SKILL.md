---
name: lightcurve-quality-outlier-flatten
description: "Condition a photometric time series for transit-period search by filtering quality flags, dropping nonfinite samples, 3-sigma outliers, and applying Lightkurve flattening."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind time, flux and quality columns plus the accepted quality value from `Instruction.md`.
2. Keep only rows with the accepted quality flag and finite time/flux.
3. Construct a `lightkurve.LightCurve` and call `remove_outliers(sigma=3)`; **3 sigma is the reference default**.
4. Call `flatten()` with Lightkurve defaults. Do not replace it with a GP, polynomial, Savitzky-Golay or manually chosen window.
5. Abort if too few finite points remain for the downstream transit search.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
