---
name: metric-csv-first-field-update
description: "Safely update metric values in an existing CSV-like template while preserving comments, unknown rows, ordering, line endings, and field text outside the first value delimiter. Use when a required procedure edits only recognized metric rows in place."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Read the Task-provided template path and metric-to-value mapping from the current task specification/the preceding computation. Read the file with line endings preserved.
2. Preserve blank lines and comment lines byte-for-byte. For a data line, split only at the **first comma** so subsequent commas/text remain untouched.
3. If the row key is recognized by the computed mapping, replace only its value portion. Serialize booleans as lowercase `true`/`false` exactly as specified here. Leave unknown keys unchanged.
4. Preserve original row order and line-ending style. Write to a temporary file in the same destination context, then atomically replace the requested output/template file.

## Checks

Compare input and output line counts. Outside recognized value fields, content must be unchanged; unknown metric rows and all comments must compare exactly.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.
