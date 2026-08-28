---
name: lake-glm-five-parameter-nelder-mead-calibration
description: "Calibrate the reference five-parameter lake GLM namelist by repeated model runs and Nelder-Mead search against temperature observations."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Scope
This is a specific five-parameter lake-GLM calibration recipe, not a general GLM optimizer.

## Reference procedure
1. Optimize parameters in this fixed order: `Kw`, `coef_mix_hyp`, `wind_factor`, `lw_factor`, `ch`. Start from `[0.3, 0.5, 1.0, 1.0, 0.0013]`.
2. Before each run, round the first four trial parameters to 4 decimals and `ch` to 6 decimals. Replace each namelist assignment with regex `(<parameter>\s*=\s*)[\d\.\-e]+`.
3. Execute `glm`; a nonzero model run or unreadable output scores **999**.
4. Minimize RMSE with SciPy Nelder-Mead, `maxiter=100`, `xatol=0.01`, `fatol=0.05`, with no explicit parameter bounds.
5. Track the best successful point globally. The reference uses an early-stop objective threshold of **1.5 RMSE**; on reaching it, raise/catch an early-stop signal rather than continue optimization.
6. Write the best parameters to the namelist and run GLM once more. If no successful trial produced a best parameter vector, abort.

## Checks

Treat a GLM subprocess failure, missing output, or nonfinite aligned RMSE as objective value `999`, exactly as the reference does. Track a best parameter vector only from successful finite runs. After optimization/early-stop, rewrite the namelist with that best vector, rerun GLM, and recompute the observation-aligned RMSE; if the final run fails or no successful trial ever existed, abort instead of keeping an optimizer result that was never validated by the simulator.
