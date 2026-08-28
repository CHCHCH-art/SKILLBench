#!/bin/bash
set -euo pipefail

cd /root

python3 -u <<'PY'
import os
import time

import numpy as np
import pandas as pd
from pycbc.filter import highpass, matched_filter, resample_to_delta_t
from pycbc.frame import read_frame
from pycbc.psd import interpolate, inverse_spectrum_truncation
from pycbc.waveform import get_td_waveform

FRAME_PATH = "/root/data/PyCBC_T2_2.gwf"
CHANNEL = "H1:TEST-STRAIN"
OUTPUT_PATH = "/root/detection_results.csv"
DIAGNOSTICS_PATH = "/root/detection_search_diagnostics.csv"

APPROXIMANTS = ("SEOBNRv4_opt", "IMRPhenomD", "TaylorT4")
MASS_VALUES = tuple(range(10, 41))
LOW_FREQUENCY_CUTOFF = 20.0
HIGHPASS_FREQUENCY = 15.0

STAGES = (
    {
        "name": "discovery",
        "sample_rate": 2048,
        "psd_segment_seconds": 8,
        "crop_start_seconds": 12,
        "crop_end_seconds": 8,
    },
    {
        "name": "confirmation",
        "sample_rate": 4096,
        "psd_segment_seconds": 4,
        "crop_start_seconds": 8,
        "crop_end_seconds": 4,
    },
)


def mass_grid():
    grid = [(mass1, mass2) for mass1 in MASS_VALUES for mass2 in range(10, mass1 + 1)]
    expected = len(MASS_VALUES) * (len(MASS_VALUES) + 1) // 2
    if len(grid) != expected or len(set(grid)) != expected:
        raise RuntimeError("Mass grid construction is incomplete or contains duplicates")
    return grid


def condition_strain(raw_strain, stage):
    filtered = highpass(raw_strain, HIGHPASS_FREQUENCY)
    resampled = resample_to_delta_t(filtered, 1.0 / stage["sample_rate"])
    conditioned = resampled.crop(2, 2)
    if int(round(float(conditioned.sample_rate))) != stage["sample_rate"]:
        raise RuntimeError(f"Unexpected sample rate in {stage['name']} stage")
    if float(conditioned.duration) <= (
        stage["crop_start_seconds"] + stage["crop_end_seconds"]
    ):
        raise RuntimeError(f"Conditioned data is too short for {stage['name']} cropping")

    psd = conditioned.psd(stage["psd_segment_seconds"])
    psd = interpolate(psd, conditioned.delta_f)
    psd = inverse_spectrum_truncation(
        psd,
        int(stage["psd_segment_seconds"] * conditioned.sample_rate),
        low_frequency_cutoff=HIGHPASS_FREQUENCY,
    )
    frequencies = psd.sample_frequencies.numpy()
    values = psd.numpy()
    usable = values[frequencies >= LOW_FREQUENCY_CUTOFF]
    if not np.isfinite(usable).all() or not (usable > 0).all():
        raise RuntimeError(f"Invalid PSD values in {stage['name']} stage")
    return conditioned, psd


def filter_template(approximant, mass1, mass2, conditioned, psd, stage):
    hp, _ = get_td_waveform(
        approximant=approximant,
        mass1=mass1,
        mass2=mass2,
        delta_t=conditioned.delta_t,
        f_lower=LOW_FREQUENCY_CUTOFF,
    )
    hp.resize(len(conditioned))
    template = hp.cyclic_time_shift(hp.start_time)
    snr_series = matched_filter(
        template,
        conditioned,
        psd=psd,
        low_frequency_cutoff=LOW_FREQUENCY_CUTOFF,
    )
    snr_series = snr_series.crop(
        stage["crop_start_seconds"], stage["crop_end_seconds"]
    )
    magnitudes = abs(snr_series).numpy()
    if magnitudes.size == 0 or not np.isfinite(magnitudes).all():
        raise RuntimeError("Matched filter returned no finite SNR samples")
    peak_index = int(np.argmax(magnitudes))
    return float(magnitudes[peak_index]), float(snr_series.sample_times[peak_index])


def scan_stage(raw_strain, stage, grid):
    started = time.monotonic()
    conditioned, psd = condition_strain(raw_strain, stage)
    records = []
    failures = []

    for approximant in APPROXIMANTS:
        approximant_records = []
        for index, (mass1, mass2) in enumerate(grid, start=1):
            try:
                peak_snr, peak_time = filter_template(
                    approximant, mass1, mass2, conditioned, psd, stage
                )
            except Exception as error:
                failures.append(
                    {
                        "stage": stage["name"],
                        "approximant": approximant,
                        "mass1": mass1,
                        "mass2": mass2,
                        "error": str(error),
                    }
                )
                continue

            record = {
                "stage": stage["name"],
                "sample_rate": stage["sample_rate"],
                "psd_segment_seconds": stage["psd_segment_seconds"],
                "approximant": approximant,
                "mass1": mass1,
                "mass2": mass2,
                "total_mass": mass1 + mass2,
                "snr": peak_snr,
                "peak_time": peak_time,
            }
            records.append(record)
            approximant_records.append(record)

            if index % 100 == 0:
                best = max(approximant_records, key=lambda item: item["snr"])
                print(
                    f"[{stage['name']} {approximant}] {index}/{len(grid)} "
                    f"best SNR={best['snr']:.3f} at ({best['mass1']}, {best['mass2']})"
                )

        if len(approximant_records) != len(grid):
            raise RuntimeError(
                f"{stage['name']} stage completed only {len(approximant_records)}/"
                f"{len(grid)} templates for {approximant}; failures={failures[-5:]}"
            )

    print(
        f"Completed {stage['name']} stage: {len(records)} templates in "
        f"{time.monotonic() - started:.1f}s"
    )
    return records


def best_by_approximant(records):
    frame = pd.DataFrame(records)
    best = {}
    for approximant in APPROXIMANTS:
        subset = frame[frame["approximant"] == approximant].sort_values(
            ["snr", "mass1", "mass2"], ascending=[False, True, True]
        )
        if subset.empty:
            raise RuntimeError(f"No successful templates for {approximant}")
        best[approximant] = subset.iloc[0].to_dict()
    return best


def audit_and_write(raw_strain, grid, all_records):
    diagnostics = pd.DataFrame(all_records)
    discovery = best_by_approximant(
        diagnostics[diagnostics["stage"] == "discovery"].to_dict("records")
    )
    confirmation_records = diagnostics[
        diagnostics["stage"] == "confirmation"
    ].to_dict("records")
    confirmation = best_by_approximant(confirmation_records)

    confirmation_stage = next(stage for stage in STAGES if stage["name"] == "confirmation")
    conditioned, psd = condition_strain(raw_strain, confirmation_stage)
    audit_rows = []
    output_rows = []
    for approximant in APPROXIMANTS:
        winner = confirmation[approximant]
        repeated_snr, repeated_time = filter_template(
            approximant,
            int(winner["mass1"]),
            int(winner["mass2"]),
            conditioned,
            psd,
            confirmation_stage,
        )
        if not np.isclose(repeated_snr, winner["snr"], rtol=0.0, atol=1e-9):
            raise RuntimeError(f"Non-reproducible winning SNR for {approximant}")
        if not np.isclose(repeated_time, winner["peak_time"], rtol=0.0, atol=1e-9):
            raise RuntimeError(f"Non-reproducible peak time for {approximant}")

        discovery_subset = diagnostics[
            (diagnostics["stage"] == "discovery")
            & (diagnostics["approximant"] == approximant)
        ].sort_values(["snr", "mass1", "mass2"], ascending=[False, True, True])
        winner_mask = (
            (discovery_subset["mass1"] == winner["mass1"])
            & (discovery_subset["mass2"] == winner["mass2"])
        )
        discovery_rank = int(np.flatnonzero(winner_mask.to_numpy())[0]) + 1
        audit_rows.append(
            {
                "approximant": approximant,
                "discovery_best_mass": discovery[approximant]["total_mass"],
                "confirmation_best_mass": winner["total_mass"],
                "confirmation_winner_discovery_rank": discovery_rank,
                "peak_time_difference": abs(
                    discovery[approximant]["peak_time"] - winner["peak_time"]
                ),
            }
        )
        output_rows.append(
            {
                "approximant": approximant,
                "snr": repeated_snr,
                "total_mass": float(winner["total_mass"]),
            }
        )

    diagnostics.to_csv(DIAGNOSTICS_PATH, index=False)
    pd.DataFrame(audit_rows).to_csv(
        "/root/detection_cross_resolution_audit.csv", index=False
    )
    pd.DataFrame(output_rows, columns=["approximant", "snr", "total_mass"]).to_csv(
        OUTPUT_PATH, index=False
    )


def main():
    if not os.path.isfile(FRAME_PATH):
        raise FileNotFoundError(FRAME_PATH)
    raw_strain = read_frame(FRAME_PATH, CHANNEL)
    if len(raw_strain) == 0 or not np.isfinite(raw_strain.numpy()).all():
        raise RuntimeError("Input strain is empty or contains non-finite samples")
    if float(raw_strain.duration) < 32:
        raise RuntimeError("Input strain is too short for robust PSD estimation")

    grid = mass_grid()
    all_records = []
    for stage in STAGES:
        all_records.extend(scan_stage(raw_strain, stage, grid))

    expected_records = len(STAGES) * len(APPROXIMANTS) * len(grid)
    if len(all_records) != expected_records:
        raise RuntimeError(
            f"Expected {expected_records} successful filters, got {len(all_records)}"
        )
    audit_and_write(raw_strain, grid, all_records)
    print(pd.read_csv(OUTPUT_PATH).to_string(index=False))


if __name__ == "__main__":
    main()
PY
