---
name: pdf-game-rule-object-extraction
description: "Extract structural quantities and scoring semantics from a task-provided game-rules PDF into a compact executable rule object for downstream spreadsheet turn scoring, while deriving every rule value and condition from the current PDF instead of embedding document-specific formulas in the SKILL."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Input-derived rule boundary

The scoring semantics belong to the current PDF. Derive them from that document at runtime. Do not copy a previously observed category formula, fixed score, face set, sequence length, or other document literal into this reusable SKILL.

## Reference procedure

1. Read every PDF page with `pypdf.PdfReader`, concatenate extracted text, collapse repeated whitespace with `re.sub(r"\s+", " ", ...)`, and strip the result.
2. Extract the structural game quantities needed downstream by label-anchored regex near their statements in the PDF: turns per game, rolls per turn, total simulated turns, and total games. Remove thousands separators before integer conversion. Missing required quantities are hard failures.
3. Locate the scoring-rule section and separate its category clauses using the document's own category labels/order. For a clause containing a literal fixed score, extract that number from the same clause. For a clause defining a computed score, retain the normalized clause text and translate only the arithmetic/condition explicitly stated there.
4. Build a minimal rule object rather than a general-purpose DSL. It needs only:
   - the extracted structural quantities;
   - an ordered list of categories;
   - for each category, its normalized source clause and one deterministic evaluator derived directly from that clause.
5. Implement each evaluator with the smallest direct operations required by its clause. Typical clause semantics can be expressed with primitives such as `max`, `min`, `sum`, equality counts/frequencies, distinct-value count, set coverage, multiplication/difference, and checking a contiguous ordered subsequence. Numeric literals and comparison values must come from the current clause. Do not infer bonuses, multipliers, allowed values, sequence lengths, or fallback scores that are not stated.
6. Preserve only structural consistency checks needed by the downstream workflow: `total_turns == total_games * turns_per_game`; the number of turns in one game must not exceed the number of one-use scoring categories; and any pairing cardinality required by the Task must be satisfiable.
7. Return the compact rule object to the turn-scoring step. If a required category clause is missing or cannot be translated unambiguously into a deterministic evaluator using its own text, abort extraction instead of filling the gap from prior knowledge.

## Checks

Require every structural value and every evaluator literal to be traceable to the current PDF text. Require one deterministic evaluator per extracted category and preserve category order. Reject ambiguous or unsupported clauses; do not add a second semantic-validation framework, synthetic-roll test suite, or hard-coded fallback rules that are not part of this procedure.
