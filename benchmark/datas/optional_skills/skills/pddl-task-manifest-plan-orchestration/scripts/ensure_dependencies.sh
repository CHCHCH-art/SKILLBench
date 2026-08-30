#!/usr/bin/env bash
set -euo pipefail

missing=()
python3 - <<'PY' || missing+=("unified-planning")
import unified_planning
PY
python3 - <<'PY' || missing+=("up-pyperplan")
import up_pyperplan
PY

if [ ${#missing[@]} -eq 0 ]; then
  python3 - <<'PY'
from unified_planning.shortcuts import OneshotPlanner
with OneshotPlanner(name="pyperplan") as planner:
    assert planner is not None
print("dependency check passed: unified_planning with pyperplan engine")
PY
  exit 0
fi

if [ "${1:-}" = "--install" ]; then
  python3 -m pip install "${missing[@]}"
  python3 - <<'PY'
from unified_planning.shortcuts import OneshotPlanner
with OneshotPlanner(name="pyperplan") as planner:
    assert planner is not None
print("dependency installation/check passed")
PY
else
  printf 'missing dependencies: %s\n' "${missing[*]}" >&2
  printf 'rerun with --install to install them\n' >&2
  exit 1
fi
