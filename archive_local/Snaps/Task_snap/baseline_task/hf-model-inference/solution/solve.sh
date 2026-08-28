#!/usr/bin/env bash
set -euo pipefail

cd /app

MODEL_NAME="distilbert-base-uncased-finetuned-sst-2-english"
MODEL_DIR="/app/model_cache/sentiment_model"
RUNTIME_DIR="/app/model_cache/numpy_int8_runtime"
APP_FILE="/app/app.py"
PID_FILE="/app/sentiment.pid"
LOG_FILE="/app/app.log"

mkdir -p "$MODEL_DIR" "$RUNTIME_DIR"

python3 - <<'PY'
import importlib.util
import subprocess
import sys

required = {
    "flask": "flask",
    "numpy": "numpy",
    "huggingface_hub": "huggingface_hub",
    "tokenizers": "tokenizers",
    "safetensors": "safetensors",
    "transformers": "transformers",
    "torch": "torch",
}
missing = [pkg for module, pkg in required.items() if importlib.util.find_spec(module) is None]
if missing:
    subprocess.check_call([sys.executable, "-m", "pip", "install", "--no-cache-dir", *missing])
PY

python3 - <<'PY'
from pathlib import Path
from huggingface_hub import snapshot_download

model_dir = Path("/app/model_cache/sentiment_model")
needed = [
    "config.json",
    "model.safetensors",
    "tokenizer_config.json",
    "special_tokens_map.json",
    "vocab.txt",
]

required_remote = [
    model_dir / "config.json",
    model_dir / "model.safetensors",
    model_dir / "vocab.txt",
]

if not all(p.exists() for p in required_remote):
    snapshot_download(
        repo_id="distilbert-base-uncased-finetuned-sst-2-english",
        local_dir=str(model_dir),
        allow_patterns=needed,
    )

if not (model_dir / "tokenizer.json").exists():
    from transformers import AutoTokenizer
    tokenizer = AutoTokenizer.from_pretrained(
        str(model_dir),
        use_fast=True,
        local_files_only=True,
    )
    tokenizer.save_pretrained(str(model_dir))

if not (model_dir / "tokenizer.json").exists():
    raise RuntimeError("failed to materialize tokenizer.json")
PY

python3 - <<'PY'
from pathlib import Path
import json
import re
import shutil

import numpy as np
from safetensors import safe_open

src = Path("/app/model_cache/sentiment_model/model.safetensors")
out = Path("/app/model_cache/numpy_int8_runtime")
manifest_path = out / "manifest.json"

source_sig = f"{src.stat().st_size}:{src.stat().st_mtime_ns}"
old_sig = None
if manifest_path.exists():
    try:
        old_sig = json.loads(manifest_path.read_text())["source_signature"]
    except Exception:
        pass

if old_sig != source_sig:
    for child in out.iterdir():
        if child.is_file():
            child.unlink()
        elif child.is_dir():
            shutil.rmtree(child)

    def safe_name(name: str) -> str:
        return re.sub(r"[^A-Za-z0-9_.-]", "_", name)

    tensors = {}
    with safe_open(str(src), framework="numpy") as f:
        for name in f.keys():
            arr = np.asarray(f.get_tensor(name))
            stem = safe_name(name)

            if arr.ndim == 2:
                x = arr.astype(np.float32, copy=False)
                scale = np.max(np.abs(x), axis=1).astype(np.float32) / 127.0
                scale[scale == 0.0] = 1.0
                q = np.rint(x / scale[:, None]).clip(-127, 127).astype(np.int8)
                q_file = f"{stem}.q.npy"
                s_file = f"{stem}.scale.npy"
                np.save(out / q_file, q, allow_pickle=False)
                np.save(out / s_file, scale, allow_pickle=False)
                tensors[name] = {"kind": "q2", "q": q_file, "scale": s_file}
            else:
                f_file = f"{stem}.f32.npy"
                np.save(out / f_file, arr.astype(np.float32), allow_pickle=False)
                tensors[name] = {"kind": "f32", "file": f_file}

    manifest_path.write_text(json.dumps({
        "source_signature": source_sig,
        "tensors": tensors,
    }, sort_keys=True))
PY

cat > "$APP_FILE" <<'PY'
from __future__ import annotations

import json
import math
import os
from pathlib import Path

os.environ.setdefault("OPENBLAS_NUM_THREADS", "1")
os.environ.setdefault("OMP_NUM_THREADS", "1")
os.environ.setdefault("MKL_NUM_THREADS", "1")
os.environ.setdefault("NUMEXPR_NUM_THREADS", "1")

import numpy as np
from flask import Flask, jsonify, request
from tokenizers import Tokenizer

MODEL_DIR = Path("/app/model_cache/sentiment_model")
RUNTIME_DIR = Path("/app/model_cache/numpy_int8_runtime")

app = Flask(__name__)

config = json.loads((MODEL_DIR / "config.json").read_text())
DIM = int(config["dim"])
N_HEADS = int(config["n_heads"])
N_LAYERS = int(config["n_layers"])
HEAD_DIM = DIM // N_HEADS
EPS = 1e-12
INV_SQRT_HEAD = 1.0 / math.sqrt(HEAD_DIM)

tokenizer = Tokenizer.from_file(str(MODEL_DIR / "tokenizer.json"))
tokenizer.enable_truncation(max_length=512)

manifest = json.loads((RUNTIME_DIR / "manifest.json").read_text())
entries = manifest["tensors"]


class WeightStore:
    """Memory-map compressed parameters and decode only what an op needs."""

    def __init__(self):
        self._q = {}
        self._s = {}
        self._v = {}

        for name, meta in entries.items():
            if meta["kind"] == "q2":
                self._q[name] = np.load(RUNTIME_DIR / meta["q"], mmap_mode="r")
                self._s[name] = np.load(RUNTIME_DIR / meta["scale"], mmap_mode="r")
            else:
                self._v[name] = np.load(RUNTIME_DIR / meta["file"], mmap_mode="r")

    def vector(self, name: str) -> np.ndarray:
        return np.asarray(self._v[name], dtype=np.float32)

    def matrix(self, name: str) -> np.ndarray:
        q = self._q[name]
        s = self._s[name]
        return q.astype(np.float32) * np.asarray(s, dtype=np.float32)[:, None]

    def embedding(self, name: str, ids: np.ndarray) -> np.ndarray:
        q = self._q[name][ids]
        s = self._s[name][ids]
        return q.astype(np.float32) * np.asarray(s, dtype=np.float32)[..., None]


W = WeightStore()


def linear(x: np.ndarray, prefix: str) -> np.ndarray:
    weight = W.matrix(prefix + ".weight")
    bias = W.vector(prefix + ".bias")
    return np.matmul(x, weight.T) + bias


def layer_norm(x: np.ndarray, prefix: str) -> np.ndarray:
    mean = x.mean(axis=-1, keepdims=True, dtype=np.float32)
    centered = x - mean
    var = np.mean(centered * centered, axis=-1, keepdims=True, dtype=np.float32)
    norm = centered / np.sqrt(var + EPS)
    return norm * W.vector(prefix + ".weight") + W.vector(prefix + ".bias")


def gelu(x: np.ndarray) -> np.ndarray:
    return 0.5 * x * (
        1.0
        + np.tanh(
            np.float32(math.sqrt(2.0 / math.pi))
            * (x + np.float32(0.044715) * x * x * x)
        )
    )


def softmax(x: np.ndarray, axis: int = -1) -> np.ndarray:
    z = x - np.max(x, axis=axis, keepdims=True)
    e = np.exp(z)
    return e / np.sum(e, axis=axis, keepdims=True)


def self_attention(x: np.ndarray, layer: int) -> np.ndarray:
    prefix = f"distilbert.transformer.layer.{layer}.attention"
    seq = x.shape[0]

    q = linear(x, prefix + ".q_lin").reshape(seq, N_HEADS, HEAD_DIM).transpose(1, 0, 2)
    k = linear(x, prefix + ".k_lin").reshape(seq, N_HEADS, HEAD_DIM).transpose(1, 0, 2)
    v = linear(x, prefix + ".v_lin").reshape(seq, N_HEADS, HEAD_DIM).transpose(1, 0, 2)

    scores = np.matmul(q, np.swapaxes(k, 1, 2)) * np.float32(INV_SQRT_HEAD)
    probs = softmax(scores, axis=-1)
    context = np.matmul(probs, v).transpose(1, 0, 2).reshape(seq, DIM)
    return linear(context, prefix + ".out_lin")


def transformer_layer(x: np.ndarray, layer: int) -> np.ndarray:
    base = f"distilbert.transformer.layer.{layer}"

    attended = self_attention(x, layer)
    x = layer_norm(attended + x, base + ".sa_layer_norm")

    ff = linear(x, base + ".ffn.lin1")
    ff = gelu(ff)
    ff = linear(ff, base + ".ffn.lin2")
    return layer_norm(ff + x, base + ".output_layer_norm")


def logits_for_text(text: str) -> np.ndarray:
    encoded = tokenizer.encode(text, add_special_tokens=True)
    ids = np.asarray(encoded.ids, dtype=np.int64)
    seq = ids.shape[0]

    word = W.embedding("distilbert.embeddings.word_embeddings.weight", ids)
    positions = np.arange(seq, dtype=np.int64)
    pos = W.embedding("distilbert.embeddings.position_embeddings.weight", positions)

    x = layer_norm(word + pos, "distilbert.embeddings.LayerNorm")

    for layer in range(N_LAYERS):
        x = transformer_layer(x, layer)

    pooled = linear(x[0], "pre_classifier")
    pooled = np.maximum(pooled, 0.0)
    return linear(pooled, "classifier").astype(np.float64)


def classify(text: str) -> dict:
    logits = logits_for_text(text)
    probs = softmax(logits, axis=-1)
    negative = float(probs[0])
    positive = float(probs[1])
    return {
        "sentiment": "positive" if positive > negative else "negative",
        "confidence": {
            "positive": positive,
            "negative": negative,
        },
    }


@app.route("/sentiment", methods=["POST"])
def sentiment():
    data = request.get_json(silent=True)
    if not isinstance(data, dict) or "text" not in data or not isinstance(data["text"], str):
        return jsonify({"error": 'Please provide text in the format {"text": "your text here"}'}), 400

    try:
        return jsonify(classify(data["text"]))
    except Exception as exc:
        app.logger.exception("sentiment inference failed")
        return jsonify({"error": f"Inference failed: {exc}"}), 400


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5000, threaded=True)
PY

if [[ -f "$PID_FILE" ]]; then
    old_pid="$(cat "$PID_FILE" 2>/dev/null || true)"
    if [[ -n "$old_pid" ]] && kill -0 "$old_pid" 2>/dev/null; then
        kill "$old_pid" 2>/dev/null || true
        for _ in $(seq 1 50); do
            if ! kill -0 "$old_pid" 2>/dev/null; then
                break
            fi
            sleep 0.1
        done
    fi
fi

nohup python3 "$APP_FILE" >"$LOG_FILE" 2>&1 &
server_pid=$!
echo "$server_pid" > "$PID_FILE"

server_ready=0
for _ in $(seq 1 240); do
    if ! kill -0 "$server_pid" 2>/dev/null; then
        echo "sentiment service exited before binding port 5000" >&2
        echo "----- /app/app.log -----" >&2
        cat "$LOG_FILE" >&2 || true
        exit 1
    fi

    if python3 - <<'PY'
import socket
with socket.socket() as s:
    s.settimeout(0.2)
    try:
        s.connect(("127.0.0.1", 5000))
    except OSError:
        raise SystemExit(1)
PY
    then
        server_ready=1
        break
    fi
    sleep 0.25
done

if [[ "$server_ready" -ne 1 ]]; then
    echo "sentiment service did not bind port 5000" >&2
    echo "----- /app/app.log -----" >&2
    cat "$LOG_FILE" >&2 || true
    exit 1
fi

python3 - <<'PY'
import json
import urllib.request

samples = [
    "A short local inference startup check.",
    "The application is running and can process this ordinary sentence.",
    "This request verifies the complete tokenizer and model execution path.",
]

for text in samples:
    req = urllib.request.Request(
        "http://127.0.0.1:5000/sentiment",
        data=json.dumps({"text": text}).encode(),
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=120) as resp:
        if resp.status != 200:
            raise SystemExit(f"startup inference returned HTTP {resp.status}")
        payload = json.loads(resp.read())
        if payload.get("sentiment") not in {"positive", "negative"}:
            raise SystemExit("startup inference returned invalid sentiment")
        conf = payload.get("confidence", {})
        if not isinstance(conf.get("positive"), float) or not isinstance(conf.get("negative"), float):
            raise SystemExit("startup inference returned invalid confidence values")
PY
