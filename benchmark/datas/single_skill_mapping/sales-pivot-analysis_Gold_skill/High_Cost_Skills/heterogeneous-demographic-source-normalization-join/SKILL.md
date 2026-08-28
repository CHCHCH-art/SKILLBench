---
name: heterogeneous-demographic-source-normalization-join
description: "Prepare a demographic tabular relation for Excel pivot reporting from population-style PDF tables and income-style Excel data: normalize keys/numerics/text, select the qualifying worksheet, join through SQLite, and preserve deterministic source order."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference normalization/join procedure
1. Bind PDF/Excel paths, required source fields, and join key from the current task specification.
2. Extract PDF tables with `pdfplumber.extract_tables()`. For each candidate row, parse the key/code from the reference leading position, normalize text fields, parse the required numeric population-like position under this procedure number parser, skip structurally invalid rows, and attach monotonically increasing PDF source sequence.
3. Open the Excel workbook `data_only=True`. Normalize headers and choose the **first worksheet** whose normalized header set contains every Task-required income/earner field. Parse key and numeric fields with missing-value, parentheses, comma, and currency conventions; attach Excel source sequence.
4. Load both normalized sources to SQLite and inner-join on the Task key. Order joined records by PDF source sequence first, then Excel source sequence.

## Checks

Require at least one valid row from each source and a nonempty inner join. If no worksheet satisfies the required header set, parsing eliminates all rows, or the join is empty, abort rather than switching to a different join type or fabricating keys.

