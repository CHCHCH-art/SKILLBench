---
name: acopf-ipopt-reference-initialization
description: "Initialize and solve a least-cost AC-feasible operating point for an AC optimal-power-flow planning/reporting workflow using rectangular voltages, bounded generator/branch-flow starting values, fixed IPOPT options, and explicit post-solve feasibility checks."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Initialization procedure

1. Initialize voltage from input magnitude/angle when available under the reference data convention; use the stated fallback for missing/nonusable initial voltage values.
2. Convert to rectangular `E0=Vm0*cos(Va0)`, `F0=Vm0*sin(Va0)`. Initialize active/reactive generator variables from input generator values clipped to their feasible bounds.
3. Compute initial branch powers from the exact branch equations. For rated branches, clip **each** initial component `Pft,Qft,Ptf,Qtf` independently to `[-rate_pu, rate_pu]`; do not radially project the complex flow vector.
4. Solve with CasADi IPOPT using reference options: `ipopt.print_level=5`, `ipopt.max_iter=2000`, `ipopt.tol=1e-7`, `ipopt.acceptable_tol=1e-5`, and `ipopt.mu_strategy="adaptive"`.
5. Require an IPOPT success status under the reference status check; do not silently return the best iterate from a failed solve.

## Checks

Require an IPOPT success status, finite primal/objective values, and returned variables inside their declared bounds. Re-evaluate the objective and all physical branch equations from the returned primal vector; keep the maximum equality residual and inequality violation for audit and require them to meet the solver/task tolerances. Abort on failed solver status, non-finite values, bound violations, or unacceptable constraint residuals; do not return a best iterate from a failed solve.
