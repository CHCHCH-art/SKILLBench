---
name: rectangular-acopf-network-model
description: "Construct the reference nonconvex AC optimal-power-flow model in rectangular voltage coordinates with explicit forward/reverse branch powers, transformer taps and shifts, nodal balance, voltage/thermal limits, angle constraints, and quadratic generator costs."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Model construction

1. Bind network data, Task limits, requested outputs, and any model-document conventions from the current task specification. The reference environment pins NumPy `1.26.4` and CasADi `3.6.7`.
2. Represent bus voltage as `V_i = E_i + j F_i`. For each branch derive series admittance from `(r,x)`; if `r^2+x^2 < 1e-24`, set reference `g=b=0`. Treat tap magnitudes with absolute value `<1e-12` as unity. Convert phase shift to radians.
3. For branch `f -> t`, define `dot=Ef*Et+Ff*Ft`, `cross=Ff*Et-Ef*Ft`, `a=(dot*cos(shift)+cross*sin(shift))/tap`, `c=(cross*cos(shift)-dot*sin(shift))/tap`, and preserve these reference flow equations:
   - `Pft = g*|Vf|^2/tap^2 - (g*a + b*c)`
   - `Qft = -(b+bchg/2)*|Vf|^2/tap^2 - (g*c - b*a)`
   - `Ptf = g*|Vt|^2 - g*a + b*c`
   - `Qtf = -(b+bchg/2)*|Vt|^2 + g*c + b*a`.
4. Make `E,F,Pg,Qg,Pft,Qft,Ptf,Qtf` decision variables. Constrain explicit branch-flow variables equal to the equations above; impose real/reactive nodal balances with outgoing end-specific branch powers.
5. Impose generator and voltage-magnitude limits. For positive branch ratings, constrain squared apparent power at **both ends**: `P^2+Q^2 <= rate_pu^2`.
6. Enforce angle-difference limits with reference numerical epsilon **`1e-10`**. If the allowed width is at most `pi + epsilon`, use the half-plane form implemented by the script; otherwise use `atan2` with clipped bounds. Skip a constraint representing essentially a full `2*pi` range.
7. For every type-3 slack/reference bus, fix `F=0` and constrain `E` positive within voltage bounds. Use the quadratic polynomial generator-cost rows expected by the procedure.

## Checks

Numerically recompute branch flows from `E,F` and compare with explicit decision variables after solving. Check nodal real/reactive residuals and both-end thermal loading before reporting.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

