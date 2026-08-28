---
name: streaming-dated-log-sqlite-aggregation
description: "Stream dated log files into a temporary SQLite severity-count table and aggregate bracketed severity occurrences without retaining log contents in memory."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind log directory, reference/current date, severity labels and requested date periods from `Instruction.md`.
2. Recurse with `os.walk`. Parse each file date from the filename prefix before the first underscore with `date.fromisoformat`; skip files whose prefix is not an ISO date.
3. Open logs in binary mode with a **1 MiB** buffer. For every line, independently test each severity needle encoded as the literal bracketed byte sequence `[<severity>]`; a line containing multiple configured needles may increment more than one severity.
4. Accumulate `(date,severity,count)` rows into a temporary SQLite database. Reference pragmas are `journal_mode=OFF`, `synchronous=OFF`, `temp_store=FILE`, `cache_size=-32768`; insert in batches of **8192** and build an index on `(date,severity)`.
5. Do not retain original line text in SQLite. A read/parse error for the database pipeline is fatal rather than a trigger for an in-memory fallback.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
