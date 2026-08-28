---
name: ooxml-two-key-lookup-formula-population
description: "Populate existing formatted Excel target cells with two-key lookup formulas keyed by a row label and a column label. Bind workbook-specific sheets/ranges from the current task specification, compute independent expected values, write both formula text and numeric OOXML caches, and preserve styles and unrelated workbook content."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check`. If it fails, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Runtime bindings

Before editing, bind all workbook-specific facts from the current task specification and workbook:

- `<input_workbook>` and, if separately specified, `<output_workbook>`;
- `<task_sheet>` and `<source_sheet>`;
- `<source_data_range>`;
- every `<lookup_target_range>`;
- the task-side row-key cells/column and task-side period/header cells;
- the source-side row-key column and period/header row;
- restrictions on sheet count, formatting, macros, and other workbook content.

If the task names one workbook to be edited and gives no distinct output filename, set `<final_workbook> = <input_workbook>`. Temporary copies are allowed, but the final validated package must atomically replace that exact path before completion.

Do not start formula generation until every target cell maps to exactly one `(row_key, column_key)` pair.

## Mandatory execution sequence

1. Read the workbook as an OOXML ZIP package. Resolve sheet XML from `xl/workbook.xml` plus `xl/_rels/workbook.xml.rels`; load shared strings when present.
2. Read all task-side row keys and period/header keys from the bound locations. Normalize only for matching: trim surrounding whitespace and render integral numeric keys without a decimal suffix. Keep raw values separate when formulas need their original representation.
3. Read `<source_data_range>` and build unique mappings:
   - normalized row key -> source row;
   - normalized period key -> source column.
   If either key is duplicated where uniqueness is required, stop rather than silently choosing one occurrence.
4. Before writing anything, resolve every target pair against the source table and materialize an independent observation relation:

   ```text
   (row_key, period_key, numeric_value, source_row, source_column)
   ```

   Require complete coverage. A lookup fallback such as `IFERROR(...,0)` must not be used to hide a missing source observation.
5. Generate the lookup formula family allowed by the task. For INDEX/MATCH, use this shape:

   ```text
   IFERROR(
     INDEX(<source_value_rectangle>,
           MATCH(<task_row_key_cell>, <source_row_key_range>, 0),
           MATCH(<task_period_cell>, <source_header_range>, 0)),
     0)
   ```

   Both `MATCH` calls use exact-match mode `0`. Construct absolute/relative references from the runtime bindings; do not substitute workbook-specific coordinates from this SKILL.
6. For each target cell, independently obtain the expected numeric value from the materialized relation. Store `{cell, formula, expected_value, original_style}` in one manifest covering all lookup targets.
7. Patch the existing target cells directly in OOXML. Each target must contain both:
   - `<f>` with the formula text;
   - `<v>` with the independently computed numeric cache.

   Preserve existing cell attributes, especially style `s`. A high-level library save that leaves formula caches empty is not sufficient.
8. Use `scripts/patch_formula_cache.py` to perform the patch when helpful. It accepts a manifest of `cell -> {formula, value}` and preserves existing cell attributes.
9. Reopen the patched workbook before any downstream formulas are generated. Verify every bound lookup target has a nonempty formula and numeric cache. If this checkpoint fails, do not continue to derived calculations.

## Artifact-path rule

A frequent failure mode is producing a correct staging workbook while leaving the task-bound workbook unchanged. Treat the final path as part of the computation:

- stage under temporary filenames if needed;
- validate the stage;
- atomically replace `<final_workbook>`;
- reopen `<final_workbook>` itself and verify its target ranges again.

Do not report completion based only on a temporary or alternate output file.

## Checks

Before leaving this stage, require all of the following:

- every target pair resolves to exactly one numeric source observation;
- every target cell contains both `<f>` and numeric `<v>`;
- every formula references the bound source sheet/ranges and intended task key cells;
- the populated target count equals the exact cell count implied by all bound lookup ranges;
- cached values equal the independent source lookup within numeric tolerance;
- original style IDs on target cells are unchanged;
- the final task-bound workbook path, not only a staging copy, contains the populated targets.

Abort on any missing target, missing cache, duplicate lookup key, formula/cache mismatch, or final-path mismatch.
