#!/usr/bin/env bash
set -euo pipefail

# fetch-pr-context.sh — Fetches PR metadata, diff, linked issues, and CI status.
# Usage: fetch-pr-context.sh <PR_NUMBER> [OWNER/REPO]

usage() {
  echo "Usage: $0 <PR_NUMBER> [OWNER/REPO]"
  echo ""
  echo "Fetches PR metadata, linked issues, comments, and CI status."
  echo "If OWNER/REPO is omitted, auto-detects from git remote origin."
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

# Extract issue numbers from PR body text.
# Matches: Fixes #N, Closes #N, Resolves #N, Related to #N, bare #N
extract_issues() {
  local body="$1"
  local issues
  issues=$(echo "$body" | grep -oiE '(Fixes|Closes|Resolves|Related to)\s+#[0-9]+' | grep -oE '[0-9]+' || true)
  local bare_issues
  bare_issues=$(echo "$body" | grep -oE '#[0-9]+' | grep -oE '[0-9]+' || true)
  # Combine, deduplicate, sort
  local all_issues
  all_issues=$(printf '%s\n%s\n' "$issues" "$bare_issues" | grep -E '^[0-9]+$' | sort -un || true)
  if [[ -z "$all_issues" ]]; then
    echo "No linked issues found."
  else
    echo "$all_issues"
  fi
}

detect_repo() {
  local remote_url
  remote_url=$(git remote get-url origin 2>/dev/null || true)
  if [[ -z "$remote_url" ]]; then
    echo ""
    return
  fi
  # Parse owner/repo from SSH or HTTPS URLs
  echo "$remote_url" | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s#\.git$##'
}

if [[ $# -lt 1 ]]; then
  usage
fi

PR_NUMBER="$1"
REPO="${2:-}"

# Validate PR number format
if [[ ! "$PR_NUMBER" =~ ^[0-9]+$ ]]; then
  echo "Error: PR_NUMBER must be numeric (for example: 123)." >&2
  exit 1
fi

# Auto-detect owner/repo from git remote if not provided
if [[ -z "$REPO" ]]; then
  REPO=$(detect_repo)
  if [[ -z "$REPO" ]]; then
    echo "Error: Not in a git repo or no 'origin' remote found. Provide OWNER/REPO as second argument." >&2
    exit 1
  fi
fi

ensure_gh_ready

echo "=== PR Metadata ==="
gh pr view "$PR_NUMBER" --repo "$REPO" --json title,body,baseRefName,headRefName,state,labels,milestone,author,reviewRequests,reviews,additions,deletions,changedFiles

echo ""
echo "=== PR Comments ==="
gh api --paginate "repos/${REPO}/issues/${PR_NUMBER}/comments" --jq '.[] | {body, user: .user.login, created_at}' || echo "(Could not fetch PR comments)"

echo ""
echo "=== Inline Review Comments ==="
gh api --paginate "repos/${REPO}/pulls/${PR_NUMBER}/comments" --jq '.[] | {path, line, body, user: .user.login}' || echo "(Could not fetch inline review comments)"

echo ""
echo "=== Changed Files ==="
gh api --paginate "repos/${REPO}/pulls/${PR_NUMBER}/files" --jq '.[] | {filename, status, additions, deletions}' || echo "(Could not fetch changed files)"

echo ""
echo "=== PR Diff ==="
gh pr diff "$PR_NUMBER" --repo "$REPO" || echo "(Could not fetch PR diff)"

echo ""
echo "=== Linked Issues ==="
PR_BODY=$(gh pr view "$PR_NUMBER" --repo "$REPO" --json body --jq '.body // ""')
ISSUE_NUMBERS=$(extract_issues "$PR_BODY")
echo "$ISSUE_NUMBERS"

if [[ "$ISSUE_NUMBERS" != "No linked issues found." ]]; then
  while IFS= read -r issue_num; do
    echo ""
    echo "--- Issue #${issue_num} ---"
    gh issue view "$issue_num" --repo "$REPO" --json title,body,comments,labels,state || echo "Could not fetch issue #${issue_num}"
  done <<< "$ISSUE_NUMBERS"
fi

echo ""
echo "=== CI Status ==="
gh pr checks "$PR_NUMBER" --repo "$REPO" || echo "(No CI checks found)"
