---
name: cpython-symmetric-quadratic-risk-kernel
description: "Implement portfolio risk in a CPython C extension by traversing only the upper triangle of a symmetric covariance matrix and accumulating a quadratic form without a NumPy matrix copy."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference kernel
1. Bind API names and validation requirements from `Instruction.md`. Convert the Python weights sequence to C doubles; covariance remains a Python sequence-of-sequences accessed with `PySequence_Fast`.
2. Allocate temporary vector `temp[n]=0`. For each `i`, add diagonal `S[i][i]*w[i]` to `temp[i]`. For every `j>i`, read only `S[i][j]`, add `Sij*w[j]` to `temp[i]` and `Sij*w[i]` to `temp[j]`.
3. Compute `risk_squared=sum_i w[i]*temp[i]`; return `sqrt(risk_squared)` according to the Task's portfolio-risk definition. This intentionally assumes covariance symmetry and does not read the lower triangle.
4. Validate matrix dimensions and conversion errors; free every allocated buffer/reference on failure. Abort on negative/nonfinite risk squared rather than silently taking absolute value.

## Checks

Require the weights vector length to equal both covariance dimensions and every accessed upper-triangular covariance entry/weight to convert to a finite C double. The temporary vector must have length `n`, and the accumulated `risk_squared = sum_i w[i]*temp[i]` must be finite and nonnegative before `sqrt`. This kernel intentionally reads only the diagonal and upper triangle; do not compare against or silently consume lower-triangular values as a repair. Dimension/conversion/allocation failure, nonfinite arithmetic, or negative risk squared aborts with a Python error rather than returning a fabricated risk.
