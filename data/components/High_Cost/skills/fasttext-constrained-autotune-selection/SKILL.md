---
name: fasttext-constrained-autotune-selection
description: "Run the fastText autotune/selection recipe under a task-specified model-size ceiling: derive a slightly sub-limit autotune budget, compare autotune against a compact baseline on the independent selection split, retrain the winner policy, and enforce final size."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Read the Task hard model-size ceiling `<size_limit>` and accuracy requirement from the current task specification. For fastText `-autotune-modelsize`, derive an integer-`M` budget with one `M` unit of headroom below an integer-MB ceiling: `<autotune_M> = floor(<size_limit_MB>) - 1`, then pass `<autotune_M>M`. This is the generalized reference policy behind the procedure's one-megabyte headroom, not a fixed SKILL constant.
2. Autotune from the search-training corpus for reference duration **300 seconds**, using the derived model-size argument and `-autotune-predictions 1`, with the tune partition as `-autotune-validation`.
3. Prefer generated `.ftz` when present; otherwise `.bin`; abort if neither exists. Evaluate this artifact and the compact baseline on the independent selection partition.
4. Select autotune only when `autotune_P@1 > baseline_P@1` **strictly**. Equal scores choose the baseline representation.
5. If autotune wins, copy its artifact bytes to the Task final model path even if the source extension is `.ftz`. If baseline wins, retrain the reference compact representation `wordNgrams=2, dim=5` on the all-data corpus and move its `.bin` to the final path.
6. Enforce the Task hard ceiling after selection. The reference shell converts an MB limit to bytes as `<limit_MB> * 1024 * 1024`; preserve this byte convention.
7. Run `fasttext test` on the final model against the selection split as a final smoke check.

## Checks
Selection must use the independent selection partition and strict `>`. If the selected artifact exceeds the Task hard size ceiling, is missing, or cannot be loaded/tested, abort; do not substitute tune score or artifact size as the selection criterion.

