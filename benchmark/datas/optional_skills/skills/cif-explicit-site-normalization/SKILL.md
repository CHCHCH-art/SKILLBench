---
name: cif-explicit-site-normalization
description: "Normalize crystallographic CIF structures into an explicit P1-like site list before symmetry analysis. Use for CIF expansion, fractional-coordinate canonicalization, occupancy/type preservation, Cartesian duplicate removal, and a write/re-read normalization pass matching a reference crystallography workflow."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Read the current Task's CIF path from the current task specification. Prefer Gemmi for CIF parsing/expansion and uses pymatgen only as a fallback when the preferred route is unavailable.
2. Expand every crystallographic site to explicit symmetry-equivalent fractional coordinates. Preserve the chemical/type label and occupancy associated with each generated site.
3. Canonicalize every fractional coordinate component with modulo 1. Components numerically within `1e-12` of either 0 or 1 are set to exactly 0 before duplicate handling.
4. Convert candidate sites to Cartesian coordinates with the current lattice. Remove duplicate sites using a **reference Cartesian tolerance of `1e-3 Å`**. Duplicate comparison is performed after periodic fractional wrapping.
5. Define the reference site-type identity as `(type_label, round(occupancy, 6))`; do not merge sites whose normalized coordinates coincide but whose type identity differs.
6. Serialize the resulting explicit sites as a P1 representation, then re-read that serialized structure before downstream symmetry inference. This write/re-read step is part of the reference pipeline and is not an optional cleanup.

## Checks

Verify every fractional coordinate is in `[0,1)`, no same-type Cartesian pair remains within the duplicate tolerance, occupancy/type labels survive the round trip, and the re-read explicit site count equals the serialized site count.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

