---
name: dots-coefficient-excel-formula
description: "Generate Excel formulas for the OpenPowerlifting Dots coefficient with sex-specific fourth-degree polynomials and bodyweight clamps."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Fixed domain formula
The reference Dots implementation uses `score = total * 500 / polynomial(clamped_bodyweight)`.

Male coefficients `(a,b,c,d,e)` are `(-0.0000010930, 0.0007391293, -0.1918759221, 24.0900756, -307.75076)` with bodyweight clamped to `[40,210]`.
Female coefficients are `(-0.0000010706, 0.0005158568, -0.1126655495, 13.6175032, -57.96288)` with bodyweight clamped to `[40,150]`.
Polynomial is `a*w^4+b*w^3+c*w^2+d*w+e`.

## Reference procedure
1. Build clamp expressions with `MAX(lower,MIN(upper,<bodyweight_cell>))`.
2. Build male/female polynomial expressions, then use `IF(<sex_cell>="M", male_score, female_score)`.
3. Bind the Task-requested output rounding precision; the reference Task uses `ROUND(...,<precision>)`.
4. Do not hard-code dataset row numbers into the coefficient generator.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
