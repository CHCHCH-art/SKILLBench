---
name: chemical-pdf-pubchem-structure-resolution
description: "Resolve molecule names extracted from a PDF into verified PubChem structures using bbox-layout text extraction, persistent alias/CID caching, bounded parallel REST retrieval, and RDKit SDF identity/canonicalization checks."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind target molecule, pool PDF, fingerprint settings, and top-k from the current task specification. Extract PDF text with `pdftotext -bbox-layout`, cache the XHTML by source SHA-256, and reconstruct ordered text lines using bbox parser.
2. Normalize extracted molecule names exactly as the reference parser does and preserve first source order. Resolve each missing name through PubChem PUG REST using the **first returned CID**.
3. Use reference network defaults: at most **4 workers**, HTTP timeout **40 s**, and **5 attempts** with `Retry-After`/backoff handling. Persist name aliases and resolved CIDs in SQLite.
4. Fetch PubChem 2D SDF for each CID and cache raw bytes. Parse with RDKit under the reference sanitize/remove-H behavior. If the SDF contains a CID property, require it to equal the requested CID.
5. Canonicalize each accepted molecule to isomeric canonical SMILES and InChIKey under this procedure path; retrieval/parsing failures are errors rather than permission to invent structures.

## Checks
Verify every pool name and the target has exactly one resolved CID/structure record before fingerprinting; retain raw SDF hashes for repeatability.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

