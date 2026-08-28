---
name: typed-record-diff-json
description: "Compare old tabular records with a current Excel workbook by task-defined primary key and field schema, producing deterministically sorted deletions and field-level modifications with typed old/new JSON values."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind current-workbook path, primary-key field, comparison columns, field types, and output JSON schema from the current task specification.
2. Load the current Excel relation and normalize both old/new values through the stated scalar conversion so Task numeric fields remain JSON numbers and text fields remain strings/null as required.
3. Deleted keys are old-table keys absent from the current table; sort them lexicographically/naturally exactly as the reference key strings compare.
4. For keys present in both tables, compare every Task-specified field. Emit one modification object per changed field with old and new values; unchanged fields produce no record.
5. Sort modifications by `(id, field)` before serialization. Write to a temporary JSON file and atomically replace the Task output.

## Checks
Ensure duplicate primary keys are rejected/handled under the reference assumptions and that output contains no changes caused solely by differing Python scalar container types.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

