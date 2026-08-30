---
name: dice-turn-category-scoring
description: "Score recovered turn records in a PDF-and-spreadsheet dice-game analysis by evaluating the ordered runtime rule object for every scoring category, producing deterministic per-game/per-turn category scores for unique-category assignment and paired-game outcome aggregation."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Rule-object contract

Consume the normalized rule object produced by the PDF/rule-extraction step. It must carry the document-derived roll/game cardinalities and an **ordered category-rule list**. Each category entry must contain enough information to execute that source rule at runtime, such as an arithmetic expression over per-turn roll statistics, a condition plus a document-derived fixed score, or a positional-sequence predicate. Do not restate or reconstruct the source PDF's concrete category formulas inside this SKILL.

## Scoring procedure

1. Preserve the category order from the rule object and the original roll order from the recovered turn table.
2. For each turn, derive only the generic primitives required by the rule descriptors: roll vector, extrema, sums/counts, distinct-value presence/counts, adjacent differences, and other descriptor-requested statistics.
3. Evaluate every category descriptor exactly as represented in the rule object. Arithmetic descriptors operate on the generic primitives; conditional descriptors return their document-derived score only when their predicate is true and otherwise zero; positional predicates must use the original roll sequence rather than a sorted copy.
4. Emit one score per `(game, turn, turn_slot, category)` and stable-sort by `(game, turn_slot, category)`.
5. Require the row count to equal `expected_turns * number_of_category_rules` and keep reference scores integral.

## Checks

Reject a rule object that is missing an executable category descriptor, changes category order, or requires a primitive that was not computed. If any required scoring or cardinality check fails, abort before assignment optimization rather than inventing a category interpretation.

