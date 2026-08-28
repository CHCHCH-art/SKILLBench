---
name: trivy-dual-scan-csv-reconciliation
description: "Run offline Trivy vulnerability scans on both a reconstructed dependency filesystem and the original lockfile, normalize task-selected findings, choose CVSS by reference source priority, reconcile result multisets, and export CSV."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Run Trivy `fs` vulnerability scans on (a) the reconstructed installed tree and (b) the original lockfile, each with JSON output, `--scanners vuln --skip-db-update --offline-scan --no-progress` and the same Task-provided cache.
2. Parse `Results[].Vulnerabilities[]`. Keep only Task-allowed severity levels from the current task specification; do not hardcode a particular severity set in the reusable SKILL.
3. For each retained finding bind Task output column names and extract package, installed version, vulnerability ID, severity, fixed version, title, and primary URL. Missing values use the stated fallback strings as mapped to the Task schema.
4. CVSS source priority is a fixed procedure decision: inspect `CVSS` in order **NVD, GHSA, Red Hat** and return the first nonempty `V3Score`; otherwise use the reference unavailable representation.
5. Compare reconstructed-tree findings and direct-lockfile findings as **multisets of complete normalized rows**. If equal, select reconstructed-tree rows; otherwise select the direct-lockfile rows as `native_control_fallback`.
6. Preserve selected report encounter order in the CSV; write exactly the Task-provided headers. Persist both finding sets and reconciliation status in SQLite for audit.

## Checks
Do not union the two scans. The reference chooses one whole result path based on multiset equality.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

