---
name: pyperplan-oneshot-plan-generation
description: "Generate a sequential plan for a parsed PDDL planning problem with the exact reference planner binding used by a Unified Planning pipeline. Given the upstream Unified Planning Problem, open OneshotPlanner(name='pyperplan'), call planner.solve(problem), and use result.plan directly; do not substitute another planner or fallback search method."
---

# Pyperplan One-Shot Plan Generation

Use this SKILL after the PDDL domain/problem pair has been parsed into a Unified Planning `Problem` object.

## Dependency precheck

Run:

```bash
bash scripts/ensure_dependencies.sh
```

If required and installation is permitted:

```bash
bash scripts/ensure_dependencies.sh --install
```

The check must confirm both Unified Planning and the `pyperplan` engine plugin are available.

## Input

- `<problem>`: the `unified_planning.model.Problem` object produced by the PDDL loading stage.

## Reference planner decision

The planner name is a reference decision, not a Task parameter: use `pyperplan` through Unified Planning's one-shot planner interface.

Execute exactly this planning pattern:

```python
from unified_planning.shortcuts import OneshotPlanner

with OneshotPlanner(name="pyperplan") as planner:
    result = planner.solve(problem)
plan = result.plan
```

The reference procedure performs a single `solve` call and returns `result.plan`. It does not configure a second planner, portfolio, timeout policy, heuristic override, or custom search strategy.

## Checks

- Creating `OneshotPlanner(name="pyperplan")` must succeed. If the engine is unavailable, stop and repair the dependency rather than choosing a different engine.
- `planner.solve(problem)` must return a result object. If `result.plan` is `None`, treat the instance as a planning failure; do not invent actions or fall back to a different planner when reproducing this recipe.
- Pass the returned plan object unchanged to the plan-writing stage. Do not rename actions or objects.
