---
name: receipt-multivariant-ocr-extraction
description: "Extract receipt text robustly from image files by generating the exact grayscale/autocontrast/resize/sharpen/threshold variants and running multiple Tesseract page-segmentation modes before semantic field parsing."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind input image directory and accepted image extensions from the current task specification. Process source filenames in sorted order.
2. Convert to grayscale. Build the reference preprocessing variants including autocontrast with cutoff **2**, enlarged/autocontrasted variants, sharpening used by the procedure, a hard threshold at **128**, and a lower faded-receipt threshold at **100**. Preserve variant order.
3. Run Tesseract over the variants with PSM strategies: primary `--psm 6`; also the reference `--psm 4`, `--psm 3`, `--psm 11`, and the digit/text whitelist PSM-6 pass according to the script's variant loop. Concatenate useful OCR text in reference order for downstream parsing.
4. Do not use OCR output filename ordering as receipt ordering; source filenames determine final row order.

## Checks
If OCR fails for one image, retain the source row and let semantic extraction yield Task-defined null values rather than dropping the image.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

