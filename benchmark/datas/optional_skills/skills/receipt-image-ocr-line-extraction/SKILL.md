---
name: receipt-image-ocr-line-extraction
description: "Preprocess receipt images and reconstruct ordered OCR lines with bounding boxes and confidence using the reference Tesseract image-data pipeline."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Accept the Task's image folder and supported image extensions. Convert each image to grayscale. If mean grayscale intensity is `<105`, invert it; apply autocontrast with cutoff 2.
2. If image width is `<900`, resize by `min(2.0, 900/width)` only when scale `>1.05`, using Lanczos.
3. Run Tesseract `image_to_data` with `--oem 3 --psm 6`. Group tokens by `(block_num,par_num,line_num)`, sort tokens by x, join with spaces, union their boxes, and average nonnegative confidences.
4. Sort reconstructed lines by `(top,left)`. A receipt-level exception is caught by the reference caller and produces missing date/total for that file rather than stopping all files.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
