---
name: dispatch-reserve-and-ptdf-audit
description: "Allocate operating reserve by minimizing maximum generator utilization and independently audit sparse DC flows with a dense spectral/PTDF construction using the reference numerical thresholds."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reserve allocation
1. Given final active dispatch, define each generator's available reserve as `min(reserve_capacity, max(Pmax-Pg,0))`. If total headroom plus **0.08 MW** is below the requirement, fail.
2. Solve a HiGHS LP whose additional scalar variable is maximum utilization; minimize that scalar subject to reserve sum and each reserve allocation bounded by availability and its utilization relation.

## Dense network audit
3. Build the reduced dense Laplacian/eigensystem. Require smallest eigenvalue `> 1e-12`; construct the inverse spectrally and derive dense bus-to-line PTDF/generator sensitivities.
4. Compare dense/PTDF flow results with the sparse physical load-flow path. Reference maximum allowed flow discrepancy is **0.08 MW**.

## Checks
Run the reference final feasibility bundle; every violation scalar must be no larger than the reference feasibility tolerance.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

