---
name: lake-temperature-glm-staged-calibration
description: "Calibrate the specific five-parameter lake-temperature GLM recipe used by the procedure, with its parameter identities/bounds, staged thermal and mixing Latin-hypercube searches, deterministic seed, multistart coordinate refinement, and fresh final simulation; do not treat it as a generic GLM optimizer."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference lake-temperature calibration recipe
1. Calibrated parameters are the five calibrated parameters `Kw`, `coef_mix_hyp`, `wind_factor`, `lw_factor`, and `ch`. Start from values parsed from the current NML.
2. Reference base bounds are: `Kw (0.10,1.20)`, `coef_mix_hyp (0.05,2.00)`, `wind_factor (0.60,1.40)`, `lw_factor (0.80,1.20)`, `ch (0.00060,0.00250)`. Expand each bound to contain `0.7*start` and `1.4*start` (with `ch` lower handling). Use RNG `default_rng(240509)`.
3. Run baseline and low/high one-at-a-time sensitivity candidates. Then sample **24** thermal LHS candidates over `(Kw,lw_factor,ch)` and rank by shallow RMSE; sample **20** mixing candidates over `(coef_mix_hyp,wind_factor)` around the thermal seed and rank by deep RMSE.
4. Evaluate combined/start joint seeds plus **48** five-dimensional global LHS candidates. Take the best **4** successful seeds sorted by `(overall_RMSE, score)`.
5. Locally refine each seed with relative scales `(0.12,0.06,0.03)`, at most **2 sweeps per scale**. Test each parameter in both directions; `ch` moves multiplicatively in log-range, others add `direction*scale*(hi-lo)`. Accept only when RMSE improves by more than `1e-6`; candidate comparison uses `(rmse_all,score)`.
6. Track global `BEST` by lowest overall RMSE. Rewrite the NML with its parameters and perform a fresh final GLM run; do not return a cached prediction as the final simulation.
7. Apply the Task-requested success threshold from the current task specification to the final RMSE; any concrete Task threshold is not a SKILL constant.

## Checks
Write calibration history/sensitivity/final observation match under the task-bound output convention and verify the final run corresponds to the selected parameter tuple.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

