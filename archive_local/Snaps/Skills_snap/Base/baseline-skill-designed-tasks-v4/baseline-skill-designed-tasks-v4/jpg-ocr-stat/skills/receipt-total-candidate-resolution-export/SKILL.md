---
name: receipt-total-candidate-resolution-export
description: "Select receipt total amounts from OCR lines using task-defined keyword priority plus the reference finality/support/local-reOCR ranking, then export deterministic spreadsheet rows."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind the Task's total-keyword priority/exclusion rules and output schema from `Instruction.md`; do not copy those Task keyword lists into this SKILL. Normalize OCR text to uppercase, collapse whitespace, replace `|` with `I`, and repair spaced comma/decimal before two trailing digits.
2. Money regex is `(?<!\d)(?:RM\s*)?([+-]?\d{1,3}(?:,\d{3})*\.\d{2}|[+-]?\d+\.\d{2})(?!\d)`. Use the last money value on a candidate line and absolute value.
3. Add reference finality bonuses: +30 for `AFTER (ADJ|ADJUST|ROUND)`, +25 for rounded-total wording, +20 for grand-total wording, +15 for net/nett-total wording. Skip a candidate when either of the preceding two lines signals tax/GST summary or summary amount.
4. Candidate support is how many OCR money occurrences are within **0.01** of its amount. Rank `(task_keyword_priority, finality, support, confidence, line_index)` descending.
5. If the best keyword line has no parsed amount, crop around that line by 90 px horizontal/10 vertical, 2× resize and OCR with PSM 6,7,11. Rank local amounts first by repetition count then candidate rank. If local recovery fails, fall through to the next already-parsed candidate.
6. Quantize final total to two decimals with `ROUND_HALF_UP`. Process filenames in sorted order and write the Task-bound columns; per-image exceptions produce missing fields rather than terminating the batch.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
