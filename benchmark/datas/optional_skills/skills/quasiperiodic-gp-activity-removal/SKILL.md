---
name: quasiperiodic-gp-activity-removal
description: "Estimate and remove stellar rotational variability with Lomb-Scargle seed search and quasi-periodic Gaussian process, including exact seed grids, hyperparameter bounds, L-BFGS-B limits, transit masking, and prediction chunk sizing."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference activity model

1. Create Lomb-Scargle bins with width `max(0.08, 10*cadence)` and remove a weighted linear mean. Search activity periods from `max(0.5,20*cadence)` to `min(0.80*baseline,20.0)`; Lomb-Scargle uses `samples_per_peak=20`.
2. Let the strongest period be `rotation_seed`; also test `0.5*rotation_seed` and `2*rotation_seed` when in range and more than 5% distinct from existing candidates.
3. GP bins use width `max(12*cadence, 0.035, baseline/520)`. If more than **560** bins exist, retain indices `linspace(0,n-1,560).round().astype(int)`.
4. The quasi-periodic covariance is `A^2 * exp[-0.5*(dt/decay)^2 - 2*sin^2(pi*dt/Prot)/coherence^2]`. Add `err^2 + jitter^2 + 1e-12` to the diagonal. The negative log likelihood is `0.5*(r^T K^-1 r + logdet(K) + N*log(2*pi))`; failed Cholesky or nonfinite values return `1e100`.
5. Set `amp0=max(robust_scale(residual),5e-5)` and `err0=max(median(error),1e-7)`. For each rotation candidate use decay seeds `clip([0.7,1.5,3.0]*Prot, max(4*cadence,0.15), max(0.3,5*baseline))`, coherence seeds `(0.45,0.9,1.8)`, and jitter seeds `(err0, max(2.5*err0, 0.08*amp0))`. Choose the lowest-NLL Cartesian seed.
6. Optimize log parameters with L-BFGS-B. Exact lower bounds before log are `[max(0.03*amp0,1e-7), max(4*cadence,0.12), 0.20, max(0.05*err0,1e-8)]`; upper bounds are `[max(8*amp0,1e-4), max(5*baseline,0.5), 5.0, max(3*amp0,20*err0)]`. Use `maxiter=12`, `maxfun=90`, `ftol=1e-7`; if result `fun` or `x` is nonfinite, fall back to the best discrete seed component as specified here.
7. After selecting the best rotation candidate/hyperparameters, test **9** rotation periods from `0.88*Prot` through `1.12*Prot`; evaluate NLL with the same hyperparameters and replace only on lower NLL.
8. Build the initial binned residual mask with `<6*sigma` and `>-5*sigma`; use it only when at least **40** points survive. In GP prediction, if a supplied training mask leaves fewer than **20** points, fall back to all bins.
9. Predict in chunks of `chunk_size = max(1000, int(2.0e7 / max(number_of_training_points,1)))` to bound the cross-covariance matrix size.
10. After a preliminary transit is found, form wrapped phase and exclude binned points with `abs(phase) <= 0.80*preliminary_duration` while also honoring the initial GP mask. If fewer than **30** transit-free points remain, fall back to the initial GP mask. Re-predict with the already fitted rotation period/hyperparameters; this procedure does not re-optimize GP hyperparameters here.

## Checks

Normalize flattened flux only after subtracting the GP prediction and adding its median. If Cholesky/prediction of the selected final GP state fails after the reference fallbacks, abort rather than substituting another kernel or optimizer.

