---
name: lightcurve-robust-conditioning
description: "Condition a photometric light curve for activity/transit analysis using quality filtering, duplicate-time inverse-variance merging, robust local outlier rejection, robust time bins, and weighted linear mean functions."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Bind the light-curve input columns/path and final period output requirements from the current task specification. The reference expects time, flux, quality flag, and uncertainty columns.
2. Keep rows with zero quality flag, finite time/flux/uncertainty, and positive uncertainty; require at least **100** valid samples. Sort by time.
3. Merge duplicate timestamps using inverse-variance weighted flux and uncertainty `sqrt(1/sum(w))`.
4. Define robust scale as `1.4826 * MAD`, falling back to standard deviation and then `1.0` if necessary. Estimate cadence from positive timestamp differences and baseline from endpoint difference.
5. Local-outlier filter: median-filter flux with an odd window based on `0.30/cadence` and minimum 5; retain residuals `< 8*sigma` and `> -20*sigma`, and uncertainty below `4 * percentile(flux_err, 99.7)`.
6. Build robust time bins by integer floor grouping on `(t-t0)/width`. Within each bin keep values within `max(5*sigma, 5*median(error))` of the median; inverse-variance average time/flux and set bin error from measurement weight plus robust scatter exactly as specified in this procedure.
7. Weighted linear trends use centered/scaled time, weights `1/max(err,1e-12)^2`, and a diagonal `1e-12` regularizer.

## Checks

Recompute cadence/baseline after outlier filtering. All downstream fitting uses sorted, de-duplicated, filtered arrays.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

