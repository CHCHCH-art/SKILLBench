---
name: shared-shape-dp-budget-closure
description: "Choose a globally shared limited set of LLM sequence shapes with the exact 1-D dynamic program, using the fully derived quadratic decode-cost coefficients, per-bucket compilation charges, iterative budget closure, and deterministic final plan ordering."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Quadratic decode derivation

For one batch with `n` requests and `G=gmax`, map all members to declared shared sequence shape `q`. Using the cost-model definitions
`sum_sq(q,G)=G*q^2 + q*G*(G-1) + G*(G-1)*(2G-1)/6`
and
`sum_lin(q,G)=G*q + G*(G-1)/2`,

`n*decode_cost(q,G)` is exactly `A*q^2 + B*q + C`, with

- `A = n * KD_ATTN * G`;
- `B = n * [KD_ATTN*G*(G-1) + (KD_MLP*HIDDEN)*G]`;
- `C = n * [KD_ATTN*G*(G-1)*(2G-1)/6 + (KD_MLP*HIDDEN)*G*(G-1)/2]`.

When accumulating one required-level entry, add the batch's `prefill_cost_sum + KBATCH_COST` to its constant term `C`. Use the same cost coefficients and Task-bound hidden dimension as `shape-aware-batch-cost-model`.

## Shared-shape DP

1. Collect all distinct required `smax` levels from both bucket partitions, sort ascending, and aggregate `A`, `B`, `C`, plus batch counts for bucket 1 and bucket 2 at each level.
2. Build prefix sums of the coefficient arrays and bucket counts. For a contiguous level interval `[l,r]`, set `q=levels[r]`, and obtain `A_seg`, `B_seg`, `C_seg` by prefix subtraction. Let `uses` be one for each bucket having at least one batch in the interval, so `uses` is 0, 1, or 2. Segment cost is
   `A_seg*q^2 + B_seg*q + C_seg + uses*shape_compile_cost(q)`.
3. Let `u` be the number of distinct levels and `kmax=min(Task_max_shapes,u)`. Initialize `dp[0][0]=0` and all other states to infinity. For `k=1..kmax`, `j=1..u`, try every split `i in [k-1,j-1]` and update `dp[k][j] = min(dp[k-1][i] + seg_cost(i,j-1))`, recording the winning predecessor only on strict improvement.
4. Choose `best_k = argmin_{1..kmax} dp[k][u]`; do **not** force all allowed shapes. Backtrack predecessors, reverse the segments, and map every level in each segment to that segment's maximum level.

## Budget closure

5. For each bucket, actual compilation cost is the sum of `shape_compile_cost(q)` over the unique mapped shapes that bucket uses. The minimum compile reserve is one compile cost at the maximum request-aligned sequence level.
6. Start with partition cap `Task_cost_limit - minimum_compile_reserve - 0.0025*Task_cost_limit`. Run at most **4** closure iterations: optimize both bucket partitions under current caps, run shared-shape DP, recompute actual compile costs, and set `required_cap = Task_cost_limit - actual_compile_cost - safety`. Tighten only if the decrease exceeds `1e-6 * Task_cost_limit`.
7. After closure, optimize both partitions once more under the final caps and rerun shape DP. Abort if either final `partition_cost + compile_cost` exceeds its Task cost limit.
8. Sort batches by `(declared_shape, gmax, smax, minimum_request_id)`; sort member requests by request ID; emit deterministic sequential batch IDs and Task-bound shape/output keys.

## Checks

Require no missing/duplicate request IDs, one identical shape per batch, every declared sequence shape meeting all member requirements, and no more than the Task-provided shared-shape count. If DP backtracking fails, no shape set is produced, or final budget closure fails, abort rather than emitting a partial plan.

