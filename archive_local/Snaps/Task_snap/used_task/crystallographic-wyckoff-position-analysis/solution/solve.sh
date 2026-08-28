#!/bin/bash

set -euo pipefail

PYTHON_BIN="$(command -v python3)"
MKDIR_BIN="$(command -v mkdir)"
CAT_BIN="$(command -v cat)"
CHMOD_BIN="$(command -v chmod)"
RM_BIN="$(command -v rm)"

"${MKDIR_BIN}" -p /root/workspace

missing_packages=()

if ! "${PYTHON_BIN}" -c 'import numpy' >/dev/null 2>&1; then
  missing_packages+=(python3-numpy)
fi

if ! "${PYTHON_BIN}" -c 'import spglib' >/dev/null 2>&1; then
  missing_packages+=(python3-spglib)
fi

if ! "${PYTHON_BIN}" -c 'import gemmi' >/dev/null 2>&1 \
   && ! "${PYTHON_BIN}" -c 'import pymatgen' >/dev/null 2>&1; then
  missing_packages+=(python3-gemmi)
fi

if (( ${#missing_packages[@]} > 0 )); then
  APT_GET_BIN="$(command -v apt-get || true)"
  if [[ -z "${APT_GET_BIN}" ]]; then
    echo "Missing Python dependencies and apt-get is unavailable: ${missing_packages[*]}" >&2
    exit 1
  fi

  export DEBIAN_FRONTEND=noninteractive
  "${APT_GET_BIN}" update
  "${APT_GET_BIN}" install -y --no-install-recommends "${missing_packages[@]}"
  "${RM_BIN}" -rf /var/lib/apt/lists/*
fi

"${PYTHON_BIN}" - <<'PY_DEPENDENCIES'
import importlib.util

required = ["numpy", "spglib"]
missing = [name for name in required if importlib.util.find_spec(name) is None]
if importlib.util.find_spec("gemmi") is None and importlib.util.find_spec("pymatgen") is None:
    missing.append("gemmi or pymatgen")
if missing:
    raise SystemExit("Missing required Python modules: " + ", ".join(missing))
PY_DEPENDENCIES

"${CAT_BIN}" > /root/workspace/wyckoff_worker.py <<'PY_WORKER'
#!/usr/bin/env python3
"""Subprocess worker for tolerance-stability spglib analysis."""

from __future__ import annotations

import argparse
import json
import math
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

import numpy as np
import spglib


def _dataset_value(dataset: Any, name: str) -> Any:
    """Support both attribute-style and legacy mapping-style datasets."""
    if hasattr(dataset, name):
        return getattr(dataset, name)
    return dataset[name]


def _normalized_orbits(
    wyckoffs: list[str],
    equivalent_atoms: list[int],
    numbers: np.ndarray,
) -> tuple[tuple[str, int, int], ...]:
    """Create an atom-order-independent description of Wyckoff orbits."""
    orbit_members: dict[int, list[int]] = defaultdict(list)
    for atom_index, representative in enumerate(equivalent_atoms):
        orbit_members[int(representative)].append(atom_index)

    orbits: list[tuple[str, int, int]] = []
    for members in orbit_members.values():
        first = members[0]
        letter = str(wyckoffs[first])
        atom_type = int(numbers[first])
        orbits.append((letter, len(members), atom_type))
    return tuple(sorted(orbits))


def _candidate_from_dataset(
    dataset: Any,
    symprec: float,
    numbers: np.ndarray,
) -> dict[str, Any]:
    wyckoffs = [str(value) for value in _dataset_value(dataset, "wyckoffs")]
    equivalent_atoms = [
        int(value) for value in _dataset_value(dataset, "equivalent_atoms")
    ]
    return {
        "symprec": float(symprec),
        "number": int(_dataset_value(dataset, "number")),
        "hall_number": int(_dataset_value(dataset, "hall_number")),
        "international": str(_dataset_value(dataset, "international")),
        "wyckoffs": wyckoffs,
        "equivalent_atoms": equivalent_atoms,
        "orbit_signature": [
            list(item)
            for item in _normalized_orbits(wyckoffs, equivalent_atoms, numbers)
        ],
    }


def _signature(candidate: dict[str, Any]) -> tuple[Any, ...]:
    return (
        int(candidate["number"]),
        tuple(tuple(item) for item in candidate["orbit_signature"]),
    )


def _select_candidate(
    candidates: list[dict[str, Any]],
    declared_spacegroup_number: int | None,
) -> dict[str, Any] | None:
    """Select the result most stable across nearby conventional tolerances."""
    if not candidates:
        return None

    frequencies = Counter(_signature(item) for item in candidates)
    highest_frequency = max(frequencies.values())
    stable_signatures = {
        signature
        for signature, count in frequencies.items()
        if count == highest_frequency
    }
    stable_pool = [
        item for item in candidates if _signature(item) in stable_signatures
    ]

    stable_pool.sort(
        key=lambda item: (
            0
            if declared_spacegroup_number is not None
            and int(item["number"]) == declared_spacegroup_number
            else 1,
            abs(math.log10(float(item["symprec"])) - math.log10(1e-3)),
            float(item["symprec"]),
        )
    )
    return stable_pool[0]


def run(npz_path: Path, metadata_path: Path, output_path: Path) -> None:
    with np.load(npz_path, allow_pickle=False) as arrays:
        lattice = np.asarray(arrays["lattice"], dtype=float)
        positions = np.asarray(arrays["positions"], dtype=float)
        numbers = np.asarray(arrays["numbers"], dtype=np.intc)

    if lattice.shape != (3, 3):
        raise ValueError(f"Expected lattice shape (3, 3), got {lattice.shape}")
    if positions.ndim != 2 or positions.shape[1] != 3:
        raise ValueError(f"Expected positions shape (N, 3), got {positions.shape}")
    if numbers.ndim != 1 or len(numbers) != len(positions):
        raise ValueError("numbers must contain one entry per atomic position")
    if len(numbers) == 0:
        raise ValueError("The normalized structure contains no atoms")
    if not np.isfinite(lattice).all() or not np.isfinite(positions).all():
        raise ValueError("The spglib input contains non-finite values")

    metadata = json.loads(metadata_path.read_text(encoding="utf-8"))
    declared = metadata.get("declared_spacegroup_number")
    declared_number = int(declared) if declared not in (None, "") else None

    cell = (lattice, positions, numbers)
    candidates: list[dict[str, Any]] = []
    errors: list[dict[str, Any]] = []

    for symprec in (1e-5, 1e-4, 1e-3, 1e-2):
        try:
            dataset = spglib.get_symmetry_dataset(
                cell,
                symprec=symprec,
                angle_tolerance=-1.0,
            )
            if dataset is None:
                errors.append({"symprec": symprec, "error": "no dataset"})
                continue
            candidates.append(_candidate_from_dataset(dataset, symprec, numbers))
        except Exception as exc:  # defensive process boundary
            errors.append({"symprec": symprec, "error": repr(exc)})

    selected = _select_candidate(candidates, declared_number)
    payload = {
        "selected": selected,
        "candidates": candidates,
        "errors": errors,
    }
    output_path.write_text(
        json.dumps(payload, indent=2, sort_keys=True),
        encoding="utf-8",
    )


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--npz", required=True)
    parser.add_argument("--metadata", required=True)
    parser.add_argument("--output", required=True)
    args = parser.parse_args()

    run(
        Path(args.npz).resolve(),
        Path(args.metadata).resolve(),
        Path(args.output).resolve(),
    )


if __name__ == "__main__":
    main()
PY_WORKER

"${CAT_BIN}" > /root/workspace/solution.py <<'PY_SOLUTION'
#!/usr/bin/env python3
"""
Alternative CIF Wyckoff analysis pipeline.

Processing route:
1. Parse and symmetry-expand the source CIF with Gemmi, or use the existing
   pymatgen parser as a compatibility fallback.
2. Deduplicate equivalent expanded sites with a periodic spatial index.
3. Serialize the expanded structure to an explicit P1 CIF representation.
4. Parse that controlled representation into NumPy arrays and metadata.
5. Run spglib in a separate worker at several symmetry tolerances.
6. Select the tolerance-stable result and rationalize representative
   coordinates with fractions.Fraction.

The public function name, input type, and return structure match the original
solution.
"""

from __future__ import annotations

import importlib.util
import json
import math
import os
import re
import shlex
import shutil
import subprocess
import sys
import tempfile
from collections import Counter, defaultdict
from dataclasses import dataclass
from fractions import Fraction
from pathlib import Path
from typing import Any, Iterable

import numpy as np


_WORKER_PATH = Path("/root/workspace/wyckoff_worker.py")
_EMPTY_RESULT = {
    "wyckoff_multiplicity_dict": {},
    "wyckoff_coordinates_dict": {},
}


@dataclass(frozen=True)
class _CellParameters:
    a: float
    b: float
    c: float
    alpha: float
    beta: float
    gamma: float


@dataclass
class _ExpandedSite:
    label: str
    type_label: str
    type_symbol: str
    occupancy: float
    frac: np.ndarray
    type_id: int = 0


def _wrapped_fractional(values: Iterable[float]) -> np.ndarray:
    frac = np.asarray(list(values), dtype=float) % 1.0
    frac[np.isclose(frac, 1.0, atol=1e-12)] = 0.0
    frac[np.isclose(frac, 0.0, atol=1e-12)] = 0.0
    return frac


def _lattice_from_cell(cell: _CellParameters) -> np.ndarray:
    alpha = math.radians(cell.alpha)
    beta = math.radians(cell.beta)
    gamma = math.radians(cell.gamma)
    sin_gamma = math.sin(gamma)
    if abs(sin_gamma) < 1e-12:
        raise ValueError("Invalid unit cell: gamma produces a singular lattice")

    a_vec = np.array([cell.a, 0.0, 0.0], dtype=float)
    b_vec = np.array(
        [cell.b * math.cos(gamma), cell.b * sin_gamma, 0.0],
        dtype=float,
    )
    c_x = cell.c * math.cos(beta)
    c_y = cell.c * (
        math.cos(alpha) - math.cos(beta) * math.cos(gamma)
    ) / sin_gamma
    c_z_sq = cell.c * cell.c - c_x * c_x - c_y * c_y
    if c_z_sq < -1e-8:
        raise ValueError("Invalid unit cell: computed negative squared c_z")
    c_vec = np.array([c_x, c_y, math.sqrt(max(0.0, c_z_sq))], dtype=float)
    lattice = np.vstack([a_vec, b_vec, c_vec])
    if abs(float(np.linalg.det(lattice))) < 1e-10:
        raise ValueError("Invalid unit cell: lattice volume is zero")
    return lattice


def _periodic_distance(
    frac_a: np.ndarray,
    frac_b: np.ndarray,
    lattice: np.ndarray,
) -> float:
    delta = frac_a - frac_b
    delta -= np.rint(delta)
    return float(np.linalg.norm(delta @ lattice))


def _deduplicate_sites(
    sites: list[_ExpandedSite],
    lattice: np.ndarray,
    distance_tolerance_angstrom: float = 1e-3,
) -> list[_ExpandedSite]:
    """Deduplicate periodic sites using local spatial buckets."""
    if not sites:
        return []

    singular_values = np.linalg.svd(lattice, compute_uv=False)
    minimum_scale = float(np.min(singular_values))
    if minimum_scale <= 0.0:
        raise ValueError("Cannot deduplicate sites in a singular lattice")

    fractional_tolerance = min(
        0.25,
        max(1e-8, distance_tolerance_angstrom / minimum_scale),
    )
    bins_per_axis = max(4, int(math.floor(1.0 / fractional_tolerance)))

    buckets: dict[tuple[str, int, int, int], list[int]] = defaultdict(list)
    retained: list[_ExpandedSite] = []

    for site in sites:
        if not math.isfinite(site.occupancy) or site.occupancy <= 0.0:
            continue
        frac = _wrapped_fractional(site.frac)
        site.frac = frac
        type_key = f"{site.type_label}|{site.occupancy:.6f}"
        base = tuple(
            int(math.floor(float(value) * bins_per_axis)) % bins_per_axis
            for value in frac
        )

        duplicate = False
        for dx in (-1, 0, 1):
            for dy in (-1, 0, 1):
                for dz in (-1, 0, 1):
                    key = (
                        type_key,
                        (base[0] + dx) % bins_per_axis,
                        (base[1] + dy) % bins_per_axis,
                        (base[2] + dz) % bins_per_axis,
                    )
                    for retained_index in buckets.get(key, []):
                        if _periodic_distance(
                            frac,
                            retained[retained_index].frac,
                            lattice,
                        ) <= distance_tolerance_angstrom:
                            duplicate = True
                            break
                    if duplicate:
                        break
                if duplicate:
                    break
            if duplicate:
                break

        if duplicate:
            continue

        retained_index = len(retained)
        retained.append(site)
        own_key = (type_key, base[0], base[1], base[2])
        buckets[own_key].append(retained_index)

    return retained


def _declared_spacegroup_number(cif_path: Path) -> int | None:
    text = cif_path.read_text(encoding="utf-8", errors="replace")
    pattern = re.compile(
        r"(?im)^\s*_(?:space_group_IT_number|symmetry_Int_Tables_number)"
        r"\s+['\"]?([0-9]{1,3})"
    )
    match = pattern.search(text)
    if not match:
        return None
    number = int(match.group(1))
    return number if 1 <= number <= 230 else None


def _parse_with_gemmi(
    cif_path: Path,
) -> tuple[_CellParameters, np.ndarray, list[_ExpandedSite], int | None]:
    import gemmi

    structure = gemmi.read_small_structure(str(cif_path))
    if len(structure.sites) == 0:
        raise ValueError(f"No atom sites could be parsed from {cif_path}")

    cell = _CellParameters(
        float(structure.cell.a),
        float(structure.cell.b),
        float(structure.cell.c),
        float(structure.cell.alpha),
        float(structure.cell.beta),
        float(structure.cell.gamma),
    )
    lattice = np.asarray(structure.cell.orth.mat.tolist(), dtype=float).T

    expanded = list(structure.get_all_unit_cell_sites())
    if not expanded:
        expanded = list(structure.sites)

    sites: list[_ExpandedSite] = []
    for index, site in enumerate(expanded):
        occupancy = float(site.occ)
        symbol = str(site.type_symbol or site.element.name or "X").strip() or "X"
        label = str(site.label or f"site_{index + 1}")
        sites.append(
            _ExpandedSite(
                label=label,
                type_label=f"{symbol}:{occupancy:.6f}",
                type_symbol=symbol,
                occupancy=occupancy,
                frac=_wrapped_fractional(
                    [site.fract.x, site.fract.y, site.fract.z]
                ),
            )
        )

    declared: int | None = None
    try:
        candidate = int(structure.spacegroup_number)
        if 1 <= candidate <= 230:
            declared = candidate
    except Exception:
        declared = None
    if declared is None:
        declared = _declared_spacegroup_number(cif_path)

    return cell, lattice, sites, declared


def _parse_with_pymatgen(
    cif_path: Path,
) -> tuple[_CellParameters, np.ndarray, list[_ExpandedSite], int | None]:
    from pymatgen.core import Structure

    structure = Structure.from_file(str(cif_path))
    if len(structure) == 0:
        raise ValueError(f"No atom sites could be parsed from {cif_path}")

    lattice = np.asarray(structure.lattice.matrix, dtype=float)
    cell = _CellParameters(
        float(structure.lattice.a),
        float(structure.lattice.b),
        float(structure.lattice.c),
        float(structure.lattice.alpha),
        float(structure.lattice.beta),
        float(structure.lattice.gamma),
    )

    sites: list[_ExpandedSite] = []
    for index, site in enumerate(structure):
        species_items = sorted(
            (
                str(specie),
                float(occupancy),
                str(getattr(specie, "symbol", str(specie))),
            )
            for specie, occupancy in site.species.items()
        )
        type_label = ";".join(
            f"{name}:{occupancy:.6f}"
            for name, occupancy, _symbol in species_items
        )
        representative_symbol = max(
            species_items,
            key=lambda item: item[1],
        )[2]
        total_occupancy = sum(item[1] for item in species_items)
        label = str(site.label or f"site_{index + 1}")
        sites.append(
            _ExpandedSite(
                label=label,
                type_label=type_label,
                type_symbol=representative_symbol,
                occupancy=total_occupancy,
                frac=_wrapped_fractional(site.frac_coords),
            )
        )

    return (
        cell,
        lattice,
        sites,
        _declared_spacegroup_number(cif_path),
    )


def _parse_source_cif(
    cif_path: Path,
) -> tuple[_CellParameters, np.ndarray, list[_ExpandedSite], int | None]:
    if importlib.util.find_spec("gemmi") is not None:
        return _parse_with_gemmi(cif_path)
    if importlib.util.find_spec("pymatgen") is not None:
        return _parse_with_pymatgen(cif_path)
    raise RuntimeError("Neither Gemmi nor pymatgen is available for CIF parsing")


def _safe_token(value: str) -> str:
    token = re.sub(r"[^A-Za-z0-9_.+-]", "_", value)
    return token or "X"


def _assign_type_ids(sites: list[_ExpandedSite]) -> None:
    type_ids: dict[tuple[str, float], int] = {}
    for site in sites:
        key = (site.type_label, round(site.occupancy, 6))
        if key not in type_ids:
            type_ids[key] = len(type_ids) + 1
        site.type_id = type_ids[key]


def _write_explicit_p1_cif(
    path: Path,
    cell: _CellParameters,
    sites: list[_ExpandedSite],
) -> None:
    lines = [
        "data_explicit_p1",
        f"_cell_length_a {cell.a:.12g}",
        f"_cell_length_b {cell.b:.12g}",
        f"_cell_length_c {cell.c:.12g}",
        f"_cell_angle_alpha {cell.alpha:.12g}",
        f"_cell_angle_beta {cell.beta:.12g}",
        f"_cell_angle_gamma {cell.gamma:.12g}",
        "_space_group_name_H-M_alt 'P 1'",
        "_space_group_IT_number 1",
        "loop_",
        "_space_group_symop_operation_xyz",
        "'x,y,z'",
        "loop_",
        "_atom_site_label",
        "_atom_site_type_symbol",
        "_atom_site_pipeline_type",
        "_atom_site_occupancy",
        "_atom_site_fract_x",
        "_atom_site_fract_y",
        "_atom_site_fract_z",
    ]

    symbol_counts: Counter[str] = Counter()
    for site in sites:
        symbol = _safe_token(site.type_symbol)
        symbol_counts[symbol] += 1
        label = f"{symbol}{symbol_counts[symbol]}"
        x, y, z = site.frac
        lines.append(
            f"{label} {symbol} {site.type_id:d} {site.occupancy:.8g} "
            f"{x:.16g} {y:.16g} {z:.16g}"
        )

    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def _read_controlled_p1_cif(
    path: Path,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, list[np.ndarray]]:
    """Read the exact P1 subset emitted by _write_explicit_p1_cif."""
    raw_lines = path.read_text(encoding="utf-8").splitlines()
    scalar_values: dict[str, str] = {}
    atom_rows: list[list[str]] = []

    index = 0
    while index < len(raw_lines):
        stripped = raw_lines[index].strip()
        if not stripped or stripped.startswith("#"):
            index += 1
            continue
        if stripped.startswith("_cell_"):
            tokens = shlex.split(stripped)
            if len(tokens) >= 2:
                scalar_values[tokens[0]] = tokens[1]
            index += 1
            continue
        if stripped != "loop_":
            index += 1
            continue

        index += 1
        headers: list[str] = []
        while index < len(raw_lines):
            candidate = raw_lines[index].strip()
            if candidate.startswith("_"):
                headers.append(candidate)
                index += 1
            else:
                break

        if "_atom_site_pipeline_type" not in headers:
            while index < len(raw_lines):
                candidate = raw_lines[index].strip()
                if not candidate or candidate == "loop_" or candidate.startswith("_"):
                    break
                index += 1
            continue

        while index < len(raw_lines):
            candidate = raw_lines[index].strip()
            if not candidate or candidate == "loop_" or candidate.startswith("_"):
                break
            values = shlex.split(candidate)
            if len(values) != len(headers):
                raise ValueError(
                    "Malformed controlled P1 atom row: " + candidate
                )
            atom_rows.append(values)
            index += 1

    required_scalars = {
        "_cell_length_a",
        "_cell_length_b",
        "_cell_length_c",
        "_cell_angle_alpha",
        "_cell_angle_beta",
        "_cell_angle_gamma",
    }
    missing = sorted(required_scalars - scalar_values.keys())
    if missing:
        raise ValueError("Controlled P1 CIF is missing: " + ", ".join(missing))
    if not atom_rows:
        raise ValueError("Controlled P1 CIF contains no atom rows")

    cell = _CellParameters(
        a=float(scalar_values["_cell_length_a"]),
        b=float(scalar_values["_cell_length_b"]),
        c=float(scalar_values["_cell_length_c"]),
        alpha=float(scalar_values["_cell_angle_alpha"]),
        beta=float(scalar_values["_cell_angle_beta"]),
        gamma=float(scalar_values["_cell_angle_gamma"]),
    )
    lattice = _lattice_from_cell(cell)

    numbers: list[int] = []
    positions: list[list[float]] = []
    coordinate_rows: list[np.ndarray] = []
    for values in atom_rows:
        type_id = int(values[2])
        frac = _wrapped_fractional(
            [float(values[4]), float(values[5]), float(values[6])]
        )
        numbers.append(type_id)
        positions.append(frac.tolist())
        coordinate_rows.append(frac)

    return (
        lattice,
        np.asarray(positions, dtype=float),
        np.asarray(numbers, dtype=np.intc),
        coordinate_rows,
    )


def _closest_simple_fraction(value: float, max_denominator: int = 12) -> str:
    wrapped = float(value) % 1.0
    if math.isclose(wrapped, 0.0, abs_tol=1e-10) or math.isclose(
        wrapped, 1.0, abs_tol=1e-10
    ):
        wrapped = 0.0
    return str(Fraction(wrapped).limit_denominator(max_denominator))


def analyze_wyckoff_position_multiplicities_and_coordinates(
    filepath: str,
) -> dict[str, dict[str, Any]]:
    """Analyze Wyckoff multiplicities and representative coordinates."""
    input_path = Path(filepath).expanduser().resolve(strict=True)
    if not input_path.is_file():
        raise ValueError(f"Not a regular file: {input_path}")
    if not _WORKER_PATH.is_file():
        raise FileNotFoundError(f"Missing worker script: {_WORKER_PATH}")

    temp_root = Path(tempfile.mkdtemp(prefix="wyckoff_pipeline_", dir="/tmp"))
    normalized_cif = temp_root / "10_explicit_p1.cif"
    arrays_npz = temp_root / "20_spglib_input.npz"
    metadata_json = temp_root / "21_metadata.json"
    worker_json = temp_root / "30_symmetry_results.json"

    try:
        cell, source_lattice, expanded_sites, declared_number = _parse_source_cif(
            input_path
        )
        unique_sites = _deduplicate_sites(expanded_sites, source_lattice)
        if not unique_sites:
            raise ValueError("No usable occupied atomic sites were found in the CIF")

        _assign_type_ids(unique_sites)
        _write_explicit_p1_cif(normalized_cif, cell, unique_sites)
        lattice, positions, numbers, coordinate_rows = _read_controlled_p1_cif(
            normalized_cif
        )

        np.savez_compressed(
            arrays_npz,
            lattice=lattice,
            positions=positions,
            numbers=numbers,
        )
        metadata_json.write_text(
            json.dumps(
                {
                    "declared_spacegroup_number": declared_number,
                    "atom_count": int(len(numbers)),
                    "type_count": int(len(set(int(value) for value in numbers))),
                    "normalized_cif": str(normalized_cif),
                },
                indent=2,
                sort_keys=True,
            ),
            encoding="utf-8",
        )

        completed = subprocess.run(
            [
                sys.executable,
                str(_WORKER_PATH),
                "--npz",
                str(arrays_npz),
                "--metadata",
                str(metadata_json),
                "--output",
                str(worker_json),
            ],
            cwd="/root/workspace",
            check=False,
            capture_output=True,
            text=True,
            timeout=180,
            env={**os.environ, "PYTHONUNBUFFERED": "1"},
        )
        if completed.returncode != 0:
            raise RuntimeError(
                "Symmetry worker failed with exit code "
                f"{completed.returncode}: {completed.stderr.strip()}"
            )

        payload = json.loads(worker_json.read_text(encoding="utf-8"))
        selected = payload.get("selected")
        if selected is None:
            return {
                "wyckoff_multiplicity_dict": {},
                "wyckoff_coordinates_dict": {},
            }

        wyckoffs = [str(value) for value in selected["wyckoffs"]]
        if len(wyckoffs) != len(coordinate_rows):
            raise RuntimeError(
                "spglib returned a Wyckoff list whose length does not match "
                "the normalized atom table"
            )

        multiplicities = dict(sorted(Counter(wyckoffs).items()))
        coordinates: dict[str, list[str]] = {}
        for row_index, letter in enumerate(wyckoffs):
            if letter in coordinates:
                continue
            frac = coordinate_rows[row_index]
            coordinates[letter] = [
                _closest_simple_fraction(float(frac[0])),
                _closest_simple_fraction(float(frac[1])),
                _closest_simple_fraction(float(frac[2])),
            ]

        return {
            "wyckoff_multiplicity_dict": multiplicities,
            "wyckoff_coordinates_dict": dict(sorted(coordinates.items())),
        }
    finally:
        shutil.rmtree(temp_root, ignore_errors=True)
PY_SOLUTION

"${CHMOD_BIN}" 0755 /root/workspace/solution.py
"${CHMOD_BIN}" 0755 /root/workspace/wyckoff_worker.py

"${PYTHON_BIN}" -m py_compile \
  /root/workspace/solution.py \
  /root/workspace/wyckoff_worker.py

echo "Solution written to /root/workspace/solution.py"