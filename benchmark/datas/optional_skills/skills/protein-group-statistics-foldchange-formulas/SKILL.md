---
name: protein-group-statistics-foldchange-formulas
description: "Write group mean, sample-standard-deviation, log2 fold-change and fold-change formulas over a task-populated log2 expression matrix using the baseline spreadsheet formula recipe."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind group-label range, expression ranges and result ranges from `Instruction.md`. Normalize group labels with trim+casefold and require both task groups, with at least two samples per group.
2. Mean formula is `SUMIF(group_range, group_ref, value_range)/COUNTIF(group_range, group_ref)`.
3. Sample SD formula is `IF(n>1, SQRT((SUMPRODUCT(--(group_range=group_ref), value_range*value_range)-n*mean_cell^2)/(n-1)),0)`.
4. Identify fold-change vs log2-fold-change output columns by casefolding their header and removing nonalphanumeric characters; recognize `log2` plus `fold/fc` as log2FC and `foldchange`, `fc`, or `fold` as FC.
5. Write `log2FC = treated_mean - control_mean`; write `FC = POWER(2, log2FC)`.
6. Set workbook calculation mode auto, fullCalcOnLoad and forceFullCalc before saving the formula workbook.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
