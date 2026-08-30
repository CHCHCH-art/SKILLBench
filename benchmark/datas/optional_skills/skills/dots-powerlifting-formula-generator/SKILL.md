---
name: dots-powerlifting-formula-generator
description: "Generate Excel formulas for the reference DOTS powerlifting coefficient with sex-specific bodyweight clamp and polynomial coefficients, while taking workbook columns and requested rounding precision from the current Task."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference coefficient
1. Bind sex, bodyweight, total-lift cell references and requested decimal precision from the current task specification/the populated worksheet.
2. For sex equal to reference male code `"M"`, clamp bodyweight to `[40,210]` and use polynomial coefficients `(-0.0000010930, 0.0007391293, -0.1918759221, 24.0900756, -307.75076)` for powers `BW^4..BW^0`.
3. For every other sex value, the procedure uses the female branch: clamp bodyweight to `[40,150]` and coefficients `(-0.0000010706, 0.0005158568, -0.1126655495, 13.6175032, -57.96288)`.
4. Compute `score = total_lift * (500 / polynomial(clamped_BW))` and wrap the Excel result in `ROUND(score, <task_precision>)`. `<task_precision>` must be read from the current task specification; it is not fixed by this SKILL.
5. Emit formulas, not precomputed Python values, for every competitor row.

## Checks
Verify the workbook formula text references the current row and the correct sex branch. Use the same clamp before polynomial evaluation.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.
