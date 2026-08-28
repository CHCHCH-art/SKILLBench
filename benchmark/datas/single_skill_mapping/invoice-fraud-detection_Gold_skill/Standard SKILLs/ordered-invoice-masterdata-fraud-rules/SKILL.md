---
name: ordered-invoice-masterdata-fraud-rules
description: "Fuzzy-resolve invoice vendors and apply the reference first-failure fraud checks against approved vendors and purchase orders."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind vendor/PO table column names and Task amount tolerance from `Instruction.md`/input schema. Build vendor records keyed by vendor name and PO records keyed by PO number.
2. Fuzzy vendor match uses RapidFuzz `fuzz.ratio`; accept only a best score **strictly greater than 80**. Otherwise emit the Task's unknown-vendor reason and stop evaluating that invoice.
3. Apply remaining checks in this exact first-failure order: payment identifier equals approved vendor record; PO exists; absolute amount difference is within the Task-provided tolerance; PO vendor ID equals resolved vendor ID.
4. On the first failed rule append one fraud record and `continue`; invoices passing every check are absent from the fraud report.
5. Preserve source page number and parsed invoice fields in each flagged record, mapped to Task-requested output names.

## Checks

For each invoice, the fuzzy-match result must be either absent or a finite score/name pair; a score `>80` must resolve to an existing vendor record before later checks run. Apply the fraud rules strictly in the stated first-failure order and emit at most one fraud reason per invoice. PO amount comparisons must use finite numeric values and the Task-bound tolerance; PO/vendor identifiers used in equality checks must come from the loaded master data. Passing invoices must not appear in the fraud report. Missing required master-data fields, inconsistent resolved keys, nonfinite amount data, or multiple reasons for one invoice aborts rule evaluation rather than reordering checks or applying a fallback matcher.
