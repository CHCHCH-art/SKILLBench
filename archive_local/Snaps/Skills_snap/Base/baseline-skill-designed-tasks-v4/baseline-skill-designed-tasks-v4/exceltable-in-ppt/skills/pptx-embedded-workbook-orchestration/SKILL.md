---
name: pptx-embedded-workbook-orchestration
description: "Unpack a PPTX, locate an embedded Excel workbook, inventory slide text for a requested rate update, and repack after formula-preserving workbook modification."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind input/output presentation paths from `Instruction.md`. The reference delegates OOXML unpack, slide-text inventory, pack, and spreadsheet recalculation to helper scripts; if equivalent helpers are available, call them rather than rewriting ZIP relationships ad hoc.
2. After unpacking, first look for the conventional embedded-workbook relationship path; if absent, choose the first `.xlsx` below `ppt/embeddings`. Abort when no embedded workbook exists.
3. Inventory all slide text. Find update text with case-insensitive regex `([A-Z]{3})\s*(?:to|→|->)\s*([A-Z]{3})\s*[=:]\s*([\d.]+)`. Validate both currency labels occur in the embedded table's row/column labels.
4. Apply exactly one resolved update to the embedded workbook, recalculate, and repack to the Task output path. A recalculation-helper failure produces a warning in the reference path but does not by itself cancel repacking; a missing workbook/update does abort.

## Checks

After updating the embedded workbook, require the PPTX ZIP to contain the original presentation parts plus the expected embedded workbook relationship, and require that the embedded workbook can be reopened as XLSX. Verify target cells contain the requested formulas/values after round-trip. If the workbook relationship breaks, the embedded XLSX is unreadable, or unrelated presentation parts are lost, abort rather than emitting a visually plausible but structurally broken PPTX.
