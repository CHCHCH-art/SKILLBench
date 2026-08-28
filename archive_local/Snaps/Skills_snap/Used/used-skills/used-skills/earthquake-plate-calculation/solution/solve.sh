#!/bin/bash
set -euo pipefail

EARTHQUAKES_FILE="/root/earthquakes_2024.json"
PLATES_FILE="/root/PB2002_plates.json"
BOUNDARIES_FILE="/root/PB2002_boundaries.json"
OUTPUT_FILE="/root/answer.json"

WORK_DIR="/root/pacific_distance_field_work"
VECTOR_GPKG="${WORK_DIR}/projected_inputs.gpkg"
BOUNDARY_GEOMETRIES_JSON="${WORK_DIR}/boundary_geometries_4087.json"
PROJECTED_POINTS_CSV="${WORK_DIR}/projected_earthquake_points.csv"
RASTER_METADATA_JSON="${WORK_DIR}/raster_metadata.json"
BOUNDARY_MASK_TIF="${WORK_DIR}/pacific_boundary_mask.tif"
DISTANCE_FIELD_TIF="${WORK_DIR}/pacific_boundary_distance_field.tif"
RASTER_SAMPLES_CSV="${WORK_DIR}/earthquake_raster_samples.csv"

CELL_SIZE_M="5000"

rm -rf "${WORK_DIR}"
mkdir -p "${WORK_DIR}"
rm -f "${OUTPUT_FILE}"

cleanup() {
    rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

if python3 -c 'import numpy, rasterio, scipy' >/dev/null 2>&1; then
    RASTER_PYTHON="$(command -v python3)"
else
    export DEBIAN_FRONTEND=noninteractive
    apt-get update
    apt-get install -y --no-install-recommends \
        python3-numpy \
        python3-rasterio \
        python3-scipy
    rm -rf /var/lib/apt/lists/*
    RASTER_PYTHON="/usr/bin/python3"
fi

printf '%s\n' "Preparing Pacific-plate vector inputs in EPSG:4087..."

EARTHQUAKES_FILE="${EARTHQUAKES_FILE}" \
PLATES_FILE="${PLATES_FILE}" \
BOUNDARIES_FILE="${BOUNDARIES_FILE}" \
VECTOR_GPKG="${VECTOR_GPKG}" \
BOUNDARY_GEOMETRIES_JSON="${BOUNDARY_GEOMETRIES_JSON}" \
PROJECTED_POINTS_CSV="${PROJECTED_POINTS_CSV}" \
RASTER_METADATA_JSON="${RASTER_METADATA_JSON}" \
CELL_SIZE_M="${CELL_SIZE_M}" \
python3 <<'PY'
import csv
import json
import math
import os
from pathlib import Path

import geopandas as gpd
import pandas as pd
from shapely.geometry import Point, mapping

SOURCE_CRS = "EPSG:4326"
METRIC_CRS = "EPSG:4087"

EARTHQUAKES_FILE = os.environ["EARTHQUAKES_FILE"]
PLATES_FILE = os.environ["PLATES_FILE"]
BOUNDARIES_FILE = os.environ["BOUNDARIES_FILE"]
VECTOR_GPKG = Path(os.environ["VECTOR_GPKG"])
BOUNDARY_GEOMETRIES_JSON = Path(os.environ["BOUNDARY_GEOMETRIES_JSON"])
PROJECTED_POINTS_CSV = Path(os.environ["PROJECTED_POINTS_CSV"])
RASTER_METADATA_JSON = Path(os.environ["RASTER_METADATA_JSON"])
CELL_SIZE_M = float(os.environ["CELL_SIZE_M"])


def ensure_crs(gdf: gpd.GeoDataFrame) -> gpd.GeoDataFrame:
    if gdf.crs is None:
        return gdf.set_crs(SOURCE_CRS, allow_override=True)
    return gdf


def union_geometries(series):
    if hasattr(series, "union_all"):
        return series.union_all()
    return series.unary_union


def optional_string(value):
    if value is None or pd.isna(value):
        return None
    return str(value)


def optional_float(value):
    if value is None or pd.isna(value):
        return None
    number = float(value)
    if not math.isfinite(number):
        return None
    return number


def load_earthquakes() -> gpd.GeoDataFrame:
    with open(EARTHQUAKES_FILE, "r", encoding="utf-8") as handle:
        payload = json.load(handle)

    rows = []
    for source_ordinal, feature in enumerate(payload.get("features", [])):
        properties = feature.get("properties") or {}
        geometry = feature.get("geometry") or {}
        coordinates = geometry.get("coordinates") or []

        if len(coordinates) < 2:
            continue

        try:
            longitude = float(coordinates[0])
            latitude = float(coordinates[1])
        except (TypeError, ValueError):
            continue

        if not math.isfinite(longitude) or not math.isfinite(latitude):
            continue

        rows.append(
            {
                "source_ordinal": int(source_ordinal),
                "earthquake_id": optional_string(feature.get("id")),
                "place": optional_string(properties.get("place")),
                "time_ms": optional_float(properties.get("time")),
                "magnitude": optional_float(properties.get("mag")),
                "longitude": longitude,
                "latitude": latitude,
                "geometry": Point(longitude, latitude),
            }
        )

    if not rows:
        raise RuntimeError("No valid earthquake point features were found")

    return gpd.GeoDataFrame(rows, geometry="geometry", crs=SOURCE_CRS)


earthquakes = load_earthquakes()
plates = ensure_crs(gpd.read_file(PLATES_FILE))
boundaries = ensure_crs(gpd.read_file(BOUNDARIES_FILE))

if "PlateName" not in plates.columns:
    raise RuntimeError(
        f"PlateName field not found; fields={list(plates.columns)}"
    )

if "Name" not in boundaries.columns:
    raise RuntimeError(
        f"Name field not found; fields={list(boundaries.columns)}"
    )

plates_for_filtering = (
    plates.to_crs(earthquakes.crs)
    if plates.crs != earthquakes.crs
    else plates
)

pacific_plate_rows = plates_for_filtering.loc[
    plates_for_filtering["PlateName"].astype("string") == "Pacific"
].copy()

if pacific_plate_rows.empty:
    raise RuntimeError("Pacific plate polygon was not found")

pacific_polygon = union_geometries(pacific_plate_rows.geometry)
pacific_quakes = earthquakes.loc[
    earthquakes.within(pacific_polygon)
].copy()

if pacific_quakes.empty:
    raise RuntimeError("No earthquakes were found within the Pacific plate")

pacific_boundaries = boundaries.loc[
    boundaries["Name"]
    .astype("string")
    .str.contains("PA", regex=False, na=False)
].copy()

pacific_boundaries = pacific_boundaries.loc[
    pacific_boundaries.geometry.notna()
    & ~pacific_boundaries.geometry.is_empty
].copy()

if pacific_boundaries.empty:
    raise RuntimeError(
        "No usable Pacific boundary features matched Name containing 'PA'"
    )

projected_quakes = pacific_quakes.to_crs(METRIC_CRS).copy()
projected_quakes = projected_quakes.sort_values(
    "source_ordinal", kind="mergesort"
).reset_index(drop=True)

projected_boundaries = pacific_boundaries.to_crs(METRIC_CRS).copy()
projected_boundaries = projected_boundaries.reset_index(drop=True)
projected_boundaries["boundary_source_pos"] = projected_boundaries.index
projected_boundaries["boundary_name"] = projected_boundaries["Name"].astype(
    "string"
)
projected_boundaries = projected_boundaries[
    ["boundary_source_pos", "boundary_name", "geometry"]
]

VECTOR_GPKG.unlink(missing_ok=True)
projected_quakes.to_file(
    VECTOR_GPKG,
    layer="pacific_quakes",
    driver="GPKG",
    index=False,
)
projected_boundaries.to_file(
    VECTOR_GPKG,
    layer="pacific_boundary",
    driver="GPKG",
    index=False,
)

with BOUNDARY_GEOMETRIES_JSON.open("w", encoding="utf-8") as handle:
    json.dump(
        [mapping(geometry) for geometry in projected_boundaries.geometry],
        handle,
        separators=(",", ":"),
    )
    handle.write("\n")

with PROJECTED_POINTS_CSV.open("w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle)
    writer.writerow(["source_ordinal", "x", "y"])
    for row in projected_quakes.itertuples(index=False):
        writer.writerow(
            [
                int(row.source_ordinal),
                format(float(row.geometry.x), ".12f"),
                format(float(row.geometry.y), ".12f"),
            ]
        )

quake_minx, quake_miny, quake_maxx, quake_maxy = (
    projected_quakes.total_bounds
)
boundary_minx, boundary_miny, boundary_maxx, boundary_maxy = (
    projected_boundaries.total_bounds
)

raw_minx = min(quake_minx, boundary_minx)
raw_miny = min(quake_miny, boundary_miny)
raw_maxx = max(quake_maxx, boundary_maxx)
raw_maxy = max(quake_maxy, boundary_maxy)

padding = 2.0 * CELL_SIZE_M
xmin = math.floor((raw_minx - padding) / CELL_SIZE_M) * CELL_SIZE_M
ymin = math.floor((raw_miny - padding) / CELL_SIZE_M) * CELL_SIZE_M
xmax = math.ceil((raw_maxx + padding) / CELL_SIZE_M) * CELL_SIZE_M
ymax = math.ceil((raw_maxy + padding) / CELL_SIZE_M) * CELL_SIZE_M

width = int(round((xmax - xmin) / CELL_SIZE_M))
height = int(round((ymax - ymin) / CELL_SIZE_M))
cell_count = width * height

if width <= 0 or height <= 0:
    raise RuntimeError("Calculated raster dimensions are invalid")

if cell_count > 100_000_000:
    raise RuntimeError(
        "Projected raster would exceed 100 million cells: "
        f"{width} x {height}"
    )

metadata = {
    "source_crs": SOURCE_CRS,
    "metric_crs": METRIC_CRS,
    "cell_size_m": CELL_SIZE_M,
    "xmin": xmin,
    "ymin": ymin,
    "xmax": xmax,
    "ymax": ymax,
    "width": width,
    "height": height,
    "cell_count": cell_count,
    "earthquake_count": int(len(projected_quakes)),
    "boundary_feature_count": int(len(projected_boundaries)),
}

with RASTER_METADATA_JSON.open("w", encoding="utf-8") as handle:
    json.dump(metadata, handle, indent=2)
    handle.write("\n")

print(
    "Selected "
    f"{len(projected_quakes)} earthquakes and "
    f"{len(projected_boundaries)} Pacific boundary features"
)
print(
    "Distance-field grid: "
    f"{width} x {height} = {cell_count} cells at "
    f"{CELL_SIZE_M / 1000.0:.2f} km"
)
PY

printf '%s\n' "Rasterizing boundary vectors and computing the distance field..."

BOUNDARY_GEOMETRIES_JSON="${BOUNDARY_GEOMETRIES_JSON}" \
RASTER_METADATA_JSON="${RASTER_METADATA_JSON}" \
BOUNDARY_MASK_TIF="${BOUNDARY_MASK_TIF}" \
DISTANCE_FIELD_TIF="${DISTANCE_FIELD_TIF}" \
"${RASTER_PYTHON}" <<'PY'
import json
import os

import numpy as np
import rasterio
from rasterio.features import rasterize
from rasterio.transform import from_origin
from scipy.ndimage import distance_transform_edt

BOUNDARY_GEOMETRIES_JSON = os.environ["BOUNDARY_GEOMETRIES_JSON"]
RASTER_METADATA_JSON = os.environ["RASTER_METADATA_JSON"]
BOUNDARY_MASK_TIF = os.environ["BOUNDARY_MASK_TIF"]
DISTANCE_FIELD_TIF = os.environ["DISTANCE_FIELD_TIF"]

with open(BOUNDARY_GEOMETRIES_JSON, "r", encoding="utf-8") as handle:
    boundary_geometries = json.load(handle)

with open(RASTER_METADATA_JSON, "r", encoding="utf-8") as handle:
    metadata = json.load(handle)

if not boundary_geometries:
    raise RuntimeError("No projected boundary geometries were serialized")

width = int(metadata["width"])
height = int(metadata["height"])
cell_size_m = float(metadata["cell_size_m"])
transform = from_origin(
    float(metadata["xmin"]),
    float(metadata["ymax"]),
    cell_size_m,
    cell_size_m,
)

boundary_mask = rasterize(
    ((geometry, 1) for geometry in boundary_geometries),
    out_shape=(height, width),
    transform=transform,
    fill=0,
    all_touched=True,
    dtype="uint8",
)

burned_cell_count = int(np.count_nonzero(boundary_mask))
if burned_cell_count == 0:
    raise RuntimeError("Boundary rasterization produced no target cells")

mask_profile = {
    "driver": "GTiff",
    "height": height,
    "width": width,
    "count": 1,
    "dtype": "uint8",
    "crs": metadata["metric_crs"],
    "transform": transform,
    "compress": "LZW",
    "tiled": True,
    "blockxsize": 512,
    "blockysize": 512,
    "BIGTIFF": "IF_SAFER",
}

with rasterio.open(BOUNDARY_MASK_TIF, "w", **mask_profile) as dataset:
    dataset.write(boundary_mask, 1)

background = boundary_mask == 0

distance_field = distance_transform_edt(
    background,
    sampling=(cell_size_m, cell_size_m),
)

if not np.isfinite(distance_field).all():
    raise RuntimeError("Distance transform produced a non-finite value")

distance_field_float32 = distance_field.astype("float32")

distance_profile = dict(mask_profile)
distance_profile["dtype"] = "float32"
distance_profile["predictor"] = 3

with rasterio.open(DISTANCE_FIELD_TIF, "w", **distance_profile) as dataset:
    dataset.write(distance_field_float32, 1)

print(
    "Rasterized "
    f"{burned_cell_count} boundary cells and wrote a "
    f"{height} x {width} distance field"
)
PY

printf '%s\n' "Sampling the persisted distance field for all earthquakes..."

PROJECTED_POINTS_CSV="${PROJECTED_POINTS_CSV}" \
DISTANCE_FIELD_TIF="${DISTANCE_FIELD_TIF}" \
RASTER_SAMPLES_CSV="${RASTER_SAMPLES_CSV}" \
"${RASTER_PYTHON}" <<'PY'
import csv
import math
import os

import numpy as np
import rasterio

PROJECTED_POINTS_CSV = os.environ["PROJECTED_POINTS_CSV"]
DISTANCE_FIELD_TIF = os.environ["DISTANCE_FIELD_TIF"]
RASTER_SAMPLES_CSV = os.environ["RASTER_SAMPLES_CSV"]

points = []
with open(PROJECTED_POINTS_CSV, "r", encoding="utf-8", newline="") as handle:
    reader = csv.DictReader(handle)
    for row in reader:
        points.append(
            (
                int(row["source_ordinal"]),
                float(row["x"]),
                float(row["y"]),
            )
        )

if not points:
    raise RuntimeError("No projected earthquake points were serialized")

with rasterio.open(DISTANCE_FIELD_TIF, "r") as dataset:
    distance_field = dataset.read(1)
    inverse_transform = ~dataset.transform

    sampled_rows = []
    for source_ordinal, x, y in points:
        column_float, row_float = inverse_transform * (x, y)
        column = int(math.floor(column_float))
        row = int(math.floor(row_float))

        if not (0 <= column < dataset.width):
            raise RuntimeError(
                f"Earthquake column is outside raster: {column}"
            )
        if not (0 <= row < dataset.height):
            raise RuntimeError(f"Earthquake row is outside raster: {row}")

        distance_m = float(distance_field[row, column])
        if not math.isfinite(distance_m) or distance_m < 0.0:
            raise RuntimeError(
                f"Invalid sampled raster distance: {distance_m}"
            )

        sampled_rows.append((source_ordinal, distance_m))

with open(RASTER_SAMPLES_CSV, "w", encoding="utf-8", newline="") as handle:
    writer = csv.writer(handle)
    writer.writerow(["source_ordinal", "raster_distance_m"])
    for source_ordinal, distance_m in sampled_rows:
        writer.writerow([source_ordinal, format(distance_m, ".9f")])

print(f"Sampled {len(sampled_rows)} earthquake locations")
PY

printf '%s\n' "Applying conservative branch-and-bound and exact vector refinement..."

VECTOR_GPKG="${VECTOR_GPKG}" \
RASTER_METADATA_JSON="${RASTER_METADATA_JSON}" \
RASTER_SAMPLES_CSV="${RASTER_SAMPLES_CSV}" \
OUTPUT_FILE="${OUTPUT_FILE}" \
python3 <<'PY'
import json
import math
import os
from datetime import datetime, timezone
from pathlib import Path

import geopandas as gpd
import pandas as pd

VECTOR_GPKG = os.environ["VECTOR_GPKG"]
RASTER_METADATA_JSON = os.environ["RASTER_METADATA_JSON"]
RASTER_SAMPLES_CSV = os.environ["RASTER_SAMPLES_CSV"]
OUTPUT_FILE = Path(os.environ["OUTPUT_FILE"])


def union_geometries(series):
    if hasattr(series, "union_all"):
        return series.union_all()
    return series.unary_union


def optional_string(value):
    if value is None or pd.isna(value):
        return None
    return str(value)


def optional_float(value):
    if value is None or pd.isna(value):
        return None
    number = float(value)
    if not math.isfinite(number):
        return None
    return number


def timestamp_to_iso8601(value) -> str:
    if value is None or pd.isna(value):
        raise RuntimeError("Winning earthquake has no timestamp")

    return datetime.fromtimestamp(
        float(value) / 1000.0,
        tz=timezone.utc,
    ).strftime("%Y-%m-%dT%H:%M:%SZ")


with open(RASTER_METADATA_JSON, "r", encoding="utf-8") as handle:
    metadata = json.load(handle)

cell_size_m = float(metadata["cell_size_m"])

raster_error_bound_m = math.sqrt(2.0) * cell_size_m

quakes = gpd.read_file(VECTOR_GPKG, layer="pacific_quakes")
boundaries = gpd.read_file(VECTOR_GPKG, layer="pacific_boundary")
samples = pd.read_csv(RASTER_SAMPLES_CSV)

if quakes.crs is None or boundaries.crs is None:
    raise RuntimeError("Projected GeoPackage layers are missing CRS metadata")

if quakes.crs != boundaries.crs:
    raise RuntimeError("Projected earthquake and boundary CRS values differ")

samples["source_ordinal"] = samples["source_ordinal"].astype("int64")
quakes["source_ordinal"] = quakes["source_ordinal"].astype("int64")

quakes = quakes.merge(
    samples,
    on="source_ordinal",
    how="left",
    validate="one_to_one",
)

if quakes["raster_distance_m"].isna().any():
    raise RuntimeError("One or more earthquakes have no raster sample")

boundary_union = union_geometries(boundaries.geometry)
if boundary_union is None or boundary_union.is_empty:
    raise RuntimeError("Pacific boundary union is empty")

float32_rounding_margin_m = (
    quakes["raster_distance_m"].abs().astype("float64") * (2.0 ** -22)
    + 1.0
)

quakes["upper_bound_m"] = (
    quakes["raster_distance_m"].astype("float64")
    + raster_error_bound_m
    + float32_rounding_margin_m
)

anchor = quakes.sort_values(
    ["raster_distance_m", "source_ordinal"],
    ascending=[False, True],
    kind="mergesort",
).iloc[0]

anchor_distance_m = float(anchor.geometry.distance(boundary_union))
if not math.isfinite(anchor_distance_m):
    raise RuntimeError("Anchor exact distance is non-finite")

candidate_mask = quakes["upper_bound_m"] >= (anchor_distance_m - 1e-7)
candidates = quakes.loc[candidate_mask].copy()

if candidates.empty:
    raise RuntimeError("Conservative screening produced no candidates")

candidates["exact_distance_m"] = candidates.geometry.distance(boundary_union)

if not candidates["exact_distance_m"].map(math.isfinite).all():
    raise RuntimeError("A non-finite exact candidate distance was produced")

winner = candidates.sort_values(
    ["exact_distance_m", "source_ordinal"],
    ascending=[False, True],
    kind="mergesort",
).iloc[0]

winner_distance_m = float(winner["exact_distance_m"])

eliminated = quakes.loc[~candidate_mask]
if not eliminated.empty:
    largest_eliminated_upper_bound = float(eliminated["upper_bound_m"].max())
    if largest_eliminated_upper_bound > winner_distance_m + 1e-6:
        raise RuntimeError(
            "Candidate proof failed: an eliminated upper bound exceeds "
            "the exact winning distance"
        )

source_feature_distances = boundaries.geometry.distance(winner.geometry)
verification_distance_m = float(source_feature_distances.min())

if not math.isclose(
    winner_distance_m,
    verification_distance_m,
    rel_tol=0.0,
    abs_tol=1e-6,
):
    raise RuntimeError(
        "Winner verification failed: "
        f"union={winner_distance_m} m, "
        f"source_features={verification_distance_m} m"
    )

result = {
    "id": optional_string(winner["earthquake_id"]),
    "place": optional_string(winner["place"]),
    "time": timestamp_to_iso8601(winner["time_ms"]),
    "magnitude": optional_float(winner["magnitude"]),
    "latitude": float(winner["latitude"]),
    "longitude": float(winner["longitude"]),
    "distance_km": round(winner_distance_m / 1000.0, 2),
}

with OUTPUT_FILE.open("w", encoding="utf-8") as handle:
    json.dump(
        result,
        handle,
        ensure_ascii=False,
        indent=2,
        allow_nan=False,
    )
    handle.write("\n")

print(
    "Conservative refinement: "
    f"{len(candidates)} candidates from {len(quakes)} earthquakes"
)
print(json.dumps(result, ensure_ascii=False, indent=2))
print(f"Result written to {OUTPUT_FILE}")
PY
