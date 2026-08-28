---
name: dcopf-reserve-lmp-solve
description: "Solve a DC optimal-power-flow market with generator reserves and extract nodal LMPs, reserve marginal price, costs, and binding lines using the exact CVXPY/CLARABEL conventions ."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Bind network path, counterfactual parameters, Task binding-line threshold/output schema, and scenario fields from the current task specification. Reference package versions are NumPy `1.26.4`, SciPy `1.11.4`, and CVXPY `1.4.2`.
2. Build the bus susceptance matrix from branches with nonzero reactance using `b=1/x`. Choose the first type-3 bus as slack and set its angle to zero.
3. Decision variables are per-unit active generation `Pg`, reserve `Rg` in MW, and bus angle `theta`. Minimize the quadratic generator cost evaluated on `Pg * baseMVA`.
4. For each bus constrain `sum(Pg_at_bus) - Pd/baseMVA == B[i,:] @ theta`. Enforce generator min/max. Enforce `Rg>=0`, `Rg<=reserve_capacity`, and `Pg_MW + Rg <= Pmax_MW`; require system `sum(Rg) >= reserve_requirement`.
5. For every positive-rating, nonzero-reactance branch impose `-rate <= (1/x)*(theta_f-theta_t)*baseMVA <= rate`.
6. Solve with `cp.CLARABEL` and require status exactly `optimal` under the reference check.
7. Extract each balance equality dual and multiply it by `baseMVA` for the reference LMP convention; round reported LMPs to 2 decimals. The reserve requirement dual is used directly as reserve MCP and rounded to 2 decimals.
8. Recompute line loading from solved angles. Apply the Task-provided binding threshold if specified by the current Task; the solve procedure's comparison and strictness must otherwise be retained.

## Checks

Confirm total generation/load/reserve consistency and recompute all branch flows before classification as binding.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

