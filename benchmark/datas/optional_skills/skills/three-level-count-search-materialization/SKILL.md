---
name: three-level-count-search-materialization
description: "Search integer multiplicities for a three-level KL target distribution, rank candidate KL error deterministically, then materialize and normalize the final NumPy probability vector."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind `V`, target and allowed KL tolerance from `Instruction.md`. The reference search centers the high-level fraction at `f0=0.05`.
2. Let `A0=round(f0*V)`. Build candidate `A` values by offsets `0..1175` in steps of 25 on both sides, keep valid unique values, sort, then inspect at most the first 200.
3. Try `B` in this reference sequence: `1,2,3,5,8,13,21,34,55,89,144,233,377,610,987,1597,2584,4096,8192,12000`; set `C=V-A-B` and skip nonpositive counts.
4. Solve each `(A,B,C)` with the three-level solver. Compute both KL values from grouped formulas and score with `max(abs(KLf-T), abs(KLb-T))`. Keep the lowest error and return immediately once it meets the Task tolerance.
5. If the search only yields a near miss, run up to 80 additional damped-Newton polish iterations using the same equations/Jacobian and up to 30 line-search halvings.
6. Materialize `P=[p_h]*A+[p_m]*B+[p_l]*C`, normalize by its sum, verify all entries are finite and strictly positive, length equals `V`, sum is numerically 1, and both KL errors meet tolerance. Otherwise abort instead of saving an invalid vector.

## Checks

For every examined candidate require integer `A,B,C > 0` and `A+B+C=V`. Candidate probabilities and grouped KL values must be finite and strictly positive where required by logarithms. The stored best candidate must be updated only by a strictly lower `max(|KLf-T|,|KLb-T|)` error, except for the documented immediate return once tolerance is met. After optional polish, materialized `P` must have length `V`, exactly the selected multiplicities, finite strictly positive entries, numerical sum 1, and recomputed forward/backward KL errors within the Task tolerance. If no candidate satisfies these invariants, abort instead of saving the nearest invalid vector.
