#!/usr/bin/env bash
set -euo pipefail
MODE="${1:---check}"
[[ "$MODE" == "--check" || "$MODE" == "--install" ]] || { echo "usage: $0 [--check|--install]" >&2; exit 2; }
if ! command -v python3 >/dev/null 2>&1; then
  if [[ "$MODE" == "--install" ]] && command -v apt-get >/dev/null 2>&1; then
    apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y python3
  else
    echo "missing command: python3" >&2; exit 1
  fi
fi
python3 - <<'PY'
import importlib.util
mods=['xml.etree.ElementTree','zipfile','json']
for m in mods:
    if importlib.util.find_spec(m) is None:
        raise SystemExit(f'missing Python module: {m}')
print('dependency check passed')
PY
