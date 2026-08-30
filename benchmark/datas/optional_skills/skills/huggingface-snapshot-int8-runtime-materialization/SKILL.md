---
name: huggingface-snapshot-int8-runtime-materialization
description: "Materialize a Hugging Face sequence-classification snapshot locally, create a fast-tokenizer JSON, and build a row-wise int8 NumPy runtime cache with source-signature invalidation."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind model repository/revision/cache locations from the Task where specified. Download only required configuration, safetensors and tokenizer assets; if `tokenizer.json` is absent, instantiate the fast Transformers tokenizer from local files and save it locally.
2. Compute source signature `file_size:mtime_ns` for the safetensors model. If it differs from the manifest signature, clear the runtime cache and rebuild all tensors.
3. For every 2-D weight matrix `X`, quantize independently by row: `scale=max(abs(row))/127`, replace zero scale by 1, `q=clip(round(X/scale),-127,127).astype(int8)`. Store `q` and row scales separately.
4. Store all non-2D tensors as float32 `.npy`. Sanitize tensor names only for filenames; preserve original tensor names in the manifest.
5. Write a sorted manifest mapping each original tensor name to either quantized matrix files or its float32 file plus the source signature. Abort if tokenizer/runtime artifacts cannot be materialized.

## Checks

For every quantized 2-D tensor, require `q.shape == source.shape`, one finite positive scale per source row, int8 values confined to `[-127,127]`, and a manifest entry that maps the original tensor name to both quantized data and scales. For float32 tensors, require shape preservation. Recompute/compare the source signature before reuse; a signature mismatch must invalidate the entire runtime cache. Missing tokenizer assets, incomplete manifests, or shape mismatches abort materialization.
