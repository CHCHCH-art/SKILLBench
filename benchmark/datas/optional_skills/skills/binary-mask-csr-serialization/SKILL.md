---
name: binary-mask-csr-serialization
description: "Serialize a sequence of binary image masks into compact CSR arrays with deterministic row-major indexing and exact dtypes, using task-provided key/schema names only at final output binding."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Read the required output container/key names from the current task specification; keep them as binding parameters until serialization.
2. Convert each final mask to boolean/binary in row-major image order. Build CSR row pointers over image rows and store column indices of nonzero pixels in ascending encounter order.
3. Use the exact dtypes selected by the procedure for shape metadata, row pointers, indices, frame association, and any concatenated offset arrays. Do not change integer widths merely to reduce file size.
4. When multiple frame masks are packed into one archive, preserve sampled-frame order and the reference offset convention so every frame's CSR slice is reconstructable without ambiguity.

## Checks

Round-trip every serialized mask to dense form and compare bit-for-bit with the source binary mask. Validate monotonic row pointers, final pointer equal to nonzero count, and every column index in bounds.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

