# Review Checklist

Detailed guidance for analyzing code changes. Use this as a reference during Phase 3 of the review workflow.

## 1. Goal Alignment

- Does the PR achieve what the linked issue(s) describe?
- Are there requirements from the issue that are missing in the implementation?
- Is there scope creep — changes unrelated to the stated goal?
- If no issue is linked, does the PR description clearly explain the motivation?

## 2. Bugs and Logic Errors

Look for:
- **Off-by-one errors** in loops, array indexing, pagination
- **Null/undefined handling**: unchecked optional values, missing null guards
- **Race conditions**: shared mutable state, concurrent access without synchronization
- **Missing edge cases**: empty arrays, zero values, negative numbers, empty strings
- **Error handling gaps**: bare catch blocks, swallowed errors, missing error propagation
- **Type coercion issues**: implicit conversions, loose equality
- **Resource leaks**: unclosed connections, file handles, timers

Avoid:
- Flagging stylistic preferences as bugs
- Reporting theoretical issues without evidence in the actual code path

## 3. Security Risks

Only report HIGH-confidence findings. Trace data flow from source to sink.

| Category | What to look for |
|----------|-----------------|
| **Injection** | SQL concatenation, shell command injection, template injection, header injection |
| **XSS** | Unescaped user input in HTML output, `dangerouslySetInnerHTML`, `innerHTML` |
| **Auth/Authz** | Missing auth checks on new endpoints, privilege escalation, broken access control |
| **Secrets** | API keys, tokens, passwords hardcoded in source (not env vars) |
| **Deserialization** | `eval()`, `pickle.loads()`, `yaml.load()` (without safe loader), `JSON.parse` on untrusted input without validation |
| **SSRF** | User-controlled URLs passed to HTTP clients without allowlist |
| **Path traversal** | User input in file paths without sanitization |

### Common False Positives to Avoid
- `hashlib.md5` / `hashlib.sha1` used for checksums or cache keys — only flag for password hashing
- `random.random()` used for non-security purposes (shuffling UI, test data) — only flag for tokens/secrets
- Internal-only endpoints behind VPN/auth — don't flag as "publicly accessible"
- Test files with hardcoded credentials — only flag if they look like real secrets

## 4. Codebase Consistency

Compare against surrounding code in the same repo, not abstract ideals:
- **Naming conventions**: Does the PR follow the existing naming style (camelCase vs snake_case, etc.)?
- **File organization**: Are new files placed in the expected directories?
- **Import patterns**: Does the PR follow existing import ordering and grouping?
- **Error handling patterns**: Does it use the same error handling approach as the rest of the codebase?
- **Architecture**: Does it follow the existing patterns (e.g., MVC, repository pattern, etc.)?

## 5. Test Coverage

- Are new code paths tested?
- Are existing tests updated for changed behavior?
- Are there obvious untested edge cases?
- Do tests actually assert meaningful behavior (not just "doesn't throw")?
- Are tests isolated and deterministic (no flaky tests)?

## 6. Performance

Look for issues with measurable impact:
- **N+1 queries**: Loop that makes a DB/API call per iteration
- **Unnecessary re-renders**: Missing memoization in hot paths
- **Unbounded operations**: Loops/queries without limits, missing pagination
- **Large memory allocations**: Loading entire datasets into memory
- **Missing indexes**: New queries on unindexed columns
- **Blocking operations**: Synchronous I/O in async contexts

## 7. Documentation

- Are public APIs documented (parameters, return values, error cases)?
- Are complex algorithms explained with comments?
- Are breaking changes noted in the PR description?
- Is the README updated if the PR changes setup/usage?
