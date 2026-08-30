---
name: casadi-acopf-pi-network-formulation
description: "Formulate a MATPOWER-style nonlinear AC optimal-power-flow problem in polar voltage coordinates using the reference pi-branch equations, generator costs, nodal balances, angle and thermal constraints."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference formulation
1. Read `baseMVA`, bus, generator, branch and polynomial generator-cost arrays from the current Task input. Build bus-number→row mapping. Convert MW/MVAr quantities to per-unit where the reference does.
2. Branch preprocessing: tap ratio with absolute value `<1e-12` becomes 1; phase shift is degrees→radians. For `r,x`, if both are effectively zero use zero series admittance; otherwise `g=r/(r^2+x^2)`, `b=-x/(r^2+x^2)`.
3. With `delta=Va_f-Va_t-shift`, reference forward flow is
`Pft=g*Vf^2/tap^2 - Vf*Vt/tap*(g*cos(delta)+b*sin(delta))`
`Qft=-(b+bsh/2)*Vf^2/tap^2 - Vf*Vt/tap*(g*sin(delta)-b*cos(delta))`.
Reverse equations use the analogous opposite-angle expression and no sending-side tap-square on the `Vt^2` term. Preserve the implementation's equations rather than replacing them with a library branch model.
4. Nodal active balance is `Pg_bus-Pd-Gs*Vm^2-Pout=0`; reactive balance is `Qg_bus-Qd+Bs*Vm^2-Qout=0`.
5. Objective is `sum(c2*(Pg*baseMVA)^2+c1*(Pg*baseMVA)+c0)`.
6. Constrain voltage magnitude to bus limits, angles to `[-pi,pi]`, generator P/Q to limits, the first reference bus angle to zero, branch angle differences to branch bounds, and both flow directions to `P^2+Q^2 <= rate_pu^2` when a positive rating exists.

## Checks

Before solving, require every generator/branch bus reference to resolve, all variable lower bounds to be no greater than upper bounds, finite per-unit data, and one selected reference bus. Verify every branch contributes flows to the correct from/to nodal balances and both thermal-direction constraints are created for rated branches. Construction errors or inconsistent bounds abort formulation; do not silently drop the offending network element.
