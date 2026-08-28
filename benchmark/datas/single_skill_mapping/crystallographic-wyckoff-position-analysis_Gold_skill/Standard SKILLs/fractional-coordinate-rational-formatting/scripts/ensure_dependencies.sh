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
check_py 'sympy' || { echo "missing python module: sympy"; missing=1; }
if [[ "$mode" == "--check" ]]; then [[ "$missing" -eq 0 ]] && echo "dependency check passed"; exit "$missing"; fi
if [[ "$mode" != "--install" ]]; then echo "usage: $0 [--check|--install]" >&2; exit 2; fi
python3 -m pip install --no-cache-dir 'sympy'
$0 --check
