---
name: tanimoto-topk-molecule-ranking
description: "Rank resolved molecular fingerprints by Tanimoto similarity with deterministic task-defined tie handling and top-k selection."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Compute `DataStructs.TanimotoSimilarity(target_fp, candidate_fp)` for each successfully resolved candidate.
2. Bind top-k and tie ordering from `Instruction.md`. The reference sorts candidates by descending similarity and then name ascending.
3. Include the target itself if it occurs in the extracted pool and successfully resolves; do not forcibly remove it.
4. Return the first k records after sorting. Failed PubChem candidates remain absent rather than receiving zero similarity.
5. Validate similarity is finite and in `[0,1]`; reject any malformed candidate record.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
