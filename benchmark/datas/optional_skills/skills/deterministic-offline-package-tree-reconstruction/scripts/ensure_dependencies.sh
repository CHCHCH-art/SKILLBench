#!/usr/bin/env bash
set -euo pipefail
MODE="${1:---check}"
if [[ "$MODE" != "--check" && "$MODE" != "--install" ]]; then
  echo "usage: $0 [--check|--install]" >&2
  exit 2
fi
COMMANDS=(python3 xz)
ANY_COMMANDS=()
APT_PACKAGES=(xz-utils)
PY_MODULES=()
PIP_PACKAGES=()

missing_cmd=0
for c in "${COMMANDS[@]}"; do
  if ! command -v "$c" >/dev/null 2>&1; then
    echo "missing command: $c" >&2
    missing_cmd=1
  fi
done
if (( ${#ANY_COMMANDS[@]} > 0 )); then
  found_any=0
  for c in "${ANY_COMMANDS[@]}"; do
    if command -v "$c" >/dev/null 2>&1; then found_any=1; break; fi
  done
  if (( ! found_any )); then
    echo "missing command: need one of ${ANY_COMMANDS[*]}" >&2
    missing_cmd=1
  fi
fi
missing_py=0
if (( ${#PY_MODULES[@]} > 0 )); then
  if ! python3 - "${PY_MODULES[@]}" <<'PYCHECK'; then
import importlib.util, sys
missing=[m for m in sys.argv[1:] if importlib.util.find_spec(m) is None]
if missing:
    print("missing Python modules: " + ", ".join(missing), file=sys.stderr)
    raise SystemExit(1)
PYCHECK
    missing_py=1
  fi
fi
if [[ "$MODE" == "--install" && ( "$missing_cmd" == "1" || "$missing_py" == "1" ) ]]; then
  if (( ${#APT_PACKAGES[@]} > 0 )) && command -v apt-get >/dev/null 2>&1; then
    if [[ "$(id -u)" == "0" ]]; then SUDO=""; elif command -v sudo >/dev/null 2>&1; then SUDO=sudo; else SUDO=""; fi
    if [[ "$(id -u)" == "0" || -n "$SUDO" ]]; then
      $SUDO apt-get update
      $SUDO apt-get install -y "${APT_PACKAGES[@]}" || true
    fi
  fi
  if (( ${#PIP_PACKAGES[@]} > 0 )); then
    python3 -m pip install "${PIP_PACKAGES[@]}"
  fi
fi
# Final strict check.
for c in "${COMMANDS[@]}"; do command -v "$c" >/dev/null 2>&1 || { echo "still missing command: $c" >&2; exit 1; }; done
if (( ${#ANY_COMMANDS[@]} > 0 )); then
  found_any=0; for c in "${ANY_COMMANDS[@]}"; do command -v "$c" >/dev/null 2>&1 && found_any=1 && break; done
  (( found_any )) || { echo "still missing all alternative commands: ${ANY_COMMANDS[*]}" >&2; exit 1; }
fi
if (( ${#PY_MODULES[@]} > 0 )); then
python3 - "${PY_MODULES[@]}" <<'PYCHECK'
import importlib.util, sys
missing=[m for m in sys.argv[1:] if importlib.util.find_spec(m) is None]
if missing:
    print("still missing Python modules: " + ", ".join(missing), file=sys.stderr)
    raise SystemExit(1)
PYCHECK
fi
echo "dependency check passed"
