---
name: openpyxl-native-pivot-workbook
description: "Create a tabular-analysis XLSX source table and native OpenXML pivot table/cache definitions for task-specified row, column, aggregate fields and subtotals, then verify the serialized pivot parts."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure

1. Bind `<source_sheet>`, source columns, pivot sheet names, row/column/value field roles and subtotal functions from `Instruction.md`.
2. Create a fresh workbook whose first worksheet is named `<source_sheet>`, then append the Task-required headers and enriched rows.
3. Create a `CacheDefinition` whose worksheet source points to `<source_sheet>` and spans its populated source range, with one `CacheField` containing empty `SharedItems` per source header.
4. For each pivot, create `TableDefinition`, attach row/optional-column axes via `PivotField`/`RowColField`, attach one `DataField` with the requested subtotal, and assign the cache. Set `Location.ref` to a deterministic rectangle on the pivot sheet large enough to cover the expected pivot output envelope; exact cell coordinates are incidental serialization layout, not a semantic SKILL default.
5. Append the pivot object to the target worksheet's private pivot list and save.

## Checks

After saving, reopen the XLSX as an OOXML ZIP. Require: the `<source_sheet>` name and range in the pivot cache match the populated source table; cache-field count equals source-header count; every requested pivot has a serialized pivotTable part and relationship; its row/column/data field indexes are valid source-field indexes; the declared `Location.ref` is a valid nonempty rectangle; and workbook XML remains readable by openpyxl. If any pivot/cache part is missing or inconsistent, abort instead of returning a workbook that merely contains ordinary worksheets.
