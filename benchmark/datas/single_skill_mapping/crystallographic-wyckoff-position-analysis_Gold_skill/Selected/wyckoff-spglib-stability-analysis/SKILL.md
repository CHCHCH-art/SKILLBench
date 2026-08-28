---
name: wyckoff-spglib-stability-analysis
description: "Analyze normalized CIF structures for Wyckoff-position multiplicities and representative fractional coordinates by sweeping spglib tolerances, selecting a stable space-group/Wyckoff signature, and deterministically choosing representative sites."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Consume the explicit normalized structure from the preceding crystallographic normalization step and bind any Task-requested coordinate rendering/denominator limit from the current task specification.
2. Build the spglib cell `(lattice, fractional_positions, type_ids)`, assigning one integer type ID to each distinct normalized site-type identity.
3. Run symmetry analysis at the reference `symprec` sweep, in this exact order: `1e-5`, `1e-4`, `1e-3`, `1e-2`. Use `angle_tolerance=-1` on every call.
4. For each successful dataset, build a signature consisting of the space-group number plus the sorted orbit descriptors `(Wyckoff letter, multiplicity, type identity)`. Multiplicity is the number of explicit sites in the corresponding equivalence class.
5. Select the **modal signature** across the tolerance sweep. If several signatures have equal frequency, break ties in this order: first prefer a signature whose space-group number matches the declared CIF space group when that declaration is available; then prefer the candidate whose `symprec` is closest in `log10` space to `1e-3`; then use the smaller/earlier deterministic tolerance choice.
6. For every selected orbit, report its multiplicity and the first explicit fractional-coordinate representative encountered in reference site order. Apply the Task-provided fractional-coordinate presentation rule only at final rendering time; do not use rendered fractions for symmetry computation.

## Checks

Keep every sweep result so the selected modal/tie-break decision can be audited. Recompute orbit sizes from equivalence labels and confirm their sum equals the explicit site count.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

