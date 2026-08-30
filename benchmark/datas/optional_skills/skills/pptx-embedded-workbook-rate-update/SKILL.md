---
name: pptx-embedded-workbook-rate-update
description: "Locate the intended embedded Excel workbook in a PowerPoint, identify a currency-rate matrix and its matching text shape, update the appropriate direct/inverse rate cell while preserving formulas, and rebuild the embedded object with the reference Apache POI workflow."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Bind presentation path, requested currency pair/rate, and output path from the current task specification. The reference Java environment uses Apache POI **5.5.1** and Log4j **2.24.3**, with the full OOXML schemas/XMLBeans dependency rather than `poi-ooxml-lite`.
2. Traverse slide text shapes recursively, including grouped shapes, and detect the requested rate statement using the reference regular-expression patterns.
3. Enumerate embedded OLE/package parts. Support direct workbook packages and the reference OLE/package unwrap path before attempting workbook parsing.
4. For each workbook, scan sheets for a matrix whose row/column labels contain three-letter currency-like codes. Score a candidate matrix as `100 * overlap + min(row_label_count, column_label_count)` and retain its geometry and supported pairs.
5. Pair a detected rate text shape with a workbook/matrix that supports the same currency pair. Use the reference shape-to-embedded-object distance score, subtracting `matrix_score * 0.0001`; when anchor information is absent use reference distance `1e8`.
6. Update the **direct** matrix cell when it is nonformula. If direct is a formula, update the inverse cell when that cell is nonformula using reciprocal `1/rate`. Fail when both direct and inverse cells are formulas; do not overwrite a formula merely to force the requested value.
7. Snapshot every workbook formula string before editing. Evaluate the resulting direct target value with POI and require it to match the requested Task rate under the reference verification.
8. Rebuild the raw embedded object in the same container representation used by the original package (direct ZIP or wrapped object) and record exactly which embedding part was changed.

## Checks

After update, every snapshotted formula string must remain identical. Reopen the updated workbook and re-evaluate the requested pair before placing it back into the PPTX.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

