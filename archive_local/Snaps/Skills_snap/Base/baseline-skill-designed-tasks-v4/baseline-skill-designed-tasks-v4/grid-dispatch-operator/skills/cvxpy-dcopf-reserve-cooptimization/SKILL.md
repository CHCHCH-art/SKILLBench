---
name: cvxpy-dcopf-reserve-cooptimization
description: "Solve the reference quadratic DC dispatch with generator reserve co-optimization, susceptance-network balance, line ratings and capacity coupling in CVXPY."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind MATPOWER-style network and reserve arrays from Task input. Build the dense bus susceptance matrix using branch reactance/tap and bus-number mapping as specified below; use the first type-3 bus as slack and fix its angle to zero.
2. Decision variables are per-unit `Pg`, MW `Rg`, and bus angles. Minimize polynomial generator cost evaluated on `Pg*baseMVA`.
3. Enforce `Pmin/baseMVA <= Pg <= Pmax/baseMVA`; `0<=Rg<=reserve_capacity`; `Pg*baseMVA + Rg <= Pmax`; and `sum(Rg)>=reserve_requirement`.
4. Power balance is `generation_pu - load_pu = B @ theta`.
5. For each branch with nonzero reactance and positive rating, constrain `b*(theta_f-theta_t)*baseMVA` to ±rating.
6. Solve once with CVXPY **CLARABEL**. The dependency versions used by the reference are NumPy 1.26.4, SciPy 1.11.4 and CVXPY 1.4.2.

## Checks

Require exactly one usable slack bus, finite network/cost inputs, nonzero reactance for every modeled branch, and compatible dimensions for bus, generator, branch, reserve, and cost arrays. After CLARABEL returns, require an optimal/usable status and finite `Pg`, `Rg`, and `theta`. Recompute generator bounds, reserve bounds/requirement, `Pg*baseMVA + Rg <= Pmax`, nodal balance, every rated-line flow, and the zero slack angle within solver tolerance. Any violated feasibility condition or unusable solver status aborts reporting; do not retry with another solver or alter the model.
