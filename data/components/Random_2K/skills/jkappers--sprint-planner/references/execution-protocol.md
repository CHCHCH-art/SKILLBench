# Execution Protocol and Rollback Procedures

Append these sections to every sprint plan document.

## Execution Protocol

1. Read acceptance criteria before starting. Criteria define completion.
2. Read the `style_anchor` document (if defined) before the first sprint. Apply its conventions to every sprint.
3. Use `reference_material` paths to locate source code. Do not guess or duplicate.
4. Complete ALL acceptance criteria for a sprint before proceeding to next sprint.
5. After each sprint, output the **Sprint Completion Report** (see Verification Gate below) before starting the next sprint.
6. If a sprint fails:
   - Stop immediately. Do not continue to next sprint.
   - Output failure details: file path, line number, error message
   - Propose fix or request clarification
7. If a criterion is ambiguous, request clarification before starting sprint.

## Verification Gate

After completing each sprint and before starting the next, output this structured report:

```
Sprint [N] Completion Report
---
Files created/modified:
  - [absolute paths]

Acceptance criteria results:
  - [criterion 1]: PASS | FAIL (evidence)
  - [criterion 2]: PASS | FAIL (evidence)
  - ...

Build/test output:
  [command]: [result summary]

Style anchor compliance:
  [Confirmed | Deviations noted: ...]

Deviations or blockers:
  [None | description]

Ready for next sprint: YES | NO (reason)
```

Do NOT proceed to the next sprint until all criteria show PASS and ready state is YES.

## Rollback on Failure

If Sprint N fails acceptance criteria:

1. Run `git status` to identify modified files
2. Run `git diff` to review changes
3. If changes are salvageable:
   - Fix specific errors
   - Re-run acceptance criteria
   - Proceed only if ALL criteria pass
4. If changes are not salvageable:
   - Run `git restore .` to revert all changes
   - Re-read sprint definition
   - Restart sprint from clean state
5. After 2 failed attempts on same sprint:
   - Stop execution
   - Request human review of sprint definition
   - Sprint may need scope reduction or clarification
