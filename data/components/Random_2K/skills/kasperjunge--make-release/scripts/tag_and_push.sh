#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: tag_and_push.sh X.Y.Z" >&2
  exit 1
fi

version="$1"
if ! [[ "$version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "Version must be SemVer: X.Y.Z" >&2
  exit 1
fi

tag="v$version"

if git rev-parse -q --verify "refs/tags/$tag" >/dev/null; then
  echo "Tag $tag already exists locally." >&2
  exit 1
fi

if git ls-remote --tags origin "$tag" | grep -q "$tag"; then
  echo "Tag $tag already exists on remote." >&2
  exit 1
fi

git tag "$tag"
git push origin main
git push origin "$tag"
