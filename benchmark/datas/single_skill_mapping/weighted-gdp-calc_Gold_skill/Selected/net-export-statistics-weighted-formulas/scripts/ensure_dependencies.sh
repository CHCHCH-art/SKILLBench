#!/usr/bin/env bash
set -euo pipefail
MODE="${1:---check}"
[[ "$MODE" == "--check" || "$MODE" == "--install" ]] || { echo "usage: $0 [--check|--install]" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "missing command: python3" >&2; exit 1; }
echo "dependency check passed"
