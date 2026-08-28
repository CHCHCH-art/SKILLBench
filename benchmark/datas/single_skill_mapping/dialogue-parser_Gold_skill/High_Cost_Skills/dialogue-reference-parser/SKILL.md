---
name: dialogue-reference-parser
description: "Parse a section-based dialogue script into deterministic section and statement records using lexical grammar: exact header/choice regexes, last-arrow transitions, first-colon speakers, comment/BOM handling, structural rejection, and cached C++17 parser execution."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Exact lexical procedure

1. Read the source as binary/text lines. On the first line only, remove UTF-8 BOM bytes `EF BB BF` when present. Trim `" \\t\\r\\n"`; ignore empty trimmed lines and lines whose trimmed form starts with `//`.
2. A section header is matched by the exact ECMAScript/C++ regex `^\\[([^\\[\\]\\r\\n]+)\\]$`. Trim capture group 1 to obtain the section ID. Reject an empty ID, a duplicate ID, content before the first section, or a file with no sections.
3. For every non-header statement, find the **last** `->` with `rfind`. If absent, the whole statement is text and target is null. If present, trim the left portion as statement text and trim the suffix as target; reject an empty target.
4. On the left/text portion, test the exact choice regex `^([0-9]+)\\.\\s*(.*)$`. For a match, parse group 1 with `stoi`, trim group 2 as choice text, retain the full pre-arrow text as `edge_text`, and retain the optional target.
5. If not a choice, find the **first** colon. When text before it trims to a nonempty speaker, classify as a spoken line with that speaker and trimmed remainder as text. Otherwise classify as plain text.
6. Preserve source line numbers and raw statement text in the intermediate representation. Apply the graph-construction stage's structural rule for sections that cannot mix choice and ordinary statement modes; report that failure before graph emission.
7. Build/run the native parser with `-std=c++17 -O2 -DNDEBUG -Wall -Wextra -pedantic`. Cache/reuse its executable by hash of the generated/native parser source; rebuild only when that source hash changes.

## Checks

Every nonignored source line must belong to exactly one section and exactly one statement class. On duplicate sections, empty transition targets, content-before-header, invalid mixed section structure, or any parser build/runtime failure, abort before graph construction.

