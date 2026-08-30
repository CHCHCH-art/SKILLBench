#!/usr/bin/env bash
set -euo pipefail

if python3 - <<'PY'
import unified_planning
print("dependency check passed: unified_planning")
PY
then
  exit 0
fi

if [ "${1:-}" = "--install" ]; then
  python3 -m pip install unified-planning
  python3 - <<'PY'
import unified_planning
print("dependency installation/check passed")
PY
else
  echo "missing dependency: unified-planning" >&2
  echo "rerun with --install to install it" >&2
  exit 1
fi
