---
name: arpack-liouvillian-steady-state
description: "Solve a sparse open-system Liouvillian steady state with the reference ARPACK near-leading-eigenvector procedure, physical symmetrization/trace normalization, and strict eigenvalue/residual verification."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Convert the Liouvillian to the sparse matrix representation expected by SciPy ARPACK. Use `scipy.sparse.linalg.eigs` with `k=4`, `which="LR"`, `tol=1e-11`, `maxiter=100000`, and `ncv=40`; do **not** use shift-invert `sigma`.
2. Use the vectorized ground-spin/vacuum density operator as the reference `v0` seed under this procedure vectorization convention.
3. From returned eigenpairs choose the candidate corresponding to the steady state under the reference leading-real/eigenvalue-near-zero selection. Reshape/vector-to-operator in the exact QuTiP ordering.
4. Hermitize the density matrix as `(rho + rho.dag())/2`, then normalize by its trace.
5. Require steady eigenvalue magnitude and explicit Liouvillian residual norm each to be at most **`1e-7`** under this procedure check.

## Checks
Reject nonfinite trace/eigenvectors and keep eigenvalue/residual diagnostics for each Task loss case.

