---
name: reference-plan-selection-and-safe-write
description: "Select among validated PDDL plans with non-improvement quality guard and unusual maximum-length tie rule, then serialize, syntax-check, reparse, revalidate, and atomically publish the chosen plan."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Selection procedure
1. From valid lifted alternatives keep only plans whose action count is **greater than or equal to the validated baseline action count**.
2. If this set is nonempty, select with Python `max` on `(action_count, label)`: choose the **longest** non-improving plan, with lexicographically larger label breaking equal lengths. This selection rule is result-affecting; do not substitute shortest-plan optimization.
3. If no alternative meets that condition, choose the baseline under reference label `baseline-quality-guard`.
4. Validate the selected plan again against the original problem.
5. Write it to a temporary output with the original problem's `PDDLWriter`. Syntax guard requires every nonblank line to start/end with exactly one pair of parentheses (`count('(')==1` and `count(')')==1`).
6. Reparse the temporary on-disk plan using the writer's name resolver and validate it again. Only then `os.replace` the Task output.
7. Write the reference manifest containing model sizes, portfolio diagnostics, baseline/selection metadata, validation statuses, input/output SHA-256, and output action count.

## Checks
Do not select a shorter plan instead; the non-improvement/maximum rule is result-affecting behavior of this workflow.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

