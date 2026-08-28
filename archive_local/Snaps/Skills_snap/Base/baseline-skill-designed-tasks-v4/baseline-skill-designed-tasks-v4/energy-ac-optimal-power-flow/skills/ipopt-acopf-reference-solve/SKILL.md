---
name: ipopt-acopf-reference-solve
description: "Solve a least-cost AC-feasible optimal power flow for ISO day-ahead base-case voltage-profile planning by applying the reference IPOPT initialization, convergence tolerances, variable ordering, and failure behavior."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Variable blocks are voltage magnitudes, voltage angles, generator active powers and generator reactive powers in the same deterministic array order used by network input.
2. Initialize all voltage magnitudes to 1, angles to 0, active/reactive generation by clipping reference starting values to their bounds, and force the slack/reference angle to zero.
3. Use IPOPT with reference options: `max_iter=2000`, `tol=1e-7`, `acceptable_tol=1e-5`, `mu_strategy="adaptive"`, IPOPT print level 5, and outer `print_time=false`.
4. Solve once. Do not add warm-start sweeps, convex relaxations, or alternate solvers.
5. If IPOPT does not return usable finite primal variables, abort reporting rather than fabricating an optimal status.

## Checks

Accept the solve only if IPOPT returns a usable finite primal vector with exactly the expected variable length. Re-evaluate all variable bounds and nonlinear constraint residuals at that vector before reporting; the reference report step performs the detailed feasibility recomputation. If IPOPT fails, returns NaN/Inf, or the state cannot be unpacked deterministically, abort. Do not retry with another solver, relaxation, or altered tolerances.
