---
name: dated-log-severity-summary
description: "Count task-specified severity markers in recursively stored date-prefixed log files over inclusive relative date periods using the reference filename-date filtering and GNU date arithmetic, then emit period/severity totals."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind log root, reference/current date, filename date convention, severity markers, requested periods, and CSV schema from the current task specification.
2. For each requested relative N-day period, derive inclusive start as `current_date - (N-1) days` and end as current date. Month-to-date begins on the first day of the current date's month. Use GNU `date` conversion for boundary timestamps.
3. Recursively enumerate files under the Task log root. Extract the date token from each filename using prefix/underscore convention, convert it to a timestamp, and include the file only when its date falls inclusively within the current period.
4. Count each Task severity using fixed-string/marker grep semantics matching the procedure. Also compute the Task-requested all-date totals over every log regardless of filename date.
5. Emit rows in the specified period order and Task severity order with the Task-provided column names.

## Checks
An N-day period includes exactly N calendar dates. Filename filtering, not timestamps inside log lines, controls date-period membership in this procedure.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

