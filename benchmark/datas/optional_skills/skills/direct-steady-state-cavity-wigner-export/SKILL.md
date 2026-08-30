---
name: direct-steady-state-cavity-wigner-export
description: "Solve each open-Dicke Liouvillian with QuTiP direct steady-state method, partial-trace to the cavity, compute task-defined Wigner grids, and export one CSV matrix per loss case."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. For each total Liouvillian call `steadystate(L, method="direct")`. Process the fourth configured case first, then cases one through three; preserve case-to-output association regardless of execution order.
2. Trace out the spin subsystem with `rho_ss.ptrace(0)` to obtain the photonic state.
3. Bind Wigner x/p range and grid size from `Instruction.md`; construct one `linspace` axis and call `qutip.wigner(cavity_state, xvec, xvec)`.
4. Bind case filenames/output directory from Instruction. Save each dense Wigner array with `numpy.savetxt(..., delimiter=",")` and no header/index.
5. Validate each matrix has the Task grid shape and only finite values. A failed steady-state or Wigner computation aborts that case/output; do not switch solver method.

## Checks

For every configured case, require `steadystate(..., method="direct")` to return a finite density operator with trace approximately 1. After `ptrace(0)`, require the cavity state dimension to match the photon cutoff and its trace to remain approximately 1. The Wigner array must have exactly the Task grid shape and contain only finite values; each case must map to its own requested output file without permutation. Any steady-state failure, nonfinite state, trace failure, shape mismatch, or write failure aborts that case rather than switching solver method or silently emitting a partial matrix.
