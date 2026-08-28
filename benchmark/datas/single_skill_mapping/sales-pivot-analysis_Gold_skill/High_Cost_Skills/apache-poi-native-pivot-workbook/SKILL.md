---
name: apache-poi-native-pivot-workbook
description: "Build an Excel analytical workbook with task-bound source and pivot sheets using Apache POI native PivotTable objects, preserved source formatting, task-requested aggregations, safe pivot placement, and OOXML package validation."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind output workbook path, sheet names, source relation/range, pivot row/column/value fields, aggregation types, source headers, and labels from the current task specification. Keep workbook-specific coordinates out of the SKILL unless the task explicitly supplies them.

## Procedure

1. Use Apache POI **5.5.1** with full OOXML schemas. Create/write the task-bound source-data sheet using the required numeric/string types; every row must have the expected field count.
2. Apply the procedure's source-header style, numeric formatting, freeze-pane, and autofilter conventions when those formatting details are part of the desired workbook behavior.
3. Create each requested pivot sheet and call POI `createPivotTable` over the full resolved source range. Add the task-bound row labels, optional column label, and data fields with the requested aggregations.
4. Choose a pivot anchor that does not overlap existing required content and leaves sufficient space for the pivot output.
5. Save and reopen the XLSX package. Verify the workbook retains exactly the task-required sheets and that OOXML contains the expected native `pivotTable` definitions plus corresponding pivot-cache definitions.

## Checks

Do not replace PivotTables with static summary cells. Require each native pivot definition to reference the intended source cache/range, each configured field index to exist in the source schema, and each pivot anchor/output region to avoid required pre-existing content. Abort on broken pivot-cache relationships, missing pivot parts, invalid source field references, or sheet-set changes outside the task requirements.
