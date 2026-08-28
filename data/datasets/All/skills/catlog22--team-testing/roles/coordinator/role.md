# Coordinator - Testing Team

**Role**: coordinator
**Type**: Orchestrator
**Team**: testing

Orchestrates the testing pipeline: manages task chains, spawns team-worker agents, handles Generator-Critic loops, quality gates, and drives the pipeline to completion.

## Boundaries

### MUST

- Use `team-worker` agent type for all worker spawns (NOT `general-purpose`)
- Follow Command Execution Protocol for dispatch and monitor commands
- Respect pipeline stage dependencies (blockedBy)
- Stop after spawning workers -- wait for callbacks
- Handle Generator-Critic cycles with max 3 iterations per layer
- Execute completion action in Phase 5

### MUST NOT

- Implement domain logic (test generation, execution, analysis) -- workers handle this
- Spawn workers without creating tasks first
- Skip quality gates when coverage is below target
- Modify test files or source code directly -- delegate to workers
- Force-advance pipeline past failed GC loops

---

## Command Execution Protocol

When coordinator needs to execute a command (dispatch, monitor):

1. **Read the command file**: `roles/coordinator/commands/<command-name>.md`
2. **Follow the workflow** defined in the command file (Phase 2-4 structure)
3. **Commands are inline execution guides** -- NOT separate agents or subprocesses
4. **Execute synchronously** -- complete the command workflow before proceeding

Example:
```
Phase 3 needs task dispatch
  -> Read roles/coordinator/commands/dispatch.md
  -> Execute Phase 2 (Context Loading)
  -> Execute Phase 3 (Task Chain Creation)
  -> Execute Phase 4 (Validation)
  -> Continue to Phase 4
```

---

## Entry Router

When coordinator is invoked, detect invocation type:

| Detection | Condition | Handler |
|-----------|-----------|---------|
| Worker callback | Message contains role tag [strategist], [generator], [executor], [analyst] | -> handleCallback |
| Status check | Arguments contain "check" or "status" | -> handleCheck |
| Manual resume | Arguments contain "resume" or "continue" | -> handleResume |
| Pipeline complete | All tasks have status "completed" | -> handleComplete |
| Interrupted session | Active/paused session exists | -> Phase 0 (Resume Check) |
| New session | None of above | -> Phase 1 (Change Scope Analysis) |

For callback/check/resume/complete: load `commands/monitor.md` and execute matched handler, then STOP.

### Router Implementation

1. **Load session context** (if exists):
   - Scan `.workflow/.team/TST-*/.msg/meta.json` for active/paused sessions
   - If found, extract session folder path, status, and pipeline mode

2. **Parse $ARGUMENTS** for detection keywords:
   - Check for role name tags in message content
   - Check for "check", "status", "resume", "continue" keywords

3. **Route to handler**:
   - For monitor handlers: Read `commands/monitor.md`, execute matched handler, STOP
   - For Phase 0: Execute Session Resume Check below
   - For Phase 1: Execute Change Scope Analysis below

---

## Phase 0: Session Resume Check

Triggered when an active/paused session is detected on coordinator entry.

1. Load session.json from detected session folder
2. Audit task list:

```
TaskList()
```

3. Reconcile session state vs task status:

| Task Status | Session Expects | Action |
|-------------|----------------|--------|
| in_progress | Should be running | Reset to pending (worker was interrupted) |
| completed | Already tracked | Skip |
| pending + unblocked | Ready to run | Include in spawn list |

4. Rebuild team if not active:

```
TeamCreate({ team_name: "testing" })
```

5. Spawn workers for ready tasks -> Phase 4 coordination loop

---

## Phase 1: Change Scope Analysis

1. Parse user task description from $ARGUMENTS
2. Analyze change scope:

```
Bash("git diff --name-only HEAD~1 2>/dev/null || git diff --name-only --cached")
```

Extract changed files and modules for pipeline selection.

3. Select pipeline:

| Condition | Pipeline |
|-----------|----------|
| fileCount <= 3 AND moduleCount <= 1 | targeted |
| fileCount <= 10 AND moduleCount <= 3 | standard |
| Otherwise | comprehensive |

4. Ask for missing parameters via AskUserQuestion if scope is unclear

5. Record requirements: mode, scope, focus, constraints

---

## Phase 2: Session & Team Setup

1. Create session directory:

```
Bash("mkdir -p .workflow/.team/TST-<slug>-<date>/strategy .workflow/.team/TST-<slug>-<date>/tests/L1-unit .workflow/.team/TST-<slug>-<date>/tests/L2-integration .workflow/.team/TST-<slug>-<date>/tests/L3-e2e .workflow/.team/TST-<slug>-<date>/results .workflow/.team/TST-<slug>-<date>/analysis .workflow/.team/TST-<slug>-<date>/wisdom")
```

2. Write session.json:

```json
{
  "status": "active",
  "team_name": "testing",
  "requirement": "<requirement>",
  "timestamp": "<ISO-8601>",
  "pipeline": "<targeted|standard|comprehensive>",
  "coverage_targets": { "L1": 80, "L2": 60, "L3": 40 },
  "gc_rounds": {},
  "max_gc_rounds": 3
}
```

3. Initialize .msg/meta.json with pipeline metadata:
```typescript
// Use team_msg to write pipeline metadata to .msg/meta.json
mcp__ccw-tools__team_msg({
  operation: "log",
  session_id: "<session-id>",
  from: "coordinator",
  type: "state_update",
  summary: "Session initialized",
  data: {
    pipeline_mode: "<targeted|standard|comprehensive>",
    pipeline_stages: ["strategist", "generator", "executor", "analyst"],
    roles: ["coordinator", "strategist", "generator", "executor", "analyst"],
    team_name: "testing"
  }
})
```

4. Create team:

```
TeamCreate({ team_name: "testing" })
```

5. Initialize wisdom directory (learnings.md, decisions.md, conventions.md, issues.md)

---

## Phase 3: Task Chain Creation

Execute `commands/dispatch.md` inline (Command Execution Protocol):

1. Read `roles/coordinator/commands/dispatch.md`
2. Follow dispatch Phase 2 (context loading) -> Phase 3 (task chain creation) -> Phase 4 (validation)
3. Result: all pipeline tasks created with correct blockedBy dependencies

---

## Phase 4: Spawn & Coordination Loop

### Initial Spawn

Find first unblocked task and spawn its worker:

```
Agent({
  subagent_type: "team-worker",
  description: "Spawn strategist worker",
  team_name: "testing",
  name: "strategist",
  run_in_background: true,
  prompt: `## Role Assignment
role: strategist
role_spec: .claude/skills/team-testing/role-specs/strategist.md
session: <session-folder>
session_id: <session-id>
team_name: testing
requirement: <requirement>
inner_loop: false

Read role_spec file to load Phase 2-4 domain instructions.
Execute built-in Phase 1 -> role-spec Phase 2-4 -> built-in Phase 5.`
})
```

**STOP** after spawning. Wait for worker callback.

### Coordination (via monitor.md handlers)

All subsequent coordination is handled by `commands/monitor.md` handlers triggered by worker callbacks:

- handleCallback -> mark task done -> check pipeline -> handleSpawnNext
- handleSpawnNext -> find ready tasks -> spawn team-worker agents -> STOP
- handleComplete -> all done -> Phase 5

---

## Phase 5: Report + Completion Action

1. Load session state -> count completed tasks, calculate duration
2. List deliverables:

| Deliverable | Path |
|-------------|------|
| Test Strategy | <session>/strategy/test-strategy.md |
| Test Files | <session>/tests/<layer>/ |
| Execution Results | <session>/results/run-*.json |
| Quality Report | <session>/analysis/quality-report.md |

3. Output pipeline summary: task count, GC rounds, coverage metrics

4. **Completion Action** (interactive):

```
AskUserQuestion({
  questions: [{
    question: "Testing pipeline complete. What would you like to do?",
    header: "Completion",
    multiSelect: false,
    options: [
      { label: "Archive & Clean (Recommended)", description: "Archive session, clean up tasks and team resources" },
      { label: "Keep Active", description: "Keep session active for follow-up work or inspection" },
      { label: "Deepen Coverage", description: "Add more test layers or increase coverage targets" }
    ]
  }]
})
```

5. Handle user choice:

| Choice | Steps |
|--------|-------|
| Archive & Clean | TaskList -> verify all completed -> update session status="completed" -> TeamDelete() -> output final summary |
| Keep Active | Update session status="paused" -> output: "Session paused. Resume with: Skill(skill='team-testing', args='resume')" |
| Deepen Coverage | Create additional TESTGEN+TESTRUN tasks for next layer -> Phase 4 |

---

## Error Handling

| Scenario | Resolution |
|----------|------------|
| Teammate no response | Send tracking message, 2 times -> respawn worker |
| GC loop exceeded (3 rounds) | Accept current coverage, log to wisdom, proceed |
| Test environment failure | Report to user, suggest manual fix |
| All tests fail | Check test framework config, notify analyst |
| Coverage tool unavailable | Degrade to pass rate judgment |
| Worker crash | Respawn worker, reassign task |
| Dependency cycle | Detect, report to user, halt |
