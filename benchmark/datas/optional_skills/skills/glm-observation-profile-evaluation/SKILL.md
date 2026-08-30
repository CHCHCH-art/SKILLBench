---
name: glm-observation-profile-evaluation
description: "Run GLM candidates and evaluate modeled temperature against observation profiles using the reference NetCDF time/depth alignment, profile interpolation, coverage-aware RMSE bundle, and cached parameter-key convention."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind GLM config/forcing/observation paths, Task target metric, and output requirements from the current task specification. Set NML `timefmt=2`, set the simulation `start` and `stop` from the current Task's requested dates/times, and set/create the output section so `out_dir` and output filename point to the Task-bound destination; these are the concrete reference template edits.
2. Detect observation columns by first trying exact lowercase names: datetime from `datetime,date_time,timestamp,date`, depth from `depth,depth_m,z`, temperature from `temp,temperature,water_temp,wtemp`; if no exact match, choose the first column whose lowercase name contains the corresponding semantic substring. Read GLM NetCDF time/temperature profiles and interpolate each observation against the reference depth-order/bounds procedure.
3. Compute overall, shallow, deep, and per-year residual metrics exactly as specified below. The reference optimization score is `overall_RMSE + 0.08*year_SD + 4.0*max(0,0.98-coverage)`.
4. A failed GLM run/missing output is represented by reference penalty metrics `999` and zero coverage. Cache candidates by the five calibrated parameters rounded to **8 decimals**.
5. Whenever a candidate is run, rewrite the NML from the preserved template, delete stale output, invoke the GLM executable, and score only the newly produced NetCDF.

## Checks
Retain coverage and component RMSE values for every candidate. Never compare candidates using a stale NetCDF from a failed invocation.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

