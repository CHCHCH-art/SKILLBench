# Operation Contract

Purpose: load this when creating or auditing loop artifacts. It defines the minimum contract for `goal.md`, `progress.md`, `done.md`, `state.env`, and the required footer.

## Contract Checklist

- `goal.md` must include:
  - goal statement
  - why it matters
  - `3-6` measurable acceptance criteria
  - out-of-scope notes
- `progress.md` must record per iteration:
  - UTC timestamp
  - iteration number
  - changed files and summary
  - verification commands and outcomes
  - remaining work
  - decision: `CONTINUE` or `DONE`
- `done.md` must include:
  - completion timestamp
  - acceptance checklist with evidence
  - rollback note

## Footer Contract

Required response footer:

```text
NEXUS_LOOP_STATUS: READY | CONTINUE | DONE
NEXUS_LOOP_SUMMARY: <single-line summary>
```

Rules:
- `NEXUS_LOOP_STATUS` must use the exact token.
- Keep the summary concise and operational.
- Missing footer defaults to `CONTINUE` in conservative mode.

## Resume Contract

`state.env` should preserve:
- `NEXT_ITERATION`
- `LAST_STATUS`
- `LAST_UPDATED_AT`
- `ORIGIN_BRANCH` when `BRANCH_ISOLATION` is enabled
- `ITER_BRANCH` when `BRANCH_ISOLATION` is enabled
- any session resume flags

Recovery priority:
1. `progress.md` timeline
2. `runner.log` status stamps
3. `state.env`
