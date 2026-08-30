#!/usr/bin/env bash
set -euo pipefail
MODE="${1:---check}"
[[ "$MODE" == "--check" || "$MODE" == "--install" ]] || { echo "usage: $0 [--check|--install]" >&2; exit 2; }
command -v python3 >/dev/null 2>&1 || { echo "missing command: python3" >&2; exit 1; }
if command -v libreoffice >/dev/null 2>&1 || command -v soffice >/dev/null 2>&1; then
  echo "dependency check passed (LibreOffice available)"
else
  echo "dependency check passed (LibreOffice unavailable; independent-cache fallback required)"
fi
