---
name: acopf-solution-reporting
description: "Report and validate the final AC optimal power flow solution after a rectangular-coordinate IPOPT solve: recompute physical voltage, generation, branch flows/loading, nodal balances, and total cost with the procedure's deterministic ranking and serialization conventions."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Recover bus voltage magnitude as `sqrt(E^2+F^2)` and angle with `atan2(F,E)` converted to degrees. Convert per-unit generation/flows back with Task/network base power.
2. Recompute all branch powers numerically from the solved `E,F`; use these recomputed physical flows rather than trusting only auxiliary branch decision variables.
3. For each rated branch compute apparent power at each end and define loading as `max(|S_ft|, |S_tf|) / limit * 100`.
4. Recompute real/reactive nodal balances and the maximum discrepancy between explicit solved branch variables and physical recomputation. Include the diagnostics expected by the reference report path.
5. Sort/report branch loading using the stated deterministic convention. If the Task supplies a requested count, bind that count; only when no count is supplied use the reference report default of **10** entries.
6. Apply final monetary/physical rounding only at serialization; reference total cost is rounded to 2 decimals in its report object.

## Checks

The post-solve recomputation must be based on unrounded solution values. Confirm reported rankings are generated before display rounding so ties are not introduced by formatting.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

