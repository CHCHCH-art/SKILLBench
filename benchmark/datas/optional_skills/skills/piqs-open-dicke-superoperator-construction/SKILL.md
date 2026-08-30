---
name: piqs-open-dicke-superoperator-construction
description: "Construct the baseline four-case open Dicke Liouvillians in QuTiP PIQS, combine them with a lossy cavity Liouvillian and the reference light-matter superoperator."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind system size, frequencies, coupling, photon cutoff and all loss-case rates from `Instruction.md`. Build collective Dicke operators with `jspin` and Dicke-space dimension `num_dicke_states(N)`.
2. For each Task loss case instantiate `piqs.Dicke(N)`, set `hamiltonian = omega0*jz`, and assign local emission/dephasing/pumping plus collective pumping/emission/dephasing exactly from that case; obtain its TLS Liouvillian.
3. Cavity Hamiltonian is `wc*a.dag()*a`; cavity collapse list contains `sqrt(kappa)*a`; obtain photonic Liouvillian.
4. Form superoperator identities with `to_super(qeye(...))` and combine uncoupled parts by `super_tensor(Lphot,id_tls)+super_tensor(id_phot,Ltls)`.
5. Use the reference interaction implementation: `h_int = g * tensor(a+a.dag(), jx)` and `L_int = -1j*spre(h_int)+1j*spost(h_int)`. Do not insert an extra factor converting `J_++J_-` to `2Jx` in this procedure.
6. Total Liouvillian is uncoupled sum plus the same interaction superoperator for every loss case.

## Checks

Require the Dicke-space dimension and cavity cutoff to be positive and all operator/superoperator dimensions to match their tensor factors. For every loss case, all assigned rates and Hamiltonian coefficients must be finite, `Lphot`, `Ltls`, both superoperator identities, and `L_int` must have compatible Liouville-space dimensions, and the final sum must contain no NaN/Inf data. A dimension mismatch, invalid rate, or failed PIQS/cavity Liouvillian construction aborts that case; do not repair it by changing the interaction normalization or Hilbert-space convention.
