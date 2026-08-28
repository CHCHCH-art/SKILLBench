#!/bin/bash
set -euo pipefail

cd /app

apt-get update
apt-get install -y git build-essential

rm -rf /app/fastText
git clone --depth 1 https://github.com/facebookresearch/fastText.git /app/fastText
make -C /app/fastText -j"$(nproc)"

FT=/app/fastText/fasttext

AUTOTUNE_SECONDS=300

AUTOTUNE_MODEL_SIZE=149M

python3 <<'PY'
import hashlib
import pandas as pd

src = "/app/data/train-00000-of-00001.parquet"

df = pd.read_parquet(src, columns=["label", "text"])

paths = {
    "all": "/app/data/all.txt",
    "train": "/app/data/search_train.txt",
    "tune": "/app/data/tune_valid.txt",
    "select": "/app/data/selection_valid.txt",
}

files = {
    key: open(path, "w", encoding="utf-8")
    for key, path in paths.items()
}

counts = {
    "all": 0,
    "train": 0,
    "tune": 0,
    "select": 0,
}

try:
    for label, text in zip(df["label"], df["text"]):
        text = str(text)
        line = f"__label__{label} {text}\n"

        files["all"].write(line)
        counts["all"] += 1

        digest = hashlib.blake2b(
            (str(label) + "\0" + text).encode("utf-8"),
            digest_size=8,
        ).digest()

        bucket = int.from_bytes(digest, "big") % 1000

        if bucket < 10:
            files["tune"].write(line)
            counts["tune"] += 1
        elif bucket < 20:
            files["select"].write(line)
            counts["select"] += 1
        else:
            files["train"].write(line)
            counts["train"] += 1
finally:
    for f in files.values():
        f.close()

print("Dataset split:")
for key in ("all", "train", "tune", "select"):
    print(f"  {key}: {counts[key]}")

if counts["tune"] < 100 or counts["select"] < 100:
    raise RuntimeError("Validation partitions are unexpectedly small")
PY

mkdir -p /app/search

evaluate() {
    local model="$1"
    local data="$2"

    "$FT" test "$model" "$data" 1 2>&1 \
        | awk '$1 == "P@1" { print $2; exit }'
}

echo
echo "=========================================="
echo "Training baseline anchor"
echo "=========================================="

"$FT" supervised \
    -input /app/data/search_train.txt \
    -output /app/search/baseline \
    -wordNgrams 2 \
    -dim 5

BASE_SIZE=$(stat -c%s /app/search/baseline.bin)
BASE_SCORE=$(evaluate \
    /app/search/baseline.bin \
    /app/data/selection_valid.txt)

echo "Baseline selection score: $BASE_SCORE"
echo "Baseline size:            $BASE_SIZE bytes"

echo
echo "=========================================="
echo "Starting constrained fastText autotune"
echo "Budget: ${AUTOTUNE_SECONDS}s"
echo "Maximum artifact size: ${AUTOTUNE_MODEL_SIZE}"
echo "=========================================="

rm -f \
    /app/search/autotuned.bin \
    /app/search/autotuned.ftz

"$FT" supervised \
    -input /app/data/search_train.txt \
    -output /app/search/autotuned \
    -autotune-validation /app/data/tune_valid.txt \
    -autotune-duration "$AUTOTUNE_SECONDS" \
    -autotune-modelsize "$AUTOTUNE_MODEL_SIZE" \
    -autotune-predictions 1

if [ -f /app/search/autotuned.ftz ]; then
    AUTO_MODEL=/app/search/autotuned.ftz
elif [ -f /app/search/autotuned.bin ]; then
    AUTO_MODEL=/app/search/autotuned.bin
else
    echo "ERROR: autotune did not create a model" >&2
    exit 1
fi

AUTO_SIZE=$(stat -c%s "$AUTO_MODEL")

AUTO_SCORE=$(evaluate \
    "$AUTO_MODEL" \
    /app/data/selection_valid.txt)

echo
echo "=========================================="
echo "Independent model comparison"
echo "=========================================="
echo "baseline: score=$BASE_SCORE size=$BASE_SIZE"
echo "autotune: score=$AUTO_SCORE size=$AUTO_SIZE"

USE_AUTOTUNE=$(
    python3 - "$AUTO_SCORE" "$BASE_SCORE" <<'PY'
import sys

auto = float(sys.argv[1])
base = float(sys.argv[2])

print(1 if auto > base else 0)
PY
)

if [ "$USE_AUTOTUNE" = "1" ]; then
    echo
    echo "Selected: constrained autotune model"

    cp "$AUTO_MODEL" /app/model.bin
else
    echo
    echo "Selected: baseline representation after model search"
    echo "Retraining it on all available public training data..."

    rm -f /app/final.bin /app/final.vec

    "$FT" supervised \
        -input /app/data/all.txt \
        -output /app/final \
        -wordNgrams 2 \
        -dim 5

    mv /app/final.bin /app/model.bin
fi

MAX_BYTES=$((150 * 1024 * 1024))
FINAL_SIZE=$(stat -c%s /app/model.bin)

echo
echo "=========================================="
echo "Final model"
echo "=========================================="
echo "Size: $FINAL_SIZE bytes"
ls -lh /app/model.bin

if [ "$FINAL_SIZE" -ge "$MAX_BYTES" ]; then
    echo "ERROR: /app/model.bin exceeds 150 MiB" >&2
    exit 1
fi

"$FT" test /app/model.bin /app/data/selection_valid.txt 1

echo "Done."