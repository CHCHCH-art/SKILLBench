---
name: hp-cycle-correlation-verification
description: "Apply a Hodrick-Prescott cycle extraction by solving the reference normal equations and compute Pearson correlation with independent numerical verification. Use when the Task supplies the HP smoothing parameter and annual series are already aligned."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Bind the HP smoothing parameter and Task year range from the current task specification. Align the normalized annual series on exactly that ordered year sequence and apply the reference transformation (including logarithms where specified by the procedure).
2. Construct the HP second-difference penalty matrix `D` and solve the normal equation `trend = (I + lambda * D.T @ D)^(-1) y` using `numpy.linalg.solve`, not a different HP-filter implementation. Define `cycle = y - trend`.
3. Compute the infinity norm of the normal-equation residual `(I + lambda D.T D) @ trend - y`; the reference requires it to be at most **`1e-10`** for each series.
4. Center both cycle vectors and compute Pearson correlation manually as their dot product divided by the product of Euclidean norms. Treat a zero-variance cycle as an error.
5. Re-read/reconstruct the normalized inputs through the reference audit route and independently recompute the final correlation. Require absolute equality within **`1e-12`** (`rel_tol=0`).
6. Serialize only after all checks, using the Task-requested output representation.

## Checks

No rounded intermediate series may enter the HP system or correlation. Keep residual norms and the independently verified correlation as audit artifacts while computing.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

