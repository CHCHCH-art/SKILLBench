---
name: quadratic-dispatch-outer-approximation-report
description: "Certify/refine economic dispatch with dense PTDF epigraph outer approximation of quadratic cost, then construct the report from rounded component values and stable branch-loading ranking."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference refinement
1. Build a dense PTDF LP with direct generation, reserve, and per-generator cost epigraph variables. Seed quadratic tangents at `Pmin`, midpoint, `Pmax`, and the feasible incumbent dispatch.
2. Solve up to **12** HiGHS master iterations. After each solve, evaluate exact quadratic cost; keep the best feasible incumbent and append tangents at the new dispatch.
3. Stop when `best_cost - master_lower_bound <= 0.05`. Treat a lower bound that exceeds the feasible best by more than the scripted `0.05` tolerance as an error.
4. Reporting rounds scalar generator output/reserve/cost/loads to **2 decimals**, with values whose rounded magnitude is below `0.005` represented as zero by the reference helper.
5. Rank eligible branches by descending loading using stable NumPy sorting and bind the requested report count from the current task specification (the current solve path itself takes its configured count before serialization).
6. Reference generation/reserve totals are sums of the **already rounded per-generator report values**, then rounded again; preserve that sequencing.

## Checks
Keep the exact incumbent cost and certified lower bound in audit data independently of rounded report totals.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

