---
name: tls-coarse-refined-period-search
description: "Detect and refine a transit period with Transit Least Squares using the reference default coarse search followed by a ±5% local re-search."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Run `transitleastsquares(time, flux).power()` with library defaults on the conditioned light curve.
2. Let the first result's period be `p0`. Run a second TLS power search with `period_min=0.95*p0` and `period_max=1.05*p0`; the ±5% interval is a reference default.
3. Take the refined result period as final. Bind output field/path and precision from `Instruction.md`.
4. If TLS raises or returns a nonfinite/nonpositive period, abort; do not fall back to BLS or Lomb-Scargle.

## Checks

Require finite conditioned time/flux arrays with matching lengths before the first TLS call. The coarse period `p0` must be finite and positive; the refinement interval must satisfy `0 < 0.95*p0 < 1.05*p0`. The refined period must be finite, positive, and lie inside that interval. A TLS exception, empty/invalid result, or period outside the requested refinement bounds aborts the search; do not fall back to another periodogram.
