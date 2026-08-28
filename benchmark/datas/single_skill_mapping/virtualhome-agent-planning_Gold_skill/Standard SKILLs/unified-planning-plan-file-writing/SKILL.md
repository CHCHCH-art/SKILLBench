---
name: unified-planning-plan-file-writing
description: "Serialize a generated PDDL plan to the task-requested output path with Unified Planning's PDDLWriter. Use after a PDDL problem has been parsed and a plan generated: read the destination path from the current task metadata, construct PDDLWriter(problem), and call write_plan(plan, filename=output_path) so action/object spellings follow the parsed model."
---

# Unified Planning Plan File Writing

Use this SKILL for the final serialization stage of the reference PDDL planning pipeline.

## Dependency precheck

Run:

```bash
bash scripts/ensure_dependencies.sh
```

If installation is permitted and required:

```bash
bash scripts/ensure_dependencies.sh --install
```

## Inputs

Obtain the output destination from the current Task/Instruction or task manifest rather than embedding a filename here.

- `<problem>`: the same parsed Unified Planning `Problem` object used for planning.
- `<plan>`: the plan returned by the one-shot Pyperplan stage.
- `<output_path>`: task-provided destination path for this instance.

## Reference procedure

Write the plan through `unified_planning.io.PDDLWriter` bound to the parsed problem:

```python
from unified_planning.io import PDDLWriter

writer = PDDLWriter(problem)
writer.write_plan(plan, filename=output_path)
```

Use the same `problem` object that produced the plan. Do not hand-format the plan or rename action/object symbols.

The reference procedure does not create parent directories or change the requested destination path. The surrounding task environment is expected to provide a writable destination.

## Checks

- `<plan>` must not be `None`; if plan generation failed, do not emit a fabricated plan file.
- The parent location of `<output_path>` must already be writable. If `write_plan` raises an I/O error, abort that task instance rather than redirecting output elsewhere.
- After `write_plan` returns, `<output_path>` must exist and be non-empty. Serialization failure is a hard failure.
- Preserve the writer's action/object spelling and one-plan-action-per-line representation; do not post-process names or reorder actions.
