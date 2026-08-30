---
name: generation-aware-dp-batch-splitting
description: "Split requests sharing one LLM sequence shape into generation-length batches by exact dynamic programming over the reference decode-cost arithmetic series."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference cost
Sort a shape bucket by `G`. For interval `[l,r]`, let `n=r-l+1`, `Smax=max(s_rep, max S_i)`, and because G is sorted `Gmax=G_r`.

`sum_sq_arith(a,n) = n*a^2 + a*n*(n-1) + n*(n-1)*(2*n-1)/6`.

Per-request decode cost is
`Cdecode(S,G) = 1.0*sum_sq_arith(S,G) + (0.5*HIDDEN)*(G*S + G*(G-1)/2)`.
Segment cost is
`Cseg(l,r)=n*Cdecode(Smax,Gmax)+10_000_000`.
The 10,000,000 batch overhead and coefficients 1.0/0.5 are reference defaults.

## DP
Set `dp[0]=0`; for r=1..N evaluate every l=1..r:
`candidate=dp[l-1]+Cseg(l-1,r-1)`. Keep the strictly lowest candidate and predecessor. Backtrack predecessors and reverse segments. Emit batches in ascending representative-shape order with deterministic sequential batch IDs; bind exact output ID/schema from Instruction.

## Checks

Require the input bucket to be sorted by nondecreasing generation length before using `G_r` as the interval maximum. For every candidate interval, `Smax >= s_rep`, `Gmax >= 0`, and `Cseg` must be finite and nonnegative. The DP must produce a finite `dp[N]`, every predecessor must satisfy `0 <= pred[r] < r`, and backtracking must cover each request exactly once with nonoverlapping contiguous intervals. Recompute the summed segment cost from the emitted partition and require it to equal `dp[N]` within floating-point tolerance; otherwise abort rather than emitting a malformed batch split.
