---
name: parquet-to-fasttext-supervised-text
description: "Convert a labeled text Parquet training dataset into fastText supervised line format without changing labels or review text."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind training Parquet path and label/text columns from `Instruction.md`/dataset schema.
2. Read the entire training Parquet with pandas.
3. For every row write exactly one UTF-8 line `__label__<label> <text>
` in dataframe order. The reference performs no normalization, train/validation split, shuffling, escaping or text cleanup.
4. Validate output row count equals the dataframe row count; abort on missing required columns rather than guessing them.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
