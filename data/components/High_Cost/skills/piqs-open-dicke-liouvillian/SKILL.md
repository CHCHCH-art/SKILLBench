---
name: piqs-open-dicke-liouvillian
description: "Construct the reference open-Dicke Liouvillian in a permutation-invariant spin basis coupled to a truncated cavity, using task-bound physical parameters/loss cases and the exact interaction representation."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Read spin count, cavity cutoff, frequencies, coupling parameter, cavity loss, all local/collective dissipative rates, and case definitions from the current task specification.
2. Build cavity operators and PIQS collective spin operators in the Dicke basis. Construct the Hamiltonian as: spin term plus cavity number term plus **`g * tensor(a + a.dag(), Jx)`** using the task-bound `g`. Keep this interaction form unchanged in this workflow.
3. Build the spin dissipator/Liouvillian through PIQS using each case's local dephasing, local pumping/emission, and collective pumping/emission rates under this procedure API mapping. Add cavity Hamiltonian and cavity collapse loss to form the full light-matter Liouvillian.
4. Keep operator tensor ordering consistent with the later cavity partial trace.

## Checks
Validate operator/Liouvillian dimensions for every Task case and ensure all omitted loss channels are exactly zero/default under the reference construction.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

