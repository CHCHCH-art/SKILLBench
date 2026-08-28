---
name: date-range-severity-summary-emission
description: "Query inclusive Task-defined date ranges from severity counts and emit a deterministic zero-filled summary CSV in requested period/severity order."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Construct each Task-defined period from the current/reference date exactly as specified by `Instruction.md`; the reference SQL query uses inclusive `date BETWEEN start AND end`.
2. For each period, query grouped severity sums. Fill a zero for every configured severity absent from that period.
3. Emit rows in Task period order, and within each period in Task severity order. Preserve the requested total/summary row convention from Instruction.
4. Ensure counts are integers and no queried date falls outside its bound period. If the date-range specification cannot be resolved, abort instead of guessing calendar semantics.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
