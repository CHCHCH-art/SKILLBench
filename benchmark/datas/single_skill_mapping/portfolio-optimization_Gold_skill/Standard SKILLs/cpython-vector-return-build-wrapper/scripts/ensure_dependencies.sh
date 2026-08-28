#!/usr/bin/env bash
set -euo pipefail
mode="${1:---check}"

check_py() { python3 - "$1" <<'PY'
import importlib.util,sys
sys.exit(0 if importlib.util.find_spec(sys.argv[1]) else 1)
PY
}
check_ver() { python3 - "$1" "$2" <<'PY'
import importlib.metadata,sys
try: v=importlib.metadata.version(sys.argv[1])
except importlib.metadata.PackageNotFoundError: raise SystemExit(1)
raise SystemExit(0 if v==sys.argv[2] else 1)
PY
}

missing=0
check_py 'setuptools' || { echo "missing python module: setuptools"; missing=1; }
command -v cc >/dev/null 2>&1 || { echo "missing command: cc"; missing=1; }
if [[ "$mode" == "--check" ]]; then [[ "$missing" -eq 0 ]] && echo "dependency check passed"; exit "$missing"; fi
if [[ "$mode" != "--install" ]]; then echo "usage: $0 [--check|--install]" >&2; exit 2; fi
if command -v apt-get >/dev/null 2>&1; then apt-get update; apt-get install -y build-essential python3-dev; fi
python3 -m pip install --no-cache-dir 'setuptools'
$0 --check
