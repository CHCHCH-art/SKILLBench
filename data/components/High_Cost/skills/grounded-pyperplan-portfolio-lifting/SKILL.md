---
name: grounded-pyperplan-portfolio-lifting
description: "Ground a Unified Planning PDDL problem, serialize/reparse it, run the exact external pyperplan search/heuristic portfolio, validate grounded plans, lift them back to original actions, and retain only valid alternatives."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Compile the original problem with Unified Planning `Compiler(name="up_grounder", CompilationKind.GROUNDING)` and require a non-null grounded problem.
2. Serialize grounded domain/problem with `PDDLWriter`, then immediately reparse both with `PDDLReader`; record original, grounded, and round-tripped action counts.
3. Run the external pyperplan CLI portfolio with these fixed members: `gbf + hmax`, `wastar + hff`, and `astar + lmcut`. Each member runs at the external CLI/process boundary and retains process metadata/plan artifact.
4. Parse each serialized grounded plan against the round-tripped grounded problem and validate it. Lift every grounded action by resolving its serialized writer name, requiring no unexpected actual parameters, then calling `grounding_result.map_back_action_instance`.
5. Validate each lifted sequential plan against the **original** problem. Retain only alternatives that pass both grounded and lifted validation; record failures instead of aborting the entire portfolio.
6. If grounding/portfolio setup fails as a whole, preserve the reference fallback status and allow the validated baseline guard to remain available.

## Checks
No plan may be compared for selection until it has been lifted and validated in the original model.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

