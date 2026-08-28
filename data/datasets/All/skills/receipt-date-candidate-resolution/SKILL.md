---
name: receipt-date-candidate-resolution
description: "Resolve receipt dates from OCR lines with contextual regex ranking, OCR-character correction and localized re-OCR fallback."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Normalize date candidate strings by replacing OCR confusions `O/o→0`, `I/l→1` and removing whitespace.
2. Try formats `%d/%m/%Y`, `%d-%m-%Y`, `%d/%m/%y`, `%d-%m-%y`, `%Y/%m/%d`, `%Y-%m-%d`; accept reference years **2000 through 2030**.
3. Search line text using these families: labeled date `(?:DATE|TARIKH)[:=\-]*([0-3]?d[/\-][01]?d[/\-]d{2,4})` with context score 2; generic Y-M-D and D-M-Y with score 1. Rank `(context_score, line_confidence, -line_index)` descending.
4. If no date resolves, rank up to four lines containing a date label or slash/dash numeric date by label/slash/dash score and confidence. Expand bbox by 70 px horizontally and 28 vertically, 2× resize, and re-OCR with PSM 7 then 13; accept the first valid date.
5. Bind final date output format from Instruction; abort only this field when no candidate succeeds.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
