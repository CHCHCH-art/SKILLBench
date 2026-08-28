---
name: spreadsheet-two-way-expression-lookup
description: "Fill a target workbook matrix with formulas that two-way match protein IDs and sample names against a raw expression sheet, using source-range discovery and INDEX/MATCH formula generation without hard-coding task coordinates."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind workbook, raw/task sheet names, target protein/sample ranges, and destination matrix from the current task specification.
2. Use a private headless LibreOffice/UNO session with an ephemeral port/profile. To infer the populated sample-header extent, scan columns `0..511`; reset `blank_run=0` on nonblank headers, increment it on blanks, and stop once `column>16` and `blank_run>=16`. To infer the protein-row extent, scan rows `1..9999` with the analogous rule, stopping once `row>32` and `blank_run>=32`. Do not assume the Task's stated dimensions are the only nonblank cells.
3. For each destination matrix cell, write a two-way `INDEX`/`MATCH` Calc formula: row match uses the current target protein ID against the raw protein-ID column; column match uses the current target sample header against the raw sample header row. Parameterize the actual sheet/range references, e.g. `$<data_sheet>.<matrix_range>`, from the current task specification.
4. Use Calc's semicolon argument separators under the reference UNO formula syntax. Recalculate the document after filling formulas.

## Checks
Inspect formula text and calculated values for corner cells; no expression value should be copied as a hard-coded number.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

