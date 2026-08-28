---
name: pddl-unified-planning-load
description: "Load paired PDDL domain and problem files for IPC-style automated planning into a Unified Planning problem object. Use when a planning task supplies separate domain/problem paths and downstream planning must reproduce a Unified Planning + Pyperplan reference pipeline: read the paths from the current task metadata, call PDDLReader.parse_problem(domain_path, problem_path), and abort on parse failure."
---

# PDDL Unified Planning Load

Use this SKILL for the parsing stage of a PDDL planning workflow when the current task provides a domain file and a problem file.

## Dependency precheck

Run:

```bash
bash scripts/ensure_dependencies.sh
```

If the dependency is missing and installation is permitted:

```bash
bash scripts/ensure_dependencies.sh --install
```

Do not continue until `unified_planning` imports successfully.

## Inputs

Obtain these values from the current Task/Instruction or its task manifest; do not hard-code paths in this SKILL:

- `<domain_path>`: path to the PDDL domain file.
- `<problem_path>`: path to the PDDL problem/instance file.

## Reference procedure

Use one parsing operation with `unified_planning.io.PDDLReader`:

```python
from unified_planning.io import PDDLReader

reader = PDDLReader()
problem = reader.parse_problem(domain_path, problem_path)
```

Use the domain path as the first argument and the problem path as the second argument. Return the resulting Unified Planning `Problem` object unchanged to the planning stage.

Do not replace this parser with a handwritten PDDL parser or a different planning framework when following this procedure.

## Checks

- Both paths must resolve to readable files before parsing; otherwise abort this task instance.
- `parse_problem(...)` must complete without an exception and return a problem object; a parser exception is a hard failure for that instance.
- Preserve the parsed model as returned by Unified Planning. Do not rewrite actions, objects, predicates, initial state, or goals between parsing and planning.
