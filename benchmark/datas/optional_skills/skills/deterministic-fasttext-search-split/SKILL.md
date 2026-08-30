---
name: deterministic-fasttext-search-split
description: "Prepare a supervised fastText corpus with a deterministic BLAKE2b train/tune/selection split and train/evaluate the compact baseline representation before constrained autotuning."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind the Task training dataset path/columns/label convention and final model constraints from the current task specification. Build/locate the fastText CLI from the upstream repository under the reference workflow.
2. Convert each row to fastText supervised text `__label__<label> <text>\n` and also write an all-data corpus.
3. Deterministically split each example using `blake2b((str(label)+"\0"+text).encode(), digest_size=8)`, interpret digest as big-endian integer modulo 1000: bucket `<10` goes to tune validation; `10..19` goes to independent selection validation; all remaining buckets go to search training.
4. Require at least **100** examples in both tune and selection sets.
5. Train the reference baseline on search-training data with `wordNgrams=2` and `dim=5`. Evaluate it with `fasttext test ... 1` and parse `P@1` as selection score.

## Checks
The selection split is never supplied to autotune. Hashing uses label plus NUL plus original text, so split membership is content-deterministic.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

