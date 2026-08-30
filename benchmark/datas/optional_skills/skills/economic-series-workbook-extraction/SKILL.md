---
name: economic-series-workbook-extraction
description: "Recover annual economic time series from mixed XLS/XLSX workbooks using LibreOffice conversion, direct OOXML sheet extraction, reference worksheet scoring, annual/quarter parsing, and CPI sheet scoring before detrending."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Bind workbook paths, requested series names, analysis year range, final-year handling, and source-specific title phrases from the current task specification.
2. Convert legacy XLS inputs to XLSX with headless LibreOffice in an isolated profile. Copy already-XLSX inputs unchanged into the normalized workbook area.
3. Parse XLSX ZIP/XML directly: resolve workbook relationships, shared strings, cell references, and inline strings; emit one tab-separated file per sheet plus a manifest. Preserve sheet ordinal.
4. For each ERP-style series, score candidate sheets as `10 * annual_label_hits + quarter_label_hits + 1000 * title_phrase_present_in_first_12_rows`. Require reference minimum score **100**. Annual labels match the reference `YYYY.` form; quarter labels accept year-prefixed first-quarter rows plus continuation Roman numerals.
5. Use annual observations for all Task-requested years before the final year. For the final Task year, average all available quarter values found by the reference parser.
6. For CPI-style data, score candidate sheets as `year_hits + 5 * value_hits`; use reference minimum score **20**. Parse numeric year cells, including Excel date-like representations handled by the script, and aggregate to one annual value per Task year with the reference annual mean rule.
7. Reject any missing Task-requested year before detrending.

## Checks

Persist selected source-sheet identity and final-year quarter count. Verify exactly one normalized value per requested year for every series.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

