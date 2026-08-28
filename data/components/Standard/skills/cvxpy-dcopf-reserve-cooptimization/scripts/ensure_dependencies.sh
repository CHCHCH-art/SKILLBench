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
check_ver 'numpy' '1.26.4' || { echo "missing/wrong version: numpy==1.26.4"; missing=1; }
check_ver 'scipy' '1.11.4' || { echo "missing/wrong version: scipy==1.11.4"; missing=1; }
check_ver 'cvxpy' '1.4.2' || { echo "missing/wrong version: cvxpy==1.4.2"; missing=1; }
if [[ "$mode" == "--check" ]]; then [[ "$missing" -eq 0 ]] && echo "dependency check passed"; exit "$missing"; fi
if [[ "$mode" != "--install" ]]; then echo "usage: $0 [--check|--install]" >&2; exit 2; fi
python3 -m pip install --no-cache-dir 'numpy==1.26.4' 'scipy==1.11.4' 'cvxpy==1.4.2'
$0 --check
