---
name: pdf-molecule-name-pool-extraction
description: "Extract the chemical-name candidate pool from a molecules PDF for a top-k PubChem/RDKit Morgan-fingerprint Tanimoto similarity search, using line-oriented PDF text parsing while avoiding page-number artifacts."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind the molecule-pool PDF from `Instruction.md`.
2. With `pdfplumber`, extract text page by page and split into lines. Strip each line, skip blanks, and skip lines consisting only of digits.
3. Preserve the remaining strings in document order as molecule names; do not infer structures or canonical names in this step.
4. If text extraction yields no candidates, abort rather than substituting an OCR pipeline outside this procedure.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
