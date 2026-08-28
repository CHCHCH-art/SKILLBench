---
name: pddl-task-manifest-plan-orchestration
description: "Orchestrate a batch of IPC-style PDDL planning instances from task metadata: iterate entries in order, bind each domain/problem/output path, invoke the parsing, Pyperplan planning, and plan-writing SKILLs in a fixed sequence, and stop on per-entry failure."
---

# PDDL Task-Manifest Plan Orchestration

Use this SKILL when one Task supplies multiple independent PDDL planning instances through JSON-like metadata.

## Dependency precheck

Run:

```bash
bash scripts/ensure_dependencies.sh
```

If required and installation is permitted:

```bash
bash scripts/ensure_dependencies.sh --install
```

## Task-provided metadata

Read the manifest location and field mapping from the current Instruction. For each entry bind:

- `<task_id>` when present, for identification/logging;
- `<domain_path>`;
- `<problem_path>`;
- `<output_path>`.

Concrete manifest filenames and key names are Task inputs and must not be fixed in this SKILL.

## Reference procedure

1. Load the task-entry collection and preserve its original order.
2. For the current entry, bind its domain, problem, and requested output paths. Do not carry paths or objects over from the previous entry.
3. Invoke the three child procedures in this exact order:
   - `pddl-unified-planning-load` with `<domain_path>, <problem_path>`;
   - `pyperplan-oneshot-plan-generation` with the returned problem object;
   - `unified-planning-plan-file-writing` with the same problem object, returned plan, and `<output_path>`.
4. Finish the current entry before advancing to the next. If parsing, planning, or writing raises an error, stop the batch at that failure; do not skip the entry or continue with stale state.

Equivalent orchestration skeleton:

```python
for entry in task_entries:
    domain_path = bind_domain(entry)
    problem_path = bind_problem(entry)
    output_path = bind_output(entry)

    problem = load_problem(domain_path, problem_path)
    plan = generate_plan(problem)
    save_plan(problem, plan, output_path)
```

Planner configuration, PDDL parsing details, and serialization details belong to the three child SKILLs and are not duplicated here.

## Checks

Every entry must provide all required bound paths. The child procedures must run exactly once per entry in parse → plan → write order, and the parsed problem/plan used for writing must belong to the same entry. After a successful entry, its requested output file must exist and be non-empty. Any child-stage exception is a hard batch failure; do not continue to later entries.
