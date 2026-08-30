---
name: glm-profile-observation-rmse-alignment
description: "Transform GLM NetCDF temperature profiles and observed lake temperatures into the exact datetime/depth keys used by the calibration recipe, then compute matched-profile RMSE with its fixed depth conversion and empty-match penalty."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure

1. Read GLM variables `time`, `z`, and `temp`. Form simulation datetimes from the Task's simulation start date with the reference clock offset **12:00:00**, then add each model-time value as hours.
2. Use the reference lake-depth default **`LAKE_DEPTH = 25`**. For every unmasked model height `h`, compute `depth = 25 - h`; keep only `0 <= depth <= 25`, then round depth with Python `round()` before matching.
3. For every retained temperature, create `(datetime, rounded_depth, temp_sim)`. If multiple model rows share the same `(datetime, depth)`, average `temp_sim` over that key.
4. Parse observed datetimes with `pandas.to_datetime`, round observed depths and convert them to integer, rename the observed-temperature field to the local comparison field, and retain only `(datetime, depth, temp_obs)`.
5. Inner-join observations and simulation exactly on `(datetime, depth)`. Do not interpolate time or depth.
6. If the join is empty, return the reference penalty **`999.0`**. Otherwise compute `sqrt(mean((temp_sim - temp_obs)^2))`. A nonfinite RMSE is a failed calibration trial.

## Checks

Require `time`, `z`, and `temp` to exist and their indexed profile dimensions to be compatible. Every retained simulation depth must lie in `[0,25]`, all matched temperatures must be finite, and grouped `(datetime, depth)` keys must be unique before the join. After joining, either return exactly `999.0` for zero matches or a finite nonnegative RMSE. Shape mismatch, invalid NetCDF variables, or nonfinite matched values abort this step rather than triggering interpolation or a different depth convention.
