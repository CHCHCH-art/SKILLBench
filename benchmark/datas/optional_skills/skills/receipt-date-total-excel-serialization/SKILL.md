---
name: receipt-date-total-excel-serialization
description: "Parse receipt dates and totals from OCR text using normalization, context priority, candidate scoring, monetary Decimal formatting, then emit exactly the task-defined single-sheet workbook in filename order."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Parsing procedure
1. Bind Task date/total output fields, keyword and exclusion lists, sheet name, null convention, and output path from the current task specification; do not copy those Task strings into the SKILL as constants.
2. Date parsing normalizes common OCR confusions (`O/o -> 0`, `I/l -> 1`) before trying the reference set of common date formats. Accept only reference sanity years **2000 through 2030**. Collect regex matches in source order and prefer matches carrying Task-defined date-context keywords; otherwise use the first valid date.
3. For amount parsing, skip lines matching Task exclusion keywords. Locate Task total-keyword matches in their Task priority order and parse monetary tokens including comma grouping into `Decimal`. The reference converts that ordering to candidate priority weights **50/40/30/20** for increasingly general same-line categories and **10** for the next-line fallback; choose the first candidate after descending priority/stable ordering.
4. Format successful money values with Decimal `ROUND_HALF_UP` to exactly the Task-requested decimal places. Format successful dates in the Task-requested canonical form.
5. Create exactly the Task-specified worksheet and columns, no extras, with one row per sorted source filename.

## Checks
Reopen the workbook and verify one sheet, exact header sequence, sorted filenames, and exact textual decimal precision. Failed field extraction remains null rather than zero/empty guessed content.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

