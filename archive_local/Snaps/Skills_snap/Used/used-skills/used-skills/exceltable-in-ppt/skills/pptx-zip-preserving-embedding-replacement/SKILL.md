---
name: pptx-zip-preserving-embedding-replacement
description: "Publish an updated embedded Excel table back into a PowerPoint financial-reporting file while leaving all other presentation content unchanged: replace exactly one OOXML embedded object and verify package-member identity plus non-target hashes."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Consume the original presentation, the updated embedded-object bytes, and the target embedding part name from the preceding step; bind final output path from the current task specification.
2. Copy the outer PPTX ZIP member-by-member, preserving each original `ZipInfo` metadata record. Replace bytes only for the selected embedding member.
3. Keep the package member-name list identical to the input package. Do not re-save the complete presentation through a high-level library, because that can rewrite unrelated XML/ZIP metadata.
4. Reopen both ZIP files. Verify the selected embedding bytes equal the intended updated object and that every non-target member has the same SHA-256 digest as the original.

## Checks

Require exactly one intended embedding difference. A changed non-target member, missing member, extra member, or wrong embedded-object hash is a hard failure.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

