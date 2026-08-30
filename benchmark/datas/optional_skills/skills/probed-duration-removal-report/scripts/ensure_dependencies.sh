#!/usr/bin/env bash
set -euo pipefail
mode="${1:---check}"
check(){ command -v ffprobe >/dev/null 2>&1; }
case "$mode" in
 --check) check && echo "dependency check passed" ;;
 --install)
   check || { command -v apt-get >/dev/null 2>&1 || { echo "ffprobe missing" >&2; exit 1; }; apt-get update && apt-get install -y ffmpeg; }
   check && echo "dependencies installed" ;;
 *) echo "usage: $0 [--check|--install]" >&2; exit 2 ;;
esac
