---
name: shared-sequence-shape-selection
description: "Choose a shared bounded set of aligned sequence shapes for two LLM request buckets using the reference weighted-L1 k-medoids and generation-weighted quantile candidates."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind alignment granularity, max shared shapes, head/hidden dimensions and request fields from `Instruction.md`. Align prompt length with `ceil(prompt/granularity)*granularity`; generation length is unchanged.
2. K-medoids candidate: use points `(S,G)`, default `k=<task max shapes>`, **8 iterations**, weighted L1 `w_s*|ΔS|+w_g*|ΔG|`. Initialize each medoid from an S-quantile `q=(i+0.5)/k` by choosing the nearest observed S, then fill missing unique medoids from earliest points. Reassign and choose within-cluster medoid minimizing total distance; stop when unchanged. Always include global max S; if over k, trim the core by integer stepping while preserving max S.
3. Sweep k-medoids generation weights `w_g` over the reference values `4, 8, 12` with `w_s=1`.
4. Weighted-quantile candidate: sort `(S, 1+alpha*G)`, build cumulative weight CDF, choose quantiles `i/(k+1)` for i=1..k, and include max S. Sweep reference `alpha` values `0,0.01,0.02,0.05`; trim overfull sets with the reference evenly spaced index rule while preserving max S.
5. Assign each request to the smallest representative `>=S`; if none, use largest representative.

## Checks

Require every aligned prompt size to be a positive multiple of the Task granularity and every candidate representative to come from the constructed candidate set. After deduplication/trimming, the shared representative set must contain at most the Task maximum number of shapes and must include the global maximum aligned prompt size. Every request must map to a representative `>=` its aligned prompt size; no request may remain uncovered. K-medoids updates must preserve unique medoids after refill, and quantile trimming must preserve the maximum representative. If any candidate violates coverage or cardinality, reject that candidate rather than repairing it with a different shape-selection algorithm.
