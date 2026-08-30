---
name: cavity-wigner-grid-export
description: "Trace a solved light-matter steady state to the cavity subsystem, evaluate QuTiP Wigner values on a task-specified phase-space grid, and export one headerless numeric CSV per task case in reference order."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind phase-space x/p bounds, grid dimensions, case order, filenames, and output location from the current task specification.
2. Partial-trace the full steady state with subsystem index so the **cavity** density matrix is retained.
3. Build linearly spaced x and p arrays from the Task bounds/counts and call QuTiP's Wigner function on that grid without introducing an alternate normalization.
4. Save the resulting numeric matrix with `numpy.savetxt(..., delimiter=",")`, no header/index. Process cases in Task order. The reference output-directory lookup uses environment `OUTPUT_DIR` when set and otherwise the current working directory; bind to the Task destination as needed.

## Checks
Each file must have exactly the Task grid shape and finite numeric entries. Do not transpose/flip the Wigner array unless the procedure explicitly requires it.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

