---
name: formula-cache-ooxml-roundtrip-verification
description: "Finalize and verify a formula-populated XLSX so formulas, numeric cached results, styles, sheet structure, and package integrity are present at the exact task-bound workbook path. Use independent caches as the primary deterministic result; optional spreadsheet recalculation is only a cross-check."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check`. If it fails, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`. LibreOffice/soffice is optional.

## Required inputs

Bind:

- `<input_or_final_workbook>`: the exact workbook path the task expects to be modified or emitted;
- `<task_sheet>`;
- `<formula_manifest>` containing every required target cell, formula text, expected numeric value, and original style ID;
- `<all_target_ranges>` covering lookup, derived, statistic, and weighted-output cells;
- any task restrictions on sheets, macros, formatting, or other workbook content.

If the task gives no separate output filename, `<input_or_final_workbook>` is the original workbook path. Finishing with a validated temporary copy while leaving this path unchanged is a failure.

## Procedure

1. Create a staging copy if desired, but ensure it already contains both `<f>` and independent `<v>` for every manifest target. Independent cache values are the deterministic primary result.
2. Optional recalculation cross-check: if LibreOffice/soffice is available, recalculate a copy headlessly. Compare recalculated values against the independent expected values with

   ```text
   tolerance = max(1e-7, abs(expected) * 1e-8)
   ```

   Accept recalculated caches only if every required target is present, finite, and within tolerance. Otherwise retain the independent caches. Recalculation must never be the only mechanism that creates usable caches.
3. Repatch the selected cache values into the original-preserving OOXML tree while keeping each manifest formula string and target style ID unchanged.
4. Repack with ZIP deflate and validate ZIP integrity. Preserve the task-bound sheet set and reject prohibited macros/binary project content.
5. If staging was used, atomically replace `<input_or_final_workbook>` now. Do not leave the validated artifact under another filename.
6. Reopen `<input_or_final_workbook>` itself and verify every manifest entry at OOXML level:
   - cell exists;
   - `<f>` equals the manifest formula;
   - `<v>` exists, parses as finite numeric data, and matches expected within tolerance;
   - style ID equals the recorded original style.
7. Run the generic verifier:

   ```text
   python3 scripts/verify_formula_targets.py \
     --workbook <input_or_final_workbook> \
     --sheet <task_sheet> \
     --ranges <range1> <range2> ...
   ```

   This command must report that every cell in every bound target range has both formula and numeric cache.
8. Perform one consumer-style cached-value read as a final checkpoint. The task-bound result ranges must be populated from the exact final workbook path.

## Checks

The final artifact is invalid if any of these conditions occurs:

- a required target cell is absent or has no `<f>`;
- a required target has no numeric `<v>`;
- a cache differs from the independent expected value beyond tolerance;
- a formula string or target style changes unexpectedly;
- any bound target range appears empty under cached-value reading;
- the final validated file is not the exact task-bound workbook path;
- ZIP integrity fails;
- prohibited sheets, macros, or binary content are introduced.

Do not report success until the final-path verifier passes.
