---
name: c-portfolio-risk-return-kernel
description: "Implement the reference C numerical kernels for portfolio return and covariance risk using direct double-precision loops and Python-callable raw buffers, preserving operation order closely enough for task tolerance and large-asset performance."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind provided skeleton/source/module paths, array sizes, accuracy requirement, and build command from the current task specification.
2. Portfolio return: accumulate `sum_i weights[i] * expected_returns[i]` in a C `double` loop.
3. Portfolio risk: compute the quadratic form with the reference nested-loop order. For each row `i`, accumulate `row_sum = sum_j covariance[i*n+j] * weights[j]`, then accumulate `variance += weights[i] * row_sum`; return `sqrt(variance)`.
4. Use contiguous row-major `double` buffers received from the Python extension interface; index covariance as `i*n+j`. Do not replace the reference loop with a different BLAS/reduction whose floating summation order changes the expected result.
5. Complete the extension entry points/error handling in the Task skeleton and compile using the Task-provided extension build procedure.

## Checks
Compare both kernels against the Task baseline over representative sizes with the Task-provided tolerance before benchmarking speed.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

