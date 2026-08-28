# Commit Conventions

## Structure

```
<type>: <subject>

[Why]: <1 sentence: motivation>
[What]: <1 sentence: implementation>
[Impact]: <1 sentence: impact>
```

## Types

- `feat` - New functionality
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Formatting (spaces, quotes)
- `refactor` - Refactoring without functional change
- `perf` - Performance improvements
- `test` - Tests
- `chore` - Build, deps, CI/CD
- `env` - Environment configuration

## Section Guide

### [Why] - Motivation

What problem does it solve? What need does it address?

Bad: "Users wanted authentication"
Good: "Users needed to keep active sessions across reloads
without losing context"

### [What] - Implementation

What was implemented or technically modified?

Bad: "Added JWT"
Good: "Implemented JWT authentication with token rotation
and middleware validation"

### [Impact] - Impact

How does it affect the application/module/users?

Bad: "Users can log in"
Good: "Users stay authenticated for 7 days; API requests
include headers automatically"

## Grouping Patterns

### Group if:

- Same module (models.py + schemas.py)
- Logically related (auth.py + decorators.py) or
  (Controller + corresponding views + routing)
- Docs + associated changes

### Do NOT group if:

- Different domains
- Mixed types (refactor + feature)
- Independent changes

## Examples

### feat: Add user authentication with JWT

[Why]: Users needed to keep secure sessions across reloads
without calling login repeatedly.

[What]: Implemented JWT authentication with access/refresh
tokens and validation middleware on protected routes.

[Impact]: Users authenticated for 7 days; API validates
tokens automatically; protected URLs redirect to login.

---

### fix: Resolve process query validation errors

[Why]: Queries with invalid filters caused unexpected
crashes in production.

[What]: Centralized parameter validation in schemas with
specific error messages.

[Impact]: Errors return clear 400 responses; users see
helpful messages instead of crashes.

---

### refactor: Optimize DiagramStore eliminating redundancy

[Why]: Redundant methods caused duplicated maintenance and
inconsistent bugs.

[What]: Consolidated 3 similar methods into a generic
function with parameters.

[Impact]: Less code; bugs fixed in one place; future
improvements are simpler.
