#!/usr/bin/env bash
set -euo pipefail
mode="${1:---check}"
check() {
  command -v ffmpeg >/dev/null 2>&1 || return 1
  command -v ffprobe >/dev/null 2>&1 || return 1
  python3 - <<'PY'
import importlib.util
for name in ("numpy", "scipy"):
    if importlib.util.find_spec(name) is None:
        raise SystemExit(1)
PY
}
case "$mode" in
  --check) check && echo "dependency check passed" ;;
  --install)
    command -v ffmpeg >/dev/null 2>&1 && command -v ffprobe >/dev/null 2>&1 || {
      if command -v apt-get >/dev/null 2>&1; then
        apt-get update && apt-get install -y ffmpeg
      else
        echo "ffmpeg/ffprobe missing and no supported system package manager found" >&2; exit 1
      fi
    }
    python3 -m pip install numpy scipy
    check && echo "dependencies installed"
    ;;
  *) echo "usage: $0 [--check|--install]" >&2; exit 2 ;;
esac
