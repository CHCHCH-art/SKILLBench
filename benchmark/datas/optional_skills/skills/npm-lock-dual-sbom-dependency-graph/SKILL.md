---
name: npm-lock-dual-sbom-dependency-graph
description: "Build a normalized npm dependency inventory and transitive-resolution graph from a lockfile by reconciling offline Trivy CycloneDX/SPDX SBOMs with lockfile package occurrences, npm purls, and node_modules ancestor resolution."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind dependency-file path, offline Trivy cache, allowed severities, and output schema from the current task specification. Require the offline Trivy DB before scanning.
2. Run Trivy filesystem inventory generation twice on the lockfile with `--offline-scan --skip-db-update`: one CycloneDX SBOM and one SPDX SBOM. Both must be nonempty.
3. Parse npm package URLs from both formats, normalizing scoped package encoding and extracting `(name,version)`. Parse modern and legacy lockfile package/dependency structures into source path occurrences.
4. Resolve each dependency name from a parent package by npm `node_modules` ancestor lookup semantics used by this procedure, then compute direct edges and transitive closure. Persist inventory, occurrence, edge, and closure state in SQLite.
5. Reconcile the lockfile/SBOM package universe under this procedure purl normalization; failures are audit errors rather than permission to silently drop packages.

## Checks
Every normalized package purl used later must map to a concrete package/version occurrence and retain deterministic source/target paths.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

