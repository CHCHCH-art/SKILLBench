---
name: protein-sample-direct-reference-lookup
description: "Populate a task matrix of protein-by-sample expression values with direct Excel formulas after uniquely resolving protein IDs and sample names in a raw data sheet."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind source/task sheet names and all target ranges from `Instruction.md`; do not make the baseline workbook's coordinates permanent SKILL constants.
2. Build `protein_id -> [source rows]` from the first source-ID column and `sample_name -> [source columns]` from the source header row. Require every target protein and target sample to resolve **exactly once**.
3. Read target protein IDs and sample names from the Task-defined matrix labels.
4. For each destination matrix cell, write a direct absolute reference formula `='<data_sheet>'!$<source_cell>` to the uniquely resolved raw value. The reference does not use INDEX/MATCH despite the Task allowing it.
5. Abort on missing/duplicate identifiers and do not copy expression values as hard-coded numbers.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
