---
name: dialogue-section-choice-parser
description: "Parse sectioned branching dialogue text into line/choice nodes and transition edges using the reference section-header, numbered-choice, speaker-line, and arrow lexical rules."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference lexical rules
Use these concrete patterns and precedence:
- Section header: `^\[(.*?)\]$` after stripping whitespace.
- Ignore blank lines and lines beginning with `//`.
- Split a transition target from the **last** `->` with `rsplit("->", 1)`; trim both pieces.
- Numbered choice: `^(\d+)\.\s*(.+)$` on the source text left of the arrow.
- Speaker line: if not a numbered choice and the source contains `:`, split on the first colon into speaker and text.

## Reference procedure
1. On a section header, create or select a node with that section ID. The reference initially represents the section as an empty line node until content sets its type/text.
2. If content is encountered before any section header, skip it.
3. For a numbered choice, make the current node a choice node with empty speaker. Keep the full numbered choice text as the edge text and use the parsed arrow target as the edge destination.
4. For a speaker line, make the current node a line node, store speaker/text, and emit a transition edge to the parsed arrow target with empty edge text.
5. For any remaining arrow transition, emit an edge with empty text. Preserve input order; do not infer extra targets or merge sections.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
