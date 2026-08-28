#!/bin/bash
set -euo pipefail

python3 <<'PYTHON_SCRIPT'
import warnings
warnings.filterwarnings("ignore")

import numpy as np
from scipy.linalg import cho_factor, cho_solve
from scipy.ndimage import median_filter
from scipy.optimize import minimize
from astropy.timeseries import BoxLeastSquares, LombScargle

INPUT_PATH = "/root/data/tess_lc.txt"
OUTPUT_PATH = "/root/period.txt"


def scalar_value(x):
    """Convert numpy/astropy scalar-like values to float."""
    if hasattr(x, "value"):
        x = x.value
    return float(np.asarray(x).reshape(-1)[0])


def robust_scale(x):
    x = np.asarray(x, dtype=float)
    x = x[np.isfinite(x)]
    if x.size == 0:
        return 1.0
    med = np.median(x)
    mad = np.median(np.abs(x - med))
    scale = 1.4826 * mad
    if not np.isfinite(scale) or scale <= 0:
        scale = np.std(x)
    return float(scale if np.isfinite(scale) and scale > 0 else 1.0)


def weighted_linear_trend(t_train, y_train, err_train, t_eval):
    """Fit and evaluate a weighted linear mean function."""
    center = np.median(t_train)
    scale = max(np.ptp(t_train), 1.0)
    x = (t_train - center) / scale
    xe = (t_eval - center) / scale
    X = np.column_stack((np.ones_like(x), x))
    w = 1.0 / np.maximum(err_train, 1e-12) ** 2
    lhs = X.T @ (w[:, None] * X)
    rhs = X.T @ (w * y_train)
    lhs.flat[:: lhs.shape[0] + 1] += 1e-12
    beta = np.linalg.solve(lhs, rhs)
    return beta[0] + beta[1] * xe


def robust_time_bins(t, y, err, width):
    """Build a robust binned representation for the GP activity model."""
    group = np.floor((t - t[0]) / width).astype(np.int64)
    boundaries = np.flatnonzero(np.r_[True, group[1:] != group[:-1], True])

    tb, yb, eb = [], [], []
    for lo, hi in zip(boundaries[:-1], boundaries[1:]):
        yy = y[lo:hi]
        tt = t[lo:hi]
        ee = err[lo:hi]
        if yy.size == 0:
            continue

        med = np.median(yy)
        sig = robust_scale(yy)
        keep = np.abs(yy - med) <= max(5.0 * sig, 5.0 * np.median(ee))
        if not np.any(keep):
            keep = np.ones(yy.size, dtype=bool)

        yy = yy[keep]
        tt = tt[keep]
        ee = ee[keep]
        ww = 1.0 / np.maximum(ee, 1e-12) ** 2
        sw = np.sum(ww)
        y_mean = np.sum(ww * yy) / sw
        t_mean = np.sum(ww * tt) / sw
        scatter = robust_scale(yy)
        e_mean = np.sqrt(1.0 / sw + scatter * scatter / max(yy.size, 1))

        tb.append(t_mean)
        yb.append(y_mean)
        eb.append(max(e_mean, np.median(ee) / np.sqrt(max(yy.size, 1))))

    return np.asarray(tb), np.asarray(yb), np.asarray(eb)


def qp_kernel_from_dt(dt, amplitude, decay, coherence, rotation_period):
    """Quasi-periodic covariance for evolving rotational modulation."""
    periodic = np.sin(np.pi * dt / rotation_period)
    exponent = -0.5 * (dt / decay) ** 2 - 2.0 * periodic * periodic / (coherence ** 2)
    return amplitude * amplitude * np.exp(exponent)


def gp_neg_loglike(log_params, dt, residual, err, rotation_period):
    amplitude, decay, coherence, jitter = np.exp(log_params)
    K = qp_kernel_from_dt(dt, amplitude, decay, coherence, rotation_period)
    diag = err * err + jitter * jitter + 1e-12
    K.flat[:: K.shape[0] + 1] += diag
    try:
        factor = cho_factor(K, lower=True, overwrite_a=True, check_finite=False)
        alpha = cho_solve(factor, residual, check_finite=False)
    except Exception:
        return 1e100
    logdet = 2.0 * np.sum(np.log(np.diag(factor[0])))
    value = 0.5 * (residual @ alpha + logdet + residual.size * np.log(2.0 * np.pi))
    return float(value) if np.isfinite(value) else 1e100


def fit_gp_hyperparameters(tb, yb, eb, candidate_periods, baseline, cadence):
    """Evaluate rotation aliases, then locally optimize the GP hyperparameters."""
    mean = weighted_linear_trend(tb, yb, eb, tb)
    residual = yb - mean
    dt = tb[:, None] - tb[None, :]

    amp0 = max(robust_scale(residual), 5e-5)
    err0 = max(np.median(eb), 1e-7)
    best = None

    for rotation_period in candidate_periods:
        decay_seeds = np.clip(
            np.asarray([0.7, 1.5, 3.0]) * rotation_period,
            max(4.0 * cadence, 0.15),
            max(0.3, 5.0 * baseline),
        )
        coherence_seeds = (0.45, 0.9, 1.8)
        jitter_seeds = (err0, max(2.5 * err0, 0.08 * amp0))

        local_best = None
        for decay in decay_seeds:
            for coherence in coherence_seeds:
                for jitter in jitter_seeds:
                    initial = np.log([amp0, decay, coherence, jitter])
                    nll = gp_neg_loglike(initial, dt, residual, eb, rotation_period)
                    if local_best is None or nll < local_best[0]:
                        local_best = (nll, initial)

        lower = np.log([
            max(0.03 * amp0, 1e-7),
            max(4.0 * cadence, 0.12),
            0.20,
            max(0.05 * err0, 1e-8),
        ])
        upper = np.log([
            max(8.0 * amp0, 1e-4),
            max(5.0 * baseline, 0.5),
            5.0,
            max(3.0 * amp0, 20.0 * err0),
        ])

        result = minimize(
            gp_neg_loglike,
            local_best[1],
            args=(dt, residual, eb, rotation_period),
            method="L-BFGS-B",
            bounds=list(zip(lower, upper)),
            options={"maxiter": 12, "maxfun": 90, "ftol": 1e-7},
        )
        nll = float(result.fun) if np.isfinite(result.fun) else local_best[0]
        params = result.x if np.all(np.isfinite(result.x)) else local_best[1]
        if best is None or nll < best[0]:
            best = (nll, rotation_period, params)

    _, period0, params0 = best
    trial_periods = np.linspace(0.88 * period0, 1.12 * period0, 9)
    for rotation_period in trial_periods:
        nll = gp_neg_loglike(params0, dt, residual, eb, rotation_period)
        if nll < best[0]:
            best = (nll, rotation_period, params0.copy())

    return best[1], np.exp(best[2])


def gp_predict(tb, yb, eb, t_eval, rotation_period, hyperparameters, train_mask=None):
    """Fit the GP on selected binned points and predict the activity baseline."""
    if train_mask is None:
        train_mask = np.ones(tb.size, dtype=bool)

    tt = tb[train_mask]
    yy = yb[train_mask]
    ee = eb[train_mask]
    if tt.size < 20:
        tt, yy, ee = tb, yb, eb

    mean_train = weighted_linear_trend(tt, yy, ee, tt)
    mean_eval = weighted_linear_trend(tt, yy, ee, t_eval)
    residual = yy - mean_train

    amplitude, decay, coherence, jitter = hyperparameters
    dt_train = tt[:, None] - tt[None, :]
    K = qp_kernel_from_dt(dt_train, amplitude, decay, coherence, rotation_period)
    K.flat[:: K.shape[0] + 1] += ee * ee + jitter * jitter + 1e-12
    factor = cho_factor(K, lower=True, overwrite_a=True, check_finite=False)
    alpha = cho_solve(factor, residual, check_finite=False)

    prediction = np.empty_like(t_eval)
    chunk_size = max(1000, int(2.0e7 / max(tt.size, 1)))
    for start in range(0, t_eval.size, chunk_size):
        stop = min(start + chunk_size, t_eval.size)
        dt_cross = t_eval[start:stop, None] - tt[None, :]
        K_cross = qp_kernel_from_dt(
            dt_cross, amplitude, decay, coherence, rotation_period
        )
        prediction[start:stop] = mean_eval[start:stop] + K_cross @ alpha
    return prediction


def make_period_grid(period_min, period_max, baseline, samples_per_peak):
    df = 1.0 / (baseline * samples_per_peak)
    frequencies = np.arange(1.0 / period_max, 1.0 / period_min + 0.5 * df, df)
    periods = 1.0 / frequencies[::-1]
    return periods


def run_bls(t, y, err, period_min, period_max, baseline, samples_per_peak, durations):
    periods = make_period_grid(period_min, period_max, baseline, samples_per_peak)
    model = BoxLeastSquares(t, y, dy=err)
    result = model.power(
        periods,
        durations,
        objective="likelihood",
        method="fast",
        oversample=10,
    )
    index = int(np.nanargmax(np.asarray(result.power)))
    return model, result, index


def extract_depth_pair(stats, key):
    value = stats.get(key)
    if value is None:
        return None
    try:
        depth = scalar_value(value[0])
        uncertainty = abs(scalar_value(value[1]))
        if uncertainty <= 0 or not np.isfinite(uncertainty):
            return None
        return depth, uncertainty
    except Exception:
        return None


def candidate_score(model, period, duration, transit_time, raw_power):
    """Penalize half-period aliases using odd/even transit consistency."""
    score = float(raw_power)
    try:
        stats = model.compute_stats(period, duration, transit_time)
        odd = extract_depth_pair(stats, "depth_odd")
        even = extract_depth_pair(stats, "depth_even")
        if odd is not None and even is not None:
            z = abs(odd[0] - even[0]) / np.hypot(odd[1], even[1])
            if np.isfinite(z) and z > 1.5:
                score -= 0.5 * (z - 1.5) ** 2

        counts = stats.get("per_transit_count")
        if counts is not None:
            counts = np.asarray(counts)
            observed_events = int(np.sum(counts > 0))
            if observed_events < 2:
                score -= 1e6
    except Exception:
        pass
    return score


data = np.loadtxt(INPUT_PATH)
if data.ndim == 1:
    data = data.reshape(1, -1)
if data.shape[1] < 4:
    raise ValueError("Expected four columns: time, flux, quality flag, uncertainty")

time = np.asarray(data[:, 0], dtype=float)
flux = np.asarray(data[:, 1], dtype=float)
quality = np.asarray(data[:, 2])
flux_err = np.asarray(data[:, 3], dtype=float)

valid = (
    (quality == 0)
    & np.isfinite(time)
    & np.isfinite(flux)
    & np.isfinite(flux_err)
    & (flux_err > 0)
)
time, flux, flux_err = time[valid], flux[valid], flux_err[valid]
if time.size < 100:
    raise RuntimeError("Too few valid TESS samples")

order = np.argsort(time)
time, flux, flux_err = time[order], flux[order], flux_err[order]

unique_time, first, counts = np.unique(time, return_index=True, return_counts=True)
if np.any(counts > 1):
    new_flux = np.empty(unique_time.size)
    new_err = np.empty(unique_time.size)
    for i, (start, count) in enumerate(zip(first, counts)):
        sl = slice(start, start + count)
        w = 1.0 / flux_err[sl] ** 2
        new_flux[i] = np.sum(w * flux[sl]) / np.sum(w)
        new_err[i] = np.sqrt(1.0 / np.sum(w))
    time, flux, flux_err = unique_time, new_flux, new_err

cadence = float(np.median(np.diff(time)[np.diff(time) > 0]))
baseline = float(time[-1] - time[0])
if not np.isfinite(cadence) or cadence <= 0 or baseline <= 0:
    raise RuntimeError("Invalid time sampling")

window_points = int(max(5, round(0.30 / cadence)))
if window_points % 2 == 0:
    window_points += 1
window_points = min(window_points, time.size - (1 - time.size % 2))
local_median = median_filter(flux, size=max(3, window_points), mode="nearest")
local_residual = flux - local_median
local_sigma = robust_scale(local_residual)
error_limit = np.percentile(flux_err, 99.7) * 4.0
keep = (
    (local_residual < 8.0 * local_sigma)
    & (local_residual > -20.0 * local_sigma)
    & (flux_err < error_limit)
)
time, flux, flux_err = time[keep], flux[keep], flux_err[keep]
cadence = float(np.median(np.diff(time)[np.diff(time) > 0]))
baseline = float(time[-1] - time[0])

ls_bin_width = max(0.08, 10.0 * cadence)
t_ls, f_ls, e_ls = robust_time_bins(time, flux, flux_err, ls_bin_width)
ls_mean = weighted_linear_trend(t_ls, f_ls, e_ls, t_ls)
ls_residual = f_ls - ls_mean

activity_period_min = max(0.5, 20.0 * cadence)
activity_period_max = min(0.80 * baseline, 20.0)
if activity_period_max <= 1.5 * activity_period_min:
    activity_period_max = min(0.90 * baseline, 4.0 * activity_period_min)

frequency, power = LombScargle(t_ls, ls_residual, e_ls).autopower(
    minimum_frequency=1.0 / activity_period_max,
    maximum_frequency=1.0 / activity_period_min,
    samples_per_peak=20,
)
rotation_seed = 1.0 / frequency[int(np.nanargmax(power))]

rotation_candidates = [rotation_seed]
for candidate in (0.5 * rotation_seed, 2.0 * rotation_seed):
    if activity_period_min <= candidate <= activity_period_max:
        if all(abs(candidate - p) / p > 0.05 for p in rotation_candidates):
            rotation_candidates.append(candidate)

gp_bin_width = max(12.0 * cadence, 0.035, baseline / 520.0)
t_bin, f_bin, e_bin = robust_time_bins(time, flux, flux_err, gp_bin_width)
if t_bin.size > 560:
    select = np.linspace(0, t_bin.size - 1, 560).round().astype(int)
    t_bin, f_bin, e_bin = t_bin[select], f_bin[select], e_bin[select]

bin_window = int(max(5, round(max(0.4, 0.12 * rotation_seed) / gp_bin_width)))
if bin_window % 2 == 0:
    bin_window += 1
bin_window = min(bin_window, t_bin.size - (1 - t_bin.size % 2))
bin_med = median_filter(f_bin, size=max(3, bin_window), mode="nearest")
bin_res = f_bin - bin_med
bin_sig = robust_scale(bin_res)
initial_gp_mask = (bin_res < 6.0 * bin_sig) & (bin_res > -5.0 * bin_sig)
if np.sum(initial_gp_mask) >= 40:
    fit_t, fit_f, fit_e = t_bin[initial_gp_mask], f_bin[initial_gp_mask], e_bin[initial_gp_mask]
else:
    fit_t, fit_f, fit_e = t_bin, f_bin, e_bin

rotation_period, gp_hyperparameters = fit_gp_hyperparameters(
    fit_t,
    fit_f,
    fit_e,
    rotation_candidates,
    baseline,
    cadence,
)

activity_initial = gp_predict(
    t_bin,
    f_bin,
    e_bin,
    time,
    rotation_period,
    gp_hyperparameters,
    train_mask=initial_gp_mask if initial_gp_mask.size == t_bin.size else None,
)
flat_initial = flux - activity_initial + np.median(activity_initial)
flat_initial /= np.median(flat_initial)
err_initial = flux_err / np.median(activity_initial)

period_min = max(0.60, 10.0 * cadence)
period_max = min(30.0, 0.50 * baseline)
if period_max <= 1.5 * period_min:
    period_max = min(0.80 * baseline, 4.0 * period_min)
if period_max <= period_min:
    raise RuntimeError("Time baseline is too short for a transit period search")

duration_min = max(2.5 * cadence, 0.018)
duration_max = min(0.18, 0.22 * period_min)
if duration_max <= duration_min:
    duration_max = 1.5 * duration_min
durations = np.linspace(duration_min, duration_max, 12)

pre_model, pre_result, pre_index = run_bls(
    time,
    flat_initial,
    err_initial,
    period_min,
    period_max,
    baseline,
    samples_per_peak=120,
    durations=durations,
)
pre_period = scalar_value(pre_result.period[pre_index])
pre_duration = scalar_value(pre_result.duration[pre_index])
pre_t0 = scalar_value(pre_result.transit_time[pre_index])

phase_bin = ((t_bin - pre_t0 + 0.5 * pre_period) % pre_period) - 0.5 * pre_period
transit_free = np.abs(phase_bin) > 0.80 * pre_duration
transit_free &= initial_gp_mask
if np.sum(transit_free) < 30:
    transit_free = initial_gp_mask

activity_final = gp_predict(
    t_bin,
    f_bin,
    e_bin,
    time,
    rotation_period,
    gp_hyperparameters,
    train_mask=transit_free,
)
flat_flux = flux - activity_final + np.median(activity_final)
normalization = np.median(flat_flux)
flat_flux /= normalization
flat_err = flux_err / normalization

final_model, final_result, final_index = run_bls(
    time,
    flat_flux,
    flat_err,
    period_min,
    period_max,
    baseline,
    samples_per_peak=300,
    durations=durations,
)

period_array = np.asarray(final_result.period, dtype=float)
power_array = np.asarray(final_result.power, dtype=float)
order = np.argsort(np.nan_to_num(power_array, nan=-np.inf))[::-1]
coarse_df = 1.0 / (baseline * 300.0)

peak_periods = []
for idx in order:
    p = period_array[idx]
    f = 1.0 / p
    if all(abs(f - 1.0 / old) > 4.0 * coarse_df for old in peak_periods):
        peak_periods.append(p)
    if len(peak_periods) >= 7:
        break

candidate_periods = []
for p in peak_periods:
    for candidate in (p, 0.5 * p, 2.0 * p):
        if period_min <= candidate <= period_max:
            if all(abs(candidate - old) / old > 2e-4 for old in candidate_periods):
                candidate_periods.append(candidate)

best_candidate = None
for candidate in candidate_periods:
    center_frequency = 1.0 / candidate
    half_width = max(6.0 * coarse_df, 2.0e-5 / max(candidate * candidate, 1e-12))
    f_lo = max(1.0 / period_max, center_frequency - half_width)
    f_hi = min(1.0 / period_min, center_frequency + half_width)
    local_frequency = np.linspace(f_lo, f_hi, 12001)
    local_periods = 1.0 / local_frequency[::-1]

    local_result = final_model.power(
        local_periods,
        durations,
        objective="likelihood",
        method="fast",
        oversample=15,
    )
    local_index = int(np.nanargmax(np.asarray(local_result.power)))
    p = scalar_value(local_result.period[local_index])
    d = scalar_value(local_result.duration[local_index])
    t0 = scalar_value(local_result.transit_time[local_index])
    raw_power = scalar_value(local_result.power[local_index])
    score = candidate_score(final_model, p, d, t0, raw_power)

    if best_candidate is None or score > best_candidate[0]:
        best_candidate = (score, p, d, t0, raw_power)

if best_candidate is None or not np.isfinite(best_candidate[1]):
    period_final = scalar_value(final_result.period[final_index])
else:
    period_final = best_candidate[1]

with open(OUTPUT_PATH, "w", encoding="utf-8") as handle:
    handle.write(f"{period_final:.5f}\n")

print(f"Estimated stellar rotation timescale: {rotation_period:.5f} d")
print(f"Best-fit exoplanet period: {period_final:.5f} d")
print(f"Written to {OUTPUT_PATH}")
PYTHON_SCRIPT
