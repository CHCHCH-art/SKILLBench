---
name: uno-two-key-index-match-population
description: "Use LibreOffice UNO to discover a source worksheet schema and populate task cells with two-condition INDEX/MATCH formulas keyed by series code and year."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind workbook/sheet names, source row range, target year labels, series-code cells and destination blocks from `Instruction.md`.
2. Launch a private headless LibreOffice process using a temporary user profile and ephemeral localhost UNO port; poll connection for up to **20 s** at 0.1 s intervals.
3. Require exactly the Task's existing sheets; do not add sheets. Discover the source header row by scanning early rows for all target years and discover the series-code column by normalized header text. Do not assume a fixed source column for years/codes.
4. Within the Task-specified source row range, build unique series-code→row mapping and require every requested code.
5. Write formulas of the reference form `INDEX(source_matrix; MATCH(task_series_code; source_series_codes;0); MATCH(task_year; source_header;0))`, using Calc semicolon separators and absolute references. Bind all concrete ranges from Instruction.
6. Do not write looked-up numbers directly; formulas are required.

## Checks

Require exactly one source row for every requested series code, one discovered header column for every requested year, and a formula in every Task-required destination cell. After LibreOffice recalculation, each formula must resolve to a non-error cached value while the formula text remains present. Ambiguous duplicate keys, missing years/codes, `#N/A`/other formula errors, or lost formulas abort the output rather than falling back to direct value insertion.
