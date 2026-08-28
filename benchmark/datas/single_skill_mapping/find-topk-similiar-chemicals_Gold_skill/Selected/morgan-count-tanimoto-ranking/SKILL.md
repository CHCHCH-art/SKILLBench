---
name: morgan-count-tanimoto-ranking
description: "Rank molecules by sparse Morgan count-fingerprint Tanimoto similarity using task-bound fingerprint parameters and the exact count intersection/union and deterministic ranking convention from the procedure."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Read fingerprint radius, chirality inclusion, and requested `top_k` from the current task specification; these are Task bindings, not SKILL constants.
2. Build RDKit Morgan **sparse count** fingerprints, preserving integer feature IDs and counts. Sort each fingerprint's nonzero `(feature_id,count)` items by feature ID.
3. Compute count Tanimoto manually: for matching feature IDs add `min(left_count,right_count)` to intersection and `max(...)` to union; unmatched features add their full count to union. Return `1.0` when union is zero, else `intersection/union`.
4. Score every pool molecule against the target. Sort by `(-score, molecule_name)` and return the first Task-requested `k` names. `k=0` returns an empty result; reject negative/noninteger k under the reference validation.

## Checks
Do not convert count fingerprints to bit fingerprints. Ranking uses unrounded float scores; lexical name order is the deterministic tie breaker.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

