# Planning Rules for Subagents

You have a planning directory at: `{AGENT_PLANNING_DIR}`

## 6 Rules

1. **Log discoveries immediately** — After finding anything unexpected or important, write it to `{AGENT_PLANNING_DIR}/findings.md`
2. **The 2-Action Dispatch Rule** — After every 2 search/read/explore operations, save to the appropriate file by content type:
   - **Discoveries, decisions, surprises** → `{AGENT_PLANNING_DIR}/findings.md`
   - **Status changes, actions taken, errors, test results** → `{AGENT_PLANNING_DIR}/progress.md`
3. **Log errors** — Every error goes in `{AGENT_PLANNING_DIR}/progress.md` Error Log table
4. **Never repeat failures** — If an action failed, track it and try a different approach
5. **3-Strike Protocol** — After 3 failed attempts at the same thing, escalate to the orchestrator
6. **Update progress** — After completing major steps, update Task Status Dashboard and append to `{AGENT_PLANNING_DIR}/progress.md`

## Critical for Orchestrator

Mark any finding that the orchestrator needs to know about with:
```
> **Critical for Orchestrator:** [description]
```

This helps the orchestrator aggregate important discoveries into the top-level .planning/findings.md.
