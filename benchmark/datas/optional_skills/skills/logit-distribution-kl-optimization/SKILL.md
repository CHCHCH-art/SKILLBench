---
name: logit-distribution-kl-optimization
description: "Optimize logits for a positive normalized distribution whose forward and reverse KL divergences to uniform hit task targets, reproducing stable KL formulas, analytic gradients, Adam schedule, recentering, best-state handling, and final validation."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Task bindings

Read distribution size `V`, target divergence value(s), final acceptance tolerance, and output path/format from the current the current task specification.

## Stable KL formulas and gradients

Let logits be `z in R^V`, `L = logsumexp(z)`, `p_i = exp(z_i-L)`, `U_i=1/V`, `LOG_V=log(V)`, and `mu_p = sum_i p_i z_i`.

Compute:

- forward KL: `KL_f = KL(P||U) = LOG_V + mu_p - L`;
- backward KL: `KL_b = KL(U||P) = L - mean(z) - LOG_V`.

The exact gradients with respect to **logits** are:

- `grad_forward_i = p_i * (z_i - mu_p)`;
- `grad_backward_i = p_i - 1/V`.

For a common target `T`, define `err_f = KL_f-T`, `err_b = KL_b-T` and objective `J = err_f^2 + err_b^2`. Its logit gradient is
`grad_i = 2*err_f*grad_forward_i + 2*err_b*grad_backward_i`.
If the Task supplies distinct forward/backward targets, bind them separately in the same expression.

## Optimization procedure

1. Use `float64`. Initialize `z ~ Normal(0,4)` with `numpy.random.default_rng(0)`. Initialize Adam first/second moments to zero.
2. Use reference Adam defaults `beta1=0.9`, `beta2=0.999`, `eps=1e-8`, initial learning rate `0.2`, and maximum `2000` iterations. At each step compute the stable KLs and `max_error=max(|err_f|,|err_b|)` before the update.
3. Track `best_z` whenever `max_error` strictly improves. Stop before updating when `max_error <= 2e-4`. Otherwise apply the analytic gradient, bias-correct Adam moments, update logits, then recenter with `z -= mean(z)`.
4. After steps `500`, `1000`, and `1500`, halve the learning rate. If and only if the loop reaches the maximum without early convergence, replace the last state with the tracked `best_z`, matching the procedure `for ... else` behavior.
5. Recompute `P=softmax(z)` and explicitly renormalize by `P /= sum(P)`. For the final audit recompute `KL(P||U)=sum(P*log(P*V))` and `KL(U||P)=mean(log((1/V)/P))` rather than reusing optimizer scalars.
6. Require the Task-bound output shape, finite strictly positive entries, normalization error at most `1e-10`, and both recomputed KLs within the Task acceptance tolerance.

## Checks

At every audited state require finite logits, finite KL values, and finite gradients. For the final candidate require the exact task-bound shape, strictly positive finite probabilities, `abs(sum(P)-1) <= 1e-10`, and independently recomputed forward/backward KL values within the task acceptance tolerance. Reject the candidate and abort without saving if any invariant fails; never round probabilities before the final KL audit.
