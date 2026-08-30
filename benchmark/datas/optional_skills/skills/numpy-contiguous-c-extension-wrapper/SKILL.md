---
name: numpy-contiguous-c-extension-wrapper
description: "Wrap a C portfolio numerical extension with NumPy input normalization, shape validation, contiguous float64 conversion, module build/import, and baseline-equivalence/performance checks."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind Task skeleton/module names and expected API signatures from the current task specification.
2. Convert weights, expected returns, and covariance inputs with `numpy.ascontiguousarray(..., dtype=float64)` before crossing the C boundary. Validate dimensional compatibility and square covariance shape.
3. Pass raw contiguous data and asset count into the C kernels; convert returned C doubles to ordinary Python floats.
4. Build/import the extension through the Task-specified setup process. Do not introduce an alternate pure-NumPy fast path: the required procedure is the completed C extension.
5. Run the Task's correctness benchmark first, then its large-size speed benchmark and maximum-size case.

## Checks
Ensure wrapper copies/normalization do not mutate caller arrays. Numerical comparison uses unrounded outputs and the Task's tolerance.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

