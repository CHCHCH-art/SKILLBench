---
name: metric-csv-template-update
description: "Safely fill only metric values in a comma-separated template while preserving comments, metric names, unknown lines, and reference boolean formatting."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Read the output path/schema requirements from `Instruction.md`, and compute a mapping from requested metric names to values.
2. Process the existing template line-by-line. Copy lines beginning with `#` unchanged.
3. For a noncomment line containing a comma, split only at the first comma. Treat the left side as the metric key; if the key is in the computed mapping, replace only the right-side value. Preserve unrecognized records unchanged.
4. Render booleans as lowercase `true`/`false`; otherwise use the already rounded scalar representation from the metric stage.
5. Write to a temporary sibling file and atomically replace the original template.
6. Track which requested keys were updated. If a required metric key was absent, abort instead of appending a new schema row.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
