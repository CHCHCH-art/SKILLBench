---
name: pddl-pyperplan-baseline-validation
description: "Load task-described PDDL planning instances, solve each with Unified Planning pyperplan plugin defaults, and validate the resulting sequential baseline plan as the quality guard for a later grounded portfolio."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Read the task-list JSON path/schema and each domain/problem/output path from the current task specification. Resolve absolute inputs directly; for relative inputs the reference checks its application root then root fallback. Create output parents as needed.
2. Parse each original problem with `PDDLReader`. Run `OneshotPlanner(name="pyperplan")` with **plugin defaults** (no search or heuristic parameters) to produce the baseline.
3. Validate the baseline with `PlanValidator(problem_kind=..., plan_kind=...)`; require status `VALID`. Record baseline action count and validation status.
4. Compute input SHA-256 values for the final manifest/audit path.

## Checks
A missing plan or invalid baseline is a hard error; later portfolio plans are never allowed to bypass baseline validity.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

