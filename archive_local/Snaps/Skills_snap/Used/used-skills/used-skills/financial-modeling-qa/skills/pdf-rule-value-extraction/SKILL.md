---
name: pdf-rule-value-extraction
description: "Extract game cardinalities, fixed rule values, and the scoring clauses needed by downstream computation from a task-provided PDF, using whitespace normalization, source-grounded field extraction, minimal executable rule descriptors, and consistency checks without embedding the PDF contents in the SKILL."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind the reference PDF path and any task-specified output/schema requirements from the current task specification at execution time. Do not copy source-document wording, values, category names, or formulas into this SKILL.

## Extraction procedure

1. Read every page with pypdf, concatenate extracted text in page order, collapse each whitespace run to one ASCII space, and trim the result.
2. Extract the cardinality fields required by the later spreadsheet-recovery stage: turns per game, rolls per turn, total simulated turns, and total simulated games. Locate each value from its semantic statement in the PDF, capture the adjacent integer, remove thousands separators, and convert to integer. A field that cannot be located unambiguously is an error.
3. Extract each fixed numeric score that the later scoring stage requires from the corresponding category/rule statement in the PDF. Keep the values in source order; do not encode the concrete category wording or numeric values in this SKILL.
4. Extract the remaining scoring clauses needed by the scoring stage directly from the PDF. Represent each clause with only the information the downstream evaluator needs: the source-order category index, the operation/predicate over one turn's roll vector, and a fixed score when the clause supplies one. This is a small task rule object, not a general expression language or parser framework.
5. Record the document's category-use constraint and any other rule-level constraint that directly governs assignment. Do not infer a constraint that is not present in the PDF.
6. Validate the extracted cardinalities against each other using the relationships stated by the document and required by the later stages. Preserve any narrow structural assumptions required by the procedure only after verifying them against the extracted PDF content.
7. Serialize a deterministic rule object containing only the extracted cardinalities, ordered scoring descriptors, fixed scores, and assignment constraints consumed downstream.

## Checks

Every required downstream field and scoring clause must have exactly one source-grounded extraction. Abort if a required field is missing/ambiguous, if a scoring descriptor cannot be grounded in the PDF text, or if the extracted cardinalities are internally inconsistent. Never substitute memorized rule text or hard-coded values for failed extraction.
