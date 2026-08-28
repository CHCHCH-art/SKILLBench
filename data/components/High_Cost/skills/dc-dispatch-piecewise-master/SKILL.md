---
name: dc-dispatch-piecewise-master
description: "Build and solve the reference sparse DC economic-dispatch linear master with piecewise generator costs, reserve availability, connected-network checks, and HiGHS settings before exact-cost refinement."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind network fields, Task reporting count/tolerances if supplied, and output schema from the current task specification. The reference treats **all branch rows as active** regardless of source status flags, then requires the active network to be connected.
2. Build the canonical sparse DC model and branch sensitivity/load-flow equations from the source data. Piecewise-linearize each generator's quadratic cost with **24 equal-width segments**.
3. Include generation, segment, reserve-availability, balance, branch, generator, and system reserve constraints exactly as specified below. Solve with `scipy.optimize.linprog(method="highs", options={"presolve": True})`.
4. The reference physical feasibility tolerance is **0.08 MW** and its stored optimality tolerance is **`2e-6`**; preserve their roles where the script applies them.
5. Convert the LP result to a feasible incumbent dispatch and compute its **exact quadratic** generator cost rather than reporting the piecewise objective as final cost.

## Checks
Require network connectivity, LP success, generation balance, branch limits, generator bounds, and sufficient reserve headroom before refinement.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

