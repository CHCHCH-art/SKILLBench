#!/bin/bash
set -euo pipefail

ROOT='/root'
NML='/root/glm3.nml'
OBS='/root/field_temp_oxy.csv'
BCS='/root/bcs'
OUT_DIR='/root/output'
OUT_NC='/root/output/output.nc'

GLM_BIN="$(command -v glm || true)"
[ -n "$GLM_BIN" ] || { echo 'ERROR: glm executable not found' >&2; exit 1; }
export GLM_BIN
[ -f "$NML" ] || { echo "ERROR: missing $NML" >&2; exit 1; }
[ -f "$OBS" ] || { echo "ERROR: missing $OBS" >&2; exit 1; }
[ -d "$BCS" ] || { echo "ERROR: missing $BCS" >&2; exit 1; }
mkdir -p "$OUT_DIR"

python3 -u <<'PYTHON'
import os
import re
import math
import shutil
import subprocess
from dataclasses import dataclass
from typing import Optional

import numpy as np
import pandas as pd
from netCDF4 import Dataset, num2date

ROOT = '/root'
GLM_BIN = os.environ['GLM_BIN']
NML_PATH = '/root/glm3.nml'
OBS_PATH = '/root/field_temp_oxy.csv'
OUT_DIR = '/root/output'
OUT_NC = '/root/output/output.nc'
HISTORY_CSV = '/root/output/calibration_history.csv'
SENSITIVITY_CSV = '/root/output/sensitivity.csv'
FINAL_MATCH_CSV = '/root/output/final_match.csv'
ORIGINAL_NML_COPY = '/root/output/glm3.original.nml'

SIM_START = '2009-01-01 00:00:00'
SIM_STOP = '2015-12-30 23:00:00'
RNG = np.random.default_rng(240509)

N_THERMAL = 24
N_MIXING = 20
N_GLOBAL = 48
LOCAL_STARTS = 4
LOCAL_SCALES = (0.12, 0.06, 0.03)
MAX_SWEEPS_PER_SCALE = 2

PARAMS = ('Kw', 'coef_mix_hyp', 'wind_factor', 'lw_factor', 'ch')
PARAM_SECTION = {
    'Kw': 'light',
    'coef_mix_hyp': 'mixing',
    'wind_factor': 'meteorology',
    'lw_factor': 'meteorology',
    'ch': 'meteorology',
}

@dataclass
class EvalResult:
    params: dict
    rmse_all: float
    score: float
    coverage: float
    rmse_shallow: float
    rmse_deep: float
    year_sd: float
    stage: str
    predictions: Optional[np.ndarray] = None


def section_span(text, section):
    m = re.search(rf'(?ims)^\s*&{re.escape(section)}\b.*?^\s*/(?:\s*!.*)?$', text)
    if not m:
        raise RuntimeError(f'Missing &{section} section in {NML_PATH}')
    return m.start(), m.end(), m.group(0)


def get_key(text, section, key):
    _, _, block = section_span(text, section)
    m = re.search(rf'(?im)^\s*{re.escape(key)}\s*=\s*([^!\n]+)', block)
    if not m:
        raise RuntimeError(f'Missing {key} in &{section}')
    raw = m.group(1).strip().rstrip(',').strip()
    return raw


def get_float(text, section, key):
    raw = get_key(text, section, key)
    raw = raw.replace('D', 'e').replace('d', 'e')
    return float(raw)


def set_key(text, section, key, value):
    start, end, block = section_span(text, section)
    pat = re.compile(rf'(?im)^(\s*{re.escape(key)}\s*=\s*)([^!\n]*)(.*)$')
    if pat.search(block):
        block2 = pat.sub(lambda m: m.group(1) + str(value) + m.group(3), block, count=1)
    else:
        lines = block.splitlines()
        insert_at = len(lines) - 1
        lines.insert(insert_at, f'   {key} = {value}')
        block2 = '\n'.join(lines)
    return text[:start] + block2 + text[end:]


def prepare_template(original):
    text = original
    text = set_key(text, 'time', 'timefmt', '2')
    text = set_key(text, 'time', 'start', f"'{SIM_START}'")
    text = set_key(text, 'time', 'stop', f"'{SIM_STOP}'")
    if not re.search(r'(?im)^\s*&output\b', text):
        text = text.rstrip() + f"\n\n&output\n   out_dir = '{OUT_DIR}'\n   out_fn = 'output'\n/\n"
    else:
        text = set_key(text, 'output', 'out_dir', f"'{OUT_DIR}'")
        text = set_key(text, 'output', 'out_fn', "'output'")
    return text


def format_param(name, value):
    if name == 'ch':
        return f'{float(value):.8g}'
    return f'{float(value):.7g}'


def render_nml(template, params):
    text = template
    for name in PARAMS:
        text = set_key(text, PARAM_SECTION[name], name, format_param(name, params[name]))
    return text


def detect_obs_columns(df):
    lower = {c.lower(): c for c in df.columns}
    def pick(exact, contains):
        for x in exact:
            if x in lower:
                return lower[x]
        for c in df.columns:
            lc = c.lower()
            if any(k in lc for k in contains):
                return c
        return None
    dt_col = pick(('datetime', 'date_time', 'timestamp', 'date'), ('datetime', 'timestamp', 'date'))
    depth_col = pick(('depth', 'depth_m', 'z'), ('depth',))
    temp_col = pick(('temp', 'temperature', 'water_temp', 'wtemp'), ('temp',))
    if not dt_col or not depth_col or not temp_col:
        raise RuntimeError(f'Could not identify datetime/depth/temp columns in {list(df.columns)}')
    return dt_col, depth_col, temp_col


def read_observations(path):
    raw = pd.read_csv(path)
    dt_col, depth_col, temp_col = detect_obs_columns(raw)
    out = pd.DataFrame({
        'datetime': pd.to_datetime(raw[dt_col], errors='coerce'),
        'depth': pd.to_numeric(raw[depth_col], errors='coerce'),
        'temp_obs': pd.to_numeric(raw[temp_col], errors='coerce'),
    })
    out = out.dropna().reset_index(drop=True)
    t0 = pd.Timestamp(SIM_START)
    t1 = pd.Timestamp(SIM_STOP)
    out = out[(out['datetime'] >= t0) & (out['datetime'] <= t1)].copy()
    if out.empty:
        raise RuntimeError('No valid field temperature observations in simulation window')
    out['obs_id'] = np.arange(len(out), dtype=int)
    return out.reset_index(drop=True)


def nc_time_to_datetime64(time_var):
    values = np.asarray(time_var[:], dtype=float)
    units = getattr(time_var, 'units', '')
    calendar = getattr(time_var, 'calendar', 'standard')
    if isinstance(units, bytes):
        units = units.decode('utf-8', 'ignore')
    if 'since' in str(units).lower():
        dates = num2date(values, units=units, calendar=calendar,
                         only_use_cftime_datetimes=False,
                         only_use_python_datetimes=True)
        arr = []
        for d in dates:
            arr.append(np.datetime64(
                f'{d.year:04d}-{d.month:02d}-{d.day:02d}T'
                f'{d.hour:02d}:{d.minute:02d}:{d.second:02d}', 'ns'))
        return np.asarray(arr, dtype='datetime64[ns]')

    base = np.datetime64(SIM_START.replace(' ', 'T'), 'ns')
    elapsed_ns = np.rint(values * 3600.0 * 1e9).astype(np.int64)
    return base + elapsed_ns.astype('timedelta64[ns]')


def get_profile_slice(var, t_idx, n_time):
    if var.ndim >= 2 and var.shape[0] == n_time:
        a = var[t_idx]
    elif var.ndim == 1 and var.shape[0] == n_time:
        a = var[t_idx:t_idx+1]
    else:
        a = var[:]
    if np.ma.isMaskedArray(a):
        a = np.ma.filled(a, np.nan)
    return np.asarray(a, dtype=float).squeeze().reshape(-1)


def interp_profile(depths, temps, target_depth):
    ok = np.isfinite(depths) & np.isfinite(temps)
    depths = depths[ok]
    temps = temps[ok]
    if len(depths) == 0:
        return np.nan

    order = np.argsort(depths)
    depths = depths[order]
    temps = temps[order]

    if len(depths) > 1 and np.any(np.diff(depths) == 0):
        tmp = pd.DataFrame({'d': depths, 't': temps}).groupby('d', as_index=False)['t'].mean()
        depths = tmp['d'].to_numpy(float)
        temps = tmp['t'].to_numpy(float)

    d = float(target_depth)
    if d < depths[0]:
        return float(temps[0]) if depths[0] - d <= 1.0 else np.nan
    if d > depths[-1]:
        return float(temps[-1]) if d - depths[-1] <= 1.0 else np.nan
    return float(np.interp(d, depths, temps))


def predictions_at_observations(nc_path, obs):
    pred = np.full(len(obs), np.nan, dtype=float)
    with Dataset(nc_path, 'r') as nc:
        if 'time' not in nc.variables or 'z' not in nc.variables or 'temp' not in nc.variables:
            raise RuntimeError('output.nc must contain time, z and temp variables')
        times = nc_time_to_datetime64(nc.variables['time'])
        if len(times) == 0:
            return pred
        n_time = len(times)
        z_var = nc.variables['z']
        t_var = nc.variables['temp']

        obs_times = obs['datetime'].to_numpy(dtype='datetime64[ns]')
        pos = np.searchsorted(times, obs_times)
        pos = np.clip(pos, 0, n_time - 1)
        left = np.clip(pos - 1, 0, n_time - 1)
        choose_left = np.abs(obs_times - times[left]) <= np.abs(times[pos] - obs_times)
        nearest = np.where(choose_left, left, pos)

        if n_time > 1:
            med_step_ns = float(np.median(np.diff(times).astype('timedelta64[ns]').astype(np.int64)))
            tol_ns = max(12 * 3600 * 1e9, 0.75 * med_step_ns)
        else:
            tol_ns = 24 * 3600 * 1e9

        delta_ns = np.abs((obs_times - times[nearest]).astype('timedelta64[ns]').astype(np.int64))
        time_ok = delta_ns <= tol_ns

        for ti in np.unique(nearest[time_ok]):
            rows = np.where((nearest == ti) & time_ok)[0]
            z = get_profile_slice(z_var, int(ti), n_time)
            temp = get_profile_slice(t_var, int(ti), n_time)
            n = min(len(z), len(temp))
            z = z[:n]
            temp = temp[:n]
            valid = np.isfinite(z) & np.isfinite(temp)
            if not np.any(valid):
                continue
            z = z[valid]
            temp = temp[valid]
            surface_h = float(np.max(z))
            depths = surface_h - z
            for r in rows:
                pred[r] = interp_profile(depths, temp, obs.iloc[r]['depth'])
    return pred


def rmse(obs_values, pred_values, mask=None):
    valid = np.isfinite(obs_values) & np.isfinite(pred_values)
    if mask is not None:
        valid &= mask
    if valid.sum() == 0:
        return 999.0
    return float(np.sqrt(np.mean((pred_values[valid] - obs_values[valid]) ** 2)))


def metric_bundle(obs, pred):
    y = obs['temp_obs'].to_numpy(float)
    valid = np.isfinite(pred)
    coverage = float(valid.mean())
    all_rmse = rmse(y, pred)

    q35 = float(obs['depth'].quantile(0.35))
    q65 = float(obs['depth'].quantile(0.65))
    shallow_mask = obs['depth'].to_numpy(float) <= max(2.0, q35)
    deep_mask = obs['depth'].to_numpy(float) >= q65
    shallow_rmse = rmse(y, pred, shallow_mask)
    deep_rmse = rmse(y, pred, deep_mask)

    year_rmses = []
    years = obs['datetime'].dt.year.to_numpy()
    for yr in np.unique(years):
        v = (years == yr) & valid
        if v.sum() >= 3:
            year_rmses.append(rmse(y, pred, v))
    year_sd = float(np.std(year_rmses)) if len(year_rmses) >= 2 else 0.0

    score = all_rmse + 0.08 * year_sd + 4.0 * max(0.0, 0.98 - coverage)
    return all_rmse, score, coverage, shallow_rmse, deep_rmse, year_sd


with open(NML_PATH, 'r', encoding='utf-8') as f:
    ORIGINAL_NML = f.read()
shutil.copyfile(NML_PATH, ORIGINAL_NML_COPY)
TEMPLATE = prepare_template(ORIGINAL_NML)
OBS = read_observations(OBS_PATH)
OBS_Y = OBS['temp_obs'].to_numpy(float)

START_PARAMS = {p: get_float(TEMPLATE, PARAM_SECTION[p], p) for p in PARAMS}

DEFAULT_BOUNDS = {
    'Kw': (0.10, 1.20),
    'coef_mix_hyp': (0.05, 2.00),
    'wind_factor': (0.60, 1.40),
    'lw_factor': (0.80, 1.20),
    'ch': (0.00060, 0.00250),
}
BOUNDS = {}
for p in PARAMS:
    lo, hi = DEFAULT_BOUNDS[p]
    v = START_PARAMS[p]
    if p == 'ch':
        lo = min(lo, max(1e-5, 0.7 * v))
        hi = max(hi, 1.4 * v)
    else:
        lo = min(lo, 0.7 * v)
        hi = max(hi, 1.4 * v)
    BOUNDS[p] = (float(lo), float(hi))

CACHE = {}
HISTORY = []
RUN_ID = 0
BEST = None


def candidate_key(params):
    return tuple(round(float(params[p]), 8) for p in PARAMS)


def clamp_params(params):
    out = {}
    for p in PARAMS:
        lo, hi = BOUNDS[p]
        out[p] = float(np.clip(params[p], lo, hi))
    return out


def run_candidate(params, stage, keep_predictions=False):
    global RUN_ID, BEST
    params = clamp_params(params)
    key = candidate_key(params)
    if key in CACHE:
        old = CACHE[key]
        return EvalResult(params=old.params.copy(), rmse_all=old.rmse_all,
                          score=old.score, coverage=old.coverage,
                          rmse_shallow=old.rmse_shallow, rmse_deep=old.rmse_deep,
                          year_sd=old.year_sd, stage=stage,
                          predictions=(old.predictions.copy() if old.predictions is not None else None))

    RUN_ID += 1
    with open(NML_PATH, 'w', encoding='utf-8') as f:
        f.write(render_nml(TEMPLATE, params))
    if os.path.exists(OUT_NC):
        os.remove(OUT_NC)

    cp = subprocess.run([GLM_BIN], cwd=ROOT, stdout=subprocess.PIPE,
                        stderr=subprocess.STDOUT, text=True)
    if cp.returncode != 0 or not os.path.isfile(OUT_NC):
        print(f'[{RUN_ID:03d}] {stage:12s} GLM FAILED')
        print(cp.stdout[-3000:])
        result = EvalResult(params.copy(), 999.0, 999.0, 0.0, 999.0, 999.0, 999.0, stage)
    else:
        pred = predictions_at_observations(OUT_NC, OBS)
        vals = metric_bundle(OBS, pred)
        result = EvalResult(params.copy(), *vals, stage=stage,
                            predictions=(pred.copy() if keep_predictions else None))
        print(f'[{RUN_ID:03d}] {stage:12s} RMSE={result.rmse_all:6.3f} '
              f'cov={result.coverage:5.1%} shallow={result.rmse_shallow:6.3f} '
              f'deep={result.rmse_deep:6.3f} | '
              f"Kw={params['Kw']:.4g} hyp={params['coef_mix_hyp']:.4g} "
              f"wind={params['wind_factor']:.4g} lw={params['lw_factor']:.4g} ch={params['ch']:.5g}")

    CACHE[key] = result
    HISTORY.append({
        'run_id': RUN_ID, 'stage': stage,
        **{p: result.params[p] for p in PARAMS},
        'rmse_all': result.rmse_all, 'score': result.score,
        'coverage': result.coverage,
        'rmse_shallow': result.rmse_shallow,
        'rmse_deep': result.rmse_deep,
        'year_sd': result.year_sd,
    })
    if result.rmse_all < 900 and (BEST is None or result.rmse_all < BEST.rmse_all):
        BEST = EvalResult(result.params.copy(), result.rmse_all, result.score,
                          result.coverage, result.rmse_shallow, result.rmse_deep,
                          result.year_sd, result.stage,
                          result.predictions.copy() if result.predictions is not None else None)
    return result


def latin_hypercube(names, n):
    d = len(names)
    unit = np.empty((n, d), dtype=float)
    for j in range(d):
        unit[:, j] = (np.arange(n) + RNG.random(n)) / n
        RNG.shuffle(unit[:, j])
    rows = []
    for i in range(n):
        p = START_PARAMS.copy()
        for j, name in enumerate(names):
            lo, hi = BOUNDS[name]
            if name == 'ch':
                p[name] = math.exp(math.log(lo) + unit[i, j] * (math.log(hi) - math.log(lo)))
            else:
                p[name] = lo + unit[i, j] * (hi - lo)
        rows.append(p)
    return rows


def stage_rank(results, metric):
    finite = [r for r in results if getattr(r, metric) < 900]
    if not finite:
        return []
    return sorted(finite, key=lambda r: (getattr(r, metric), r.score))


print('=' * 78)
print('GLM staged calibration: profile interpolation + global search + multi-start refinement')
print('=' * 78)
print(f'Observations: {len(OBS)}')
print('Initial parameters:', START_PARAMS)
print('Bounds:', BOUNDS)

baseline = run_candidate(START_PARAMS, 'baseline')
sens_rows = []
for p in PARAMS:
    lo, hi = BOUNDS[p]
    for label, value in (('low', lo), ('high', hi)):
        cand = START_PARAMS.copy()
        cand[p] = value
        r = run_candidate(cand, 'sensitivity')
        sens_rows.append({'parameter': p, 'level': label, 'value': value,
                          'rmse_all': r.rmse_all,
                          'delta_vs_baseline': r.rmse_all - baseline.rmse_all})
pd.DataFrame(sens_rows).to_csv(SENSITIVITY_CSV, index=False)

thermal_results = []
for cand in latin_hypercube(('Kw', 'lw_factor', 'ch'), N_THERMAL):
    cand['coef_mix_hyp'] = START_PARAMS['coef_mix_hyp']
    cand['wind_factor'] = START_PARAMS['wind_factor']
    thermal_results.append(run_candidate(cand, 'thermal'))
thermal_ranked = stage_rank(thermal_results, 'rmse_shallow')
thermal_seed = thermal_ranked[0].params.copy() if thermal_ranked else START_PARAMS.copy()

mixing_results = []
for cand0 in latin_hypercube(('coef_mix_hyp', 'wind_factor'), N_MIXING):
    cand = thermal_seed.copy()
    cand['coef_mix_hyp'] = cand0['coef_mix_hyp']
    cand['wind_factor'] = cand0['wind_factor']
    mixing_results.append(run_candidate(cand, 'mixing'))
mixing_ranked = stage_rank(mixing_results, 'rmse_deep')
combined_seed = mixing_ranked[0].params.copy() if mixing_ranked else thermal_seed.copy()

global_results = [run_candidate(combined_seed, 'joint-seed'),
                  run_candidate(START_PARAMS, 'joint-seed')]
for cand in latin_hypercube(PARAMS, N_GLOBAL):
    global_results.append(run_candidate(cand, 'joint-global'))

all_valid = [r for r in global_results + thermal_results + mixing_results + [baseline]
             if r.rmse_all < 900]
seeds = sorted(all_valid, key=lambda r: (r.rmse_all, r.score))[:LOCAL_STARTS]
if not seeds:
    raise RuntimeError('No successful GLM candidate was produced')

for sidx, seed in enumerate(seeds, start=1):
    current = seed.params.copy()
    current_r = run_candidate(current, f'local{sidx}')
    for scale in LOCAL_SCALES:
        for _sweep in range(MAX_SWEEPS_PER_SCALE):
            best_here = current_r
            best_params_here = current.copy()
            for p in PARAMS:
                lo, hi = BOUNDS[p]
                span = hi - lo
                for direction in (-1.0, 1.0):
                    cand = current.copy()
                    if p == 'ch':
                        factor = math.exp(direction * scale * (math.log(hi) - math.log(lo)))
                        cand[p] = cand[p] * factor
                    else:
                        cand[p] = cand[p] + direction * scale * span
                    cand = clamp_params(cand)
                    r = run_candidate(cand, f'local{sidx}')
                    if (r.rmse_all, r.score) < (best_here.rmse_all, best_here.score):
                        best_here = r
                        best_params_here = cand.copy()
            if best_here.rmse_all + 1e-6 < current_r.rmse_all:
                current = best_params_here
                current_r = best_here
            else:
                break

pd.DataFrame(HISTORY).to_csv(HISTORY_CSV, index=False)

if BEST is None:
    raise RuntimeError('Calibration produced no valid result')

with open(NML_PATH, 'w', encoding='utf-8') as f:
    f.write(render_nml(TEMPLATE, BEST.params))
if os.path.exists(OUT_NC):
    os.remove(OUT_NC)
cp = subprocess.run([GLM_BIN], cwd=ROOT, stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT, text=True)
if cp.returncode != 0 or not os.path.isfile(OUT_NC):
    print(cp.stdout[-5000:])
    raise RuntimeError('Final GLM run failed')

final_pred = predictions_at_observations(OUT_NC, OBS)
final_metrics = metric_bundle(OBS, final_pred)
final_rmse = final_metrics[0]
match = OBS[['datetime', 'depth', 'temp_obs']].copy()
match['temp_sim'] = final_pred
match['residual'] = match['temp_sim'] - match['temp_obs']
match.to_csv(FINAL_MATCH_CSV, index=False)

print('=' * 78)
print('Calibration complete')
print('Best parameters:')
for p in PARAMS:
    print(f'  {p:14s} = {BEST.params[p]:.8g}')
print(f'Final interpolated RMSE = {final_rmse:.4f} degC')
print(f'Output NetCDF           = {OUT_NC}')
print(f'Final namelist          = {NML_PATH}')
print(f'Calibration history     = {HISTORY_CSV}')
print(f'Observation match       = {FINAL_MATCH_CSV}')
print('=' * 78)

if not np.isfinite(final_rmse) or final_rmse >= 2.0:
    raise SystemExit(f'Calibration finished but RMSE target was not met: {final_rmse:.4f} >= 2.0')
PYTHON

test -s "$OUT_NC"
test -s "$NML"
