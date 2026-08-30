---
name: invoice-pdf-reference-field-extraction
description: "Extract vendor, amount, purchase-order and payment-identifier fields page-by-page from simple invoice PDFs using the reference anchored text regex families."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference lexical rules
After `pdfplumber` text extraction, the reference uses:
- vendor: `From: (.*)` and strips the captured line;
- amount: `Total \$(\d+\.\d{2})`, converted to float, defaulting to 0.0 if absent;
- purchase order: `PO Number: (PO-\d+)`;
- payment identifier: `Payment IBAN: ([A-Z0-9_-]+)`.
Bind the output field names from `Instruction.md`; the regexes are reference parser knowledge, not values copied from invoice content.

Emit one parsed record per PDF page with 1-based page number. If page text itself cannot be extracted, treat it as a failed page rather than inventing OCR.

## Checks

Require text extraction to succeed for every processed page; this procedure has no OCR fallback. Emit exactly one parsed record per successfully processed page with sequential 1-based page numbering. When a regex matches, its capture must satisfy the corresponding lexical form before conversion; amount conversion must be finite, while an absent amount follows the specified `0.0` default and absent vendor/PO/payment identifiers remain missing rather than being synthesized. A page with unavailable text, an invalid numeric capture, or a parser exception aborts extraction instead of inventing field values.
