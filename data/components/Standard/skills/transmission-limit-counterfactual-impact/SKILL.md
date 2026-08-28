---
name: transmission-limit-counterfactual-impact
description: "Run a single transmission-rating counterfactual on the reference DC market LP and report cost, LMP and congestion changes using the procedure’s rounded-comparison conventions."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind the target line, rating change and requested comparison count from `Instruction.md`.
2. Copy the base inequality RHS and change both the positive and negative line-limit rows for the selected line. Keep every other model coefficient, reserve condition and solver option identical.
3. Solve/report base and counterfactual independently with the same pricing procedure.
4. Reference cost reduction is computed from the **already rounded report costs**, not the hidden raw objectives.
5. LMP deltas are computed from the rounded per-bus LMPs. Sort delta ascending and take the requested number of leading buses.
6. The reference `congestion_relieved` convention is `was_binding_in_base AND not_binding_in_counterfactual`. Preserve that convention rather than redefining the Boolean from prose.

## Checks

Before the counterfactual solve, verify that only the positive and negative inequality-RHS entries for the Task-selected line are changed and every other model coefficient/RHS entry remains identical to the base case. Both base and counterfactual solves must pass the same pricing feasibility checks. Cost reduction must be recomputed from the already rounded report costs; per-bus LMP deltas must be computed from rounded LMPs, sorted ascending, and truncated to the Task-requested count. `congestion_relieved` must equal `base_binding AND NOT counterfactual_binding`. Any unintended model mutation, failed solve, nonfinite delta, ordering mismatch, or Boolean inconsistency aborts the comparison.
