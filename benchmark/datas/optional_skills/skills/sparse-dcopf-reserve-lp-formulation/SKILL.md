---
name: sparse-dcopf-reserve-lp-formulation
description: "Build a sparse DC optimal-power-flow linear program with generator reserves, energy-reserve capacity coupling, line limits, and a fixed slack angle for market-pricing analysis."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference formulation
1. Bind network data and reserve requirement/capacities from the Task input. Require linear generation costs: abort if any quadratic coefficient magnitude exceeds `1e-12`.
2. For each nonzero-reactance branch set `b=1/x`. Add to `Bbus`: `+b/tap^2` at from/from, `+b` at to/to, and `-b/tap` on both off-diagonals; zero/absent tap is treated as 1. Build line-flow row `[+b/tap, -b]` only for positively rated lines.
3. Variable vector is `[Pg, Rg, phi]`. Objective uses linear generation cost `c1*Pg`; fixed `c0` is added only to the reported total cost.
4. Equality balance is `-Cg*Pg + Bbus*phi = -Pd`. Inequalities include `Pg+Rg<=Pmax`, `-sum(Rg)<=-reserve_requirement`, and positive/negative rated line-flow bounds.
5. Bounds: `Pmin<=Pg<=Pmax`, `0<=Rg<=reserve_capacity`; bus angles unbounded except the reference/slack angle fixed to zero.
6. Solve with `scipy.optimize.linprog(method="highs-ds")`, presolve enabled and primal/dual feasibility tolerances both `1e-7`.

## Checks

Require one consistent bus index for every generator/branch endpoint, nonzero reactance for every branch included in susceptance calculations, and matching dimensions for `Bbus`, generator-incidence matrices, equality rows, inequality rows, bounds, and objective vector. Reject any non-negligible quadratic generation-cost coefficient instead of approximating it. After solving, require HiGHS success and finite variables; recompute nodal balance, reserve requirement, `Pg+Rg<=Pmax`, rated-line limits, variable bounds, and the fixed slack angle within solver feasibility tolerance. Any violated model invariant aborts pricing/reporting rather than modifying the LP after the fact.
