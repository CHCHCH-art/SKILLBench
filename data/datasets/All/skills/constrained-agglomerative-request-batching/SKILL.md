---
name: constrained-agglomerative-request-batching
description: "Pack arbitrary prompt/generation requests into shape-aware static-graph LLM inference batches under a global unique-shape budget, using singleton-start sparse agglomerative merges, feasibility-gated improvement, fixed candidate neighborhoods, phase budgets, and deterministic ordering."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference merge search
1. Start with one batch per request. If there are at most **96** batches, consider every pair. Otherwise form sparse neighbor pairs from four fixed orderings: `(gmax,smax,n)`, `(smax,gmax,n)`, decode-latency order, and `gmax*max(1,smax)` order, taking the current phase window.
2. For each merge, recompute cost, padding, sequential time and high-latency exceedance deltas. Reject any merge with nonpositive sequential-time gain.
3. If a metric is already within its cap, a merge may not cross that cap; if it is currently above cap, require the merge delta for that metric to improve it. This rule applies independently to cost, padding, and high-latency count.
4. Score an admissible merge as `seq_gain / penalty`, with penalty exactly `1 + 1.5*cost_pressure + 4*pad_pressure + 5*high_pressure + 0.2*shape_pressure` using headroom definitions.
5. Sort candidates by `(-score, dpad, dcost, i, j)`. Greedily accept disjoint pairs while rechecking running caps; merge all accepted pairs as one round.
6. Run reference phases `(cost_fraction,pad_fraction,seq_fraction,window)` = `(0.94,0.94,0.965,12)`, `(0.975,0.97,0.980,24)`, `(1.0,0.99,0.990,40)`, at most **24 merge rounds per phase**. Absolute bucket budgets/targets are Task parameters.

## Checks
Every request remains in exactly one batch after each round. Do not replace this search with generic bin packing even if another packing gives better metrics.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

