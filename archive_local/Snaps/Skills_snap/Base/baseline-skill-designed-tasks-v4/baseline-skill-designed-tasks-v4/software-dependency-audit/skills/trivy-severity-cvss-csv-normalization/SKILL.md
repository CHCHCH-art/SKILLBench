---
name: trivy-severity-cvss-csv-normalization
description: "Filter Trivy JSON vulnerabilities to task-requested severities, normalize CVSS/fix metadata, and export the reference CSV when findings exist."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind allowed severities and CSV field order from `Instruction.md`; do not hard-code the Task's severity list or column names as general constants.
2. Iterate every object in Trivy `Results` and each nested `Vulnerabilities` item. Keep only records whose `Severity` belongs to the bound Task set.
3. CVSS V3 score source precedence is **NVD first, then GHSA, then RedHat**; return `N/A` when none provides `V3Score`. Missing fixed version becomes `N/A`; missing title uses the reference fallback description; missing URL becomes empty string.
4. If at least one finding exists, write CSV header plus all normalized rows. If no finding exists, the baseline prints success and **does not create an empty CSV**. Preserve that reference behavior even if Instruction appears to expect a file; record the conflict separately.
5. Abort parsing on malformed/missing raw scan JSON; do not reinterpret a scanner error as zero vulnerabilities.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
