---
name: binary-mask-csr-npz-serialization
description: "Serialize one binary mask per sampled frame as CSR arrays inside a compressed NPZ while binding key names and output path from the current task."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind output path, shape key and per-frame key naming pattern from `Instruction.md`.
2. For each boolean `H x W` mask obtain `(rows, cols)=where(mask)`. Store `data=ones(len(cols), dtype=bool)` and `indices=cols.astype(int32)` in row-major `where` order.
3. Build `indptr=zeros(H+1,int32)`. For every true-pixel row index `r`, increment all entries `indptr[r+1:]` by one. This is the reference construction; do not replace its on-the-fly convention with a different sparse serialization contract.
4. Store a two-element shape array and each frame's `data/indices/indptr` under the bound key pattern, then call compressed NPZ save.
5. Validate `indptr[0]==0`, `indptr[-1]==len(indices)==len(data)`, nondecreasing `indptr`, and all indices in `[0,W)`. Abort serialization on violation.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
