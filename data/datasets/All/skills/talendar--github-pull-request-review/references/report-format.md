# Report Format

Template and guidelines for the PR review report.

## Template

```markdown
## PR Review: #<number> — <title>

### Summary
[1-2 sentences: what the PR does and whether it achieves its stated goal]

### Verdict: ✅ APPROVE / ⚠️ APPROVE WITH COMMENTS / ❌ REQUEST CHANGES

### Blocking Issues (must fix before merge)
1. **[BUG/SECURITY/LOGIC]** <description> — `file.py:123`

### Non-blocking Issues (should fix)
1. **[STYLE/PERF/DOCS]** <description> — `file.py:456`

### Positive Observations
- [Good patterns, clever solutions, well-tested areas]

### Checks
| Check      | Result | Notes                    |
|------------|--------|--------------------------|
| Lint       | ✅/❌   | <detail if failed>       |
| Type-check | ✅/❌   |                          |
| Tests      | ✅/❌   | X passed, Y failed       |
| CI         | ✅/❌   | <from gh pr checks>      |

### Context
- Linked issues: #N, #M
- Files changed: N (additions: +X, deletions: -Y)
```

## Verdict Criteria

| Verdict | When to use |
|---------|-------------|
| ✅ APPROVE | No blocking issues. Minor non-blocking items are OK. |
| ⚠️ APPROVE WITH COMMENTS | No blocking issues, but several non-blocking items that should be addressed. |
| ❌ REQUEST CHANGES | One or more blocking issues that must be fixed before merge. |

## Issue Priority Order

Rank blocking issues by severity:
1. Security vulnerabilities
2. Bugs and data corruption risks
3. Logic errors
4. Breaking changes (API, behavior)

## Good vs Bad Findings

### Good Finding
> **[BUG]** `getUserById` returns `null` when the user is soft-deleted, but the caller at `routes/profile.ts:45` doesn't handle `null`, causing an unhandled exception. — `services/user.ts:23`

Why it's good: Specific, references exact file and line, explains the consequence, traces the data flow.

### Bad Finding
> **[BUG]** There might be null pointer issues in the user service.

Why it's bad: Vague, no file/line reference, "might be" indicates speculation, no trace of actual data flow.

### Good Finding
> **[SECURITY]** User input from `req.query.redirect` is passed directly to `res.redirect()` at `routes/auth.ts:67` without validation, enabling open redirect attacks.

### Bad Finding
> **[SECURITY]** The code uses `res.redirect()` which could be vulnerable.

## Rules

- Every issue MUST reference a specific file and line number.
- If nothing significant is found, say so explicitly — do not invent issues to fill the report.
- Include positive feedback for well-written code. Reviewers should acknowledge good work.
- Keep the summary to 1-2 sentences. Details go in the issues section.
- If no checks are available, note "N/A" in the Checks table, not a failure.
