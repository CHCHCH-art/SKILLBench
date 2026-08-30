---
name: fractional-coordinate-rational-formatting
description: "Format representative atom fractional coordinates for CIF Wyckoff-position analysis as simple rational strings under the task-supplied denominator limit, preserving the upstream Wyckoff-letter order."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind the maximum allowed denominator from `Instruction.md`.
2. For each floating fractional coordinate `c`, compute `sympy.Rational(c).limit_denominator(<max_denominator>)`.
3. Convert the rational to its ordinary string representation, so integral rationals become strings such as `0` and nonintegral rationals use `numerator/denominator`.
4. Preserve coordinate order `(x,y,z)` and preserve the Wyckoff-letter ordering established upstream. Do not apply an additional modulo, tolerance snap, or decimal rounding stage.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
