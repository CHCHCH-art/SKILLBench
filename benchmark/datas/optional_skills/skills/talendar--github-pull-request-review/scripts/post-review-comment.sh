#!/usr/bin/env bash
set -euo pipefail

# post-review-comment.sh — Posts a structured review comment on a GitHub PR.
# Usage: post-review-comment.sh <PR_NUMBER> <VERDICT> <BODY_FILE> [OWNER/REPO]
#
# VERDICT: approve | request-changes | comment
# BODY_FILE: Path to a file containing the review body text.

usage() {
  echo "Usage: $0 <PR_NUMBER> <VERDICT> <BODY_FILE> [OWNER/REPO]"
  echo ""
  echo "Posts a review on a GitHub PR."
  echo ""
  echo "Arguments:"
  echo "  PR_NUMBER   The pull request number"
  echo "  VERDICT     One of: approve, request-changes, comment"
  echo "  BODY_FILE   Path to file containing the review body"
  echo "  OWNER/REPO  Optional. Auto-detected from git remote if omitted."
  exit 1
}

ensure_gh_ready() {
  if ! command -v gh >/dev/null 2>&1; then
    echo "Error: gh CLI is required but not installed." >&2
    exit 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    echo "Error: gh CLI is not authenticated. Run: gh auth login" >&2
    exit 1
  fi
}

detect_repo() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || true)
  if [[ -z "$remote_url" ]]; then
    echo ""
    return
  fi
  echo "$remote_url" | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s#\.git$##'
}

if [[ $# -lt 3 ]]; then
  usage
fi

PR_NUMBER="$1"
VERDICT="$2"
BODY_FILE="$3"
REPO="${4:-}"

# Validate verdict
case "$VERDICT" in
  approve|request-changes|comment) ;;
  *)
    echo "Error: Invalid verdict '$VERDICT'. Must be one of: approve, request-changes, comment" >&2
    exit 1
    ;;
esac

# Validate body file
if [[ ! -f "$BODY_FILE" ]]; then
  echo "Error: Body file '$BODY_FILE' does not exist." >&2
  exit 1
fi

# Auto-detect repo
if [[ -z "$REPO" ]]; then
  REPO=$(detect_repo)
  if [[ -z "$REPO" ]]; then
    echo "Error: Not in a git repo or no 'origin' remote found. Provide OWNER/REPO as fourth argument." >&2
    exit 1
  fi
fi

ensure_gh_ready

# Map verdict to gh flag
GH_FLAG=""
case "$VERDICT" in
  approve)          GH_FLAG="--approve" ;;
  request-changes)  GH_FLAG="--request-changes" ;;
  comment)          GH_FLAG="--comment" ;;
esac

BODY=$(cat "$BODY_FILE")

echo "About to post review on PR #${PR_NUMBER} in ${REPO}"
echo "Verdict: ${VERDICT} (${GH_FLAG})"
echo "---"
echo "$BODY"
echo "---"
echo ""

# Confirm before posting
read -rp "Post this review? [y/N] " confirm
if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
  echo "Aborted."
  exit 0
fi

gh pr review "$PR_NUMBER" --repo "$REPO" "$GH_FLAG" --body "$BODY"
echo "Review posted successfully."
