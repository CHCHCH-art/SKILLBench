---
name: xlsx-formula-cache-preserving-recalc
description: "Recalculate a formula-based analytical XLSX with LibreOffice, copy cached numeric results back into the original OOXML formula cells, and verify that formulas and cached values survive the round trip."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Run LibreOffice headless with a private profile and convert the formula workbook to XLSX in a separate recalculation directory. Failure to produce a recalculated file aborts.
2. Resolve the target worksheet XML path through `workbook.xml` and workbook relationships for both source and recalculated workbooks.
3. Build the set of Task-required formula cell addresses. From the recalculated sheet XML, require a nonempty `<v>` cached value for every required cell.
4. In the **source** sheet XML, locate each `<c r="ADDR">...</c>` and replace an existing `<v>`, self-closing `<v/>`, or append a new `<v>` with the recalculated numeric text. Preserve all other source ZIP entries byte-for-byte as copied through ZipFile.
5. Open the patched workbook twice with openpyxl (`data_only=False` and `True`). Require every target cell to retain a formula string beginning `=` and a finite numeric cached value. Atomically replace the Task output only after all checks pass.

## Checks

Require the recalculated workbook to contain a nonempty cached `<v>` for every Task-required formula cell. After patching the original OOXML, reopen with `data_only=False` and require every target still contains its original formula string; reopen with `data_only=True` and require a finite cached numeric value. Also require that non-target ZIP entries and non-target cell formula text remain unchanged. Any missing cache, lost formula, or OOXML parse failure aborts replacement of the output workbook.
