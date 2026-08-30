---
name: powerlifting-workbook-column-formula-population
description: "Populate a designated workbook sheet with the documented source columns needed for a powerlifting coefficient, add row formulas for lifted total and coefficient, and preserve workbook structure/styles through LibreOffice/openpyxl processing."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind workbook path, source/work sheet names, documented required source columns, requested formula columns, and computation precision from the current task specification plus the Task's data documentation. Do not hardcode those Task column/sheet names in this SKILL.
2. The reference workflow can convert/inspect the workbook through LibreOffice FODS when needed to robustly determine source columns. Preserve source row order and copy the lifter identity plus all Task-required coefficient inputs into the work sheet with their original header names/order.
3. Clear/rebuild the designated work area rather than appending stale rows. Add the Task-defined total-lift column immediately after copied inputs and fill each data row with an Excel formula summing the relevant lifted components.
4. Add the coefficient column after total and fill every data row with an Excel formula implementing the reference coefficient calculation. Use the Task-provided rounding precision as a formula parameter.
5. Save, force calculation/round-trip via LibreOffice under the reference workflow, and verify formulas remain present rather than replaced by hard-coded results.

## Checks
Row count/order must match source competitors and all Task-required source headers must be present before formula generation.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

