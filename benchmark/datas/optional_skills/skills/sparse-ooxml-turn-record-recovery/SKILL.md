---
name: sparse-ooxml-turn-record-recovery
description: "Recover structured turn/game/dice records from a sparse Excel workbook by parsing OOXML cells directly and scanning for contiguous numeric windows that satisfy reference turn-to-game invariants."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Open the workbook as a ZIP. Resolve workbook sheet relationships and shared strings; decode cell values without relying on recalculated workbook display.
2. Obtain `rolls_per_turn`, `turns_per_game` and expected total turns from the upstream rule object.
3. In each worksheet row, collect populated numeric cells by column index. Scan contiguous windows of width `2 + rolls_per_turn`; interpret them as `(turn, game, rolls...)` only when all required cells are present.
4. Validate each candidate: turn is in expected range; `game == floor((turn-1)/turns_per_game)+1`; every die value lies in the rule-object die domain. Reject invalid windows.
5. For each turn require exactly one consistent record. Duplicate identical recoveries may coalesce; conflicting records abort. Require complete coverage of all expected turn IDs before scoring.

## Checks

Require `xl/workbook.xml` and its relationship part to resolve every scanned worksheet, and decode shared-string/inline/numeric cells without coordinate collisions. Every accepted window must have exactly `2 + rolls_per_turn` consecutive populated numeric cells and satisfy the turn-range, turn-to-game, and roll-domain invariants. Duplicate recoveries for one turn may coalesce only when `(game, rolls)` is identical; any conflicting duplicate aborts. Before scoring, recovered turn IDs must equal the complete expected set with no gaps or extras.
