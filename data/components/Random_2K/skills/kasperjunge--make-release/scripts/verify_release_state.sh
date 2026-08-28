#!/usr/bin/env bash
set -euo pipefail

if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  echo "Not inside a git repository." >&2
  exit 1
fi

branch=$(git branch --show-current)
if [[ "$branch" != "main" ]]; then
  echo "Must be on 'main' branch to release. Current: $branch" >&2
  exit 1
fi

status=$(git status --porcelain)
if [[ -n "$status" ]]; then
  echo "Working tree is not clean. Commit or stash changes first." >&2
  echo >&2
  git status --short >&2
  exit 1
fi
