---
name: deterministic-offline-package-tree-reconstruction
description: "Reconstruct a deterministic installed npm-like filesystem from normalized package inventory using synthetic package artifacts, content hashes, transitive placement, and a verified PAX/xz audit bundle before offline vulnerability scanning."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. For every normalized purl, derive artifact ID from the first **24 hex characters of SHA-256(purl)**. Create a minimal package artifact containing the reference package metadata under `package/` using gzip tar with compression level 9 and PAX format.
2. Store and verify both SHA-256 and SHA-512 of every generated artifact. Install/extract artifacts into the staged node_modules tree according to the resolved occurrence/transitive graph, guarding extraction paths as specified here.
3. Hash every installed regular file and store the manifest in SQLite.
4. Create the complete audit bundle as `tar.xz` with PAX format using normalization filter for deterministic member metadata (mtime/ownership/mode fields as implemented). Reopen the archive and verify every extracted/staged manifest file hash.
5. Extract the verified bundle to the scan root used by Trivy. This reconstruction is part of the reference audit path, not an optional optimization.

## Checks
Artifact/bundle hash mismatches or path-resolution inconsistencies are hard failures. Do not use network package installation as a replacement for the reconstructed offline tree.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

