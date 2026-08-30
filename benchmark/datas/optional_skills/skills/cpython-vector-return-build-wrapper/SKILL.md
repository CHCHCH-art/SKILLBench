---
name: cpython-vector-return-build-wrapper
description: "Implement the portfolio expected-return dot product beside the risk kernel, build the native extension in place, and expose thin Python wrappers for the task API."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Expected return kernel is the direct dot product `sum_i weights[i]*expected_returns[i]` after equal-length validation; do not introduce normalization or NumPy conversion.
2. Define CPython methods for risk and return and propagate type/dimension errors as Python exceptions.
3. Build with a minimal setuptools extension via `build_ext --inplace`; bind module/function names from `Instruction.md`.
4. Python wrapper functions import the compiled module and delegate directly. Run Task-provided functional/benchmark checks if available, but do not alter the mathematical result to optimize benchmark behavior.
5. If native compilation or import fails, abort rather than falling back to the slower baseline implementation when the Task requires the extension.

## Checks

Require equal nonnegative lengths for weights and expected-return sequences and successful finite numeric conversion of every element before computing the dot product. The compiled extension must export the Task-bound method/module names, `build_ext --inplace` must succeed, and the Python wrapper must import that compiled module and delegate without changing arguments or results. A basic invocation must return a finite scalar for valid finite inputs and propagate conversion/dimension errors for invalid inputs. Compilation/import/symbol mismatch or nonfinite kernel output aborts; do not fall back to a different implementation when the native extension is required.
