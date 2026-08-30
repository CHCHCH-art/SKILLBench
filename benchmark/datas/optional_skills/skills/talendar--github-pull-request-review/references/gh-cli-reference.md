# gh CLI Reference

Quick reference for all `gh` commands and API endpoints used by this skill.

## Auto-detect Owner/Repo

```bash
gh repo view --json nameWithOwner --jq .nameWithOwner
# Returns: owner/repo
```

Or parse from git remote:
```bash
git remote get-url origin | sed -E 's#^(https?://[^/]+/|git@[^:]+:)##; s#\.git$##'
```

## PR Metadata

```bash
# Full metadata as JSON
gh pr view <PR> --json title,body,baseRefName,headRefName,state,labels,milestone,author,reviewRequests,reviews,additions,deletions,changedFiles

# Human-readable summary
gh pr view <PR>
```

## PR Diff

```bash
gh pr diff <PR>
```

For very large PRs, fetch the file list first:
```bash
gh api --paginate repos/{owner}/{repo}/pulls/{pr}/files --jq '.[].filename'
```

## PR Comments

```bash
# PR-level discussion comments (NOT inline review comments)
# Note: avoid `gh pr view --comments` — it triggers a deprecated GraphQL field (projectCards).
gh api --paginate repos/{owner}/{repo}/issues/{pr}/comments \
  --jq '.[] | {body, user: .user.login, created_at}'
```

**Important:** The endpoint above does NOT return inline code review comments.

## Inline Review Comments

```bash
# Code-level review comments (on specific lines)
gh api --paginate repos/{owner}/{repo}/pulls/{pr}/comments \
  --jq '.[] | {path, line, body, user: .user.login}'
```

## Review Decisions

```bash
gh api --paginate repos/{owner}/{repo}/pulls/{pr}/reviews \
  --jq '.[] | {user: .user.login, state, body}'
```

## Files Changed

```bash
gh api --paginate repos/{owner}/{repo}/pulls/{pr}/files \
  --jq '.[] | {filename, status, additions, deletions}'
```

## CI Checks

```bash
# Status of all checks
gh pr checks <PR>

# If a check failed, view the logs
gh run view <RUN_ID> --log-failed
```

## Issues

```bash
gh issue view <ISSUE_NUMBER> --json title,body,comments,labels,state
```

## Posting Reviews

```bash
# Approve
gh pr review <PR> --approve --body "LGTM! Summary..."

# Request changes
gh pr review <PR> --request-changes --body "Full report..."

# Comment (no verdict)
gh pr review <PR> --comment --body "Full report..."
```

## Checkout PR Branch

```bash
gh pr checkout <PR>
```
