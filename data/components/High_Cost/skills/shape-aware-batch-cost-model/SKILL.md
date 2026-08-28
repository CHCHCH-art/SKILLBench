---
name: shape-aware-batch-cost-model
description: "Reproduce the analytical LLM batching cost model: prompt alignment, arithmetic-series decode compute, prefill/decode latency, token padding, per-batch overhead, shape compilation cost, and P95 exceedance accounting used by its shape-aware scheduler."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Task bindings

Read alignment granularity `G_align`, aligned head/hidden dimensions `H`, shared-shape limit, per-bucket metric budgets, request schema, and output schema from the current task specification.

## Exact reference arithmetic

Align a prompt length `p` by `S = ceil(p/G_align)*G_align`.
For an arithmetic sequence `a, a+1, ..., a+n-1`, use
`sum_sq_arith(a,n) = n*a^2 + a*n*(n-1) + n*(n-1)*(2*n-1)/6`, i.e. `sum_{t=0}^{n-1}(a+t)^2`.
Also define `sum_lin(a,n) = n*a + n*(n-1)/2 = sum_{t=0}^{n-1}(a+t)`.

Reference coefficients not supplied by the Task are:
`KP_ATTN=2.0`, `KP_MLP=1.0`, `KD_ATTN=1.0`, `KD_MLP=0.5`,
`TP_ATTN=0.002`, `TP_MLP=0.0015`, `TD_ATTN=0.0012`, `TD_MLP=0.0006`,
`KSHAPE_ATTN=500.0`, `KSHAPE_MLP=2.0`, `KBATCH_COST=10_000_000.0`, and `TBATCH_MS=8.0`.
The script also defines `TSHAPE_COMPILE_MS=1500.0` but does not use it in the planning arithmetic; do not inject it into costs/latencies that this procedure does not charge.

For aligned prompt/context `S`, generation bound `g`, and Task hidden dimension `H`:

- `prefill_cost(p) = KP_ATTN*S^2 + KP_MLP*S*H`;
- `prefill_lat(p) = TP_ATTN*S^2 + TP_MLP*S*H`;
- `decode_cost(S,g) = KD_ATTN*sum_sq_arith(S,g) + (KD_MLP*H)*sum_lin(S,g)`;
- `decode_lat(S,g) = TD_ATTN*sum_sq_arith(S,g) + (TD_MLP*H)*sum_lin(S,g)`;
- `shape_compile_cost(q) = KSHAPE_ATTN*q^2 + KSHAPE_MLP*q*H`.

## Batch aggregation

1. A batch has `smax=max(member aligned prompts)` and `gmax=max(member generation lengths)` unless a larger declared shared sequence shape `q` is supplied for decode arithmetic.
2. `batch_cost = sum(member prefill_cost) + n*decode_cost(q_or_smax,gmax) + KBATCH_COST`.
3. Per-request prompt padding is `p_pad_i = aligned_prompt_i - prompt_len_i`; batch prompt padding is `sum_i p_pad_i` and does **not** add extra padding from the batch/shared `smax`. Generation padding is `n*gmax - sum_i gen_len_i`. Thus `batch_pad = sum_i(aligned_prompt_i-prompt_len_i) + n*gmax - sum_i gen_len_i`. Reference real tokens are `sum_i(prompt_len_i + gen_len_i)` using the **unaligned** prompt lengths.
4. `batch_exec_time = max(member prefill_lat) + decode_lat(q_or_smax,gmax) + TBATCH_MS`.
5. For a Task P95 latency limit `L`, compute `cutoff = L - decode_lat(q_or_smax,gmax) - TBATCH_MS`; with sorted member prefill latencies, exceedances are `n - bisect_right(prefill_latencies, cutoff)`. The permitted high-latency count is `n - ceil(0.95*n)`.

## Checks

Recompute batch and partition totals directly from request members after every structural change. If any arithmetic invariant is nonfinite/inconsistent, or a batch uses a declared shape smaller than a member requirement, reject that batch/merge; do not continue planning with approximated costs.

