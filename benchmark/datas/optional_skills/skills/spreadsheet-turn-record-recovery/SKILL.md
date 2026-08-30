---
name: spreadsheet-turn-record-recovery
description: "Recover a hidden/irregular rectangular turn table from an Excel workbook by scanning every sheet for contiguous integer windows, validating game/turn arithmetic, deduplicating conflicting records, and enforcing complete sequence coverage."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Read the workbook in `data_only=True` mode and convert each worksheet's values to a tabular frame. The row width is derived from the PDF rule object: two identifier fields plus the document-defined number of rolls.
2. Convert only exact integer-like cells: reject booleans, nonintegral finite floats, and strings that are not signed integer text.
3. For every sheet and every possible start column, construct contiguous windows by joining shifted integer cells on `(row_index,start_column)`. Interpret field 0/1 as turn/game and subsequent fields as die rolls.
4. Validate `expected_game = ((turn-1)//turns_per_game)+1`, require game equality, and require all die values within the reference die-face bounds implied by the rule set.
5. Combine candidate windows across sheets. For each turn, reject conflicting distinct `(game, rolls...)` records. Keep the first identical duplicate.
6. Sort by turn and require the exact sequence `1..expected_turns`. Require exactly `turns_per_game` records for each game and exactly `expected_games` games.

## Checks

Do not select a table merely by header text; completeness and arithmetic validation determine the recovered relation. Report the first conflict/missing sequence if validation fails.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

