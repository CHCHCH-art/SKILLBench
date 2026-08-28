---
name: demographic-pdf-excel-normalization-join
description: "Normalize demographic population tables from PDF and income records from Excel, then inner-join them on a shared region code for downstream pivot reporting."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind input files and source field mapping from `Instruction.md`; do not embed the Task's concrete filenames/field names into reusable code.
2. PDF population extraction: for every page/table/row, accept rows with at least four cells whose first cell is all digits. Parse region code as integer, strip name/state strings, and remove thousands separators before integer population conversion; empty population becomes zero.
3. Read income Excel with pandas. For the Task-specified income numeric columns, stringify, remove commas, and `to_numeric(errors="coerce")`.
4. Inner-merge population and income on the Task region code. If both sources contain a duplicate region-name column, preserve the population-side name and drop the suffixed income-side duplicate.
5. Abort when the inner join is empty; do not outer-join or impute missing regions.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
