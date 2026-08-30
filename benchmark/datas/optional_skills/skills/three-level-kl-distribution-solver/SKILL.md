---
name: three-level-kl-distribution-solver
description: "Construct a positive three-level probability distribution whose forward and backward KL divergences from uniform meet Task-supplied targets, using the reference stabilized two-level seed and damped Newton equations."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Mathematics
Bind vocabulary size `V`, KL target `T`, and tolerance from `Instruction.md`; let `L=log(V)`. For any materialized `P`:
`KL(P||U)=sum_i P_i log(P_i)+L`, and `KL(U||P)=-L-(1/V)sum_i log(P_i)`.

For counts `(A,B,C)` with probabilities `p_h,p_m,p_l` and log-probabilities `l_h,l_m,l_l`, solve:
- `E1 = A*p_h + B*p_m + C*p_l - 1 = 0`
- `E2 = A*l_h + B*l_m + C*l_l + V*(L+T) = 0`
- `E3 = A*p_h*l_h + B*p_m*l_m + C*p_l*l_l - (T-L) = 0`
with `p=exp(l)`.

The exact Jacobian with respect to `(l_h,l_m,l_l)` is:
`[[A*p_h, B*p_m, C*p_l], [A,B,C], [A*p_h*(l_h+1), B*p_m*(l_m+1), C*p_l*(l_l+1)]]`.

## Reference seed and solve
1. For fraction `f=(A+B)/V`, solve scalar `t` from
`phi(t)=1-exp((1-f)t-T+log(f))-(1-f)*exp(-(T+f*t))=0`.
Start `t_lo=-20`, `t_hi=(L+T)/max(1e-12,1-f)`; widen a nonbracketing endpoint by 5 for at most 60 rounds. Bisection runs up to 300 iterations and stops when bracket width `<1e-13`.
2. Set `l_h=-T-L+(1-f)t`, `l_l=-T-L-f*t`, and initialize `l_m=(l_h+l_l)/2`.
3. Damped Newton runs up to 400 iterations. Solve `J*delta=-E`; on linear-solve failure use least squares on `J+1e-12 I`. Backtrack up to 50 halvings; clip proposed log-probabilities to at most 0. Stop at infinity-norm residual `<1e-14` or step-norm stagnation `<1e-16`.
4. Reject nonfinite/nonpositive solutions; do not substitute a generic optimizer.

## Checks

After Newton terminates, require finite `l_h,l_m,l_l`, strictly positive probabilities, normalization residual `|E1|` within the Task tolerance, and both recomputed KL divergences within the Task tolerance of their targets. Reject a candidate whose residuals merely stagnated without meeting the required accuracy. Linear-solve failure may use only the documented regularized least-squares fallback; if backtracking cannot produce an improving finite step, reject the candidate rather than switching optimizers.
