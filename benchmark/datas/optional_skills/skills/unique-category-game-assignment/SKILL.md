---
name: unique-category-game-assignment
description: "Score recovered dice turns using a PDF-derived rule object, optimize one-use category assignment within each game by bitmask dynamic programming, then compare paired games."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Consume the rule object from PDF extraction. For every recovered turn, evaluate every category **through that rule object**. Do not hard-code category formulas, bonuses, face values, run definitions, or other PDF contents here.
2. For each game, use dynamic programming over category-use bitmasks: state maps `used_mask -> best_total`. For each turn, try every category whose bit is not set and update the new mask with the maximum accumulated score. This enforces each category at most once.
3. After all turns in a game, take the maximum total among reachable states that satisfy the rule-object assignment requirements.
4. Read the Task-specified `<pairing_rule>` and aggregate comparison/sign convention from `Instruction.md`. Pair games exactly according to `<pairing_rule>`, then apply the requested comparison convention; do not impose an odd/even pairing unless the current Task explicitly specifies it.
5. Abort if a game has missing turns, no legal assignment, or the rule object cannot score a recovered roll.

## Checks

Before dynamic programming, require the rule object to contain an ordered category list and a deterministic evaluator for every category. For every recovered turn, evaluating all categories must produce one finite numeric score per category with no unresolved rule operation. During DP, category masks must never reuse a category within a game and at least one reachable state must remain after every turn. Missing turns, evaluator failures, or an empty legal assignment set abort the calculation rather than triggering a hard-coded scoring fallback.
