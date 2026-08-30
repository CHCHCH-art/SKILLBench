# Command: Monitor

Handle all coordinator monitoring events: worker callbacks, status checks, pipeline advancement, Generator-Critic loop control, and completion.

## Phase 2: Context Loading

| Input | Source | Required |
|-------|--------|----------|
| Session state | <session>/session.json | Yes |
| Task list | TaskList() | Yes |
| Trigger event | From Entry Router detection | Yes |
| Pipeline definition | From SKILL.md | Yes |

1. Load session.json for current state, pipeline mode, gc_rounds, coverage_targets
2. Run TaskList() to get current task statuses
3. Identify trigger event type from Entry Router

## Phase 3: Event Handlers

### handleCallback

Triggered when a worker sends completion message.

1. Parse message to identify role, task ID:

| Message Pattern | Role Detection |
|----------------|---------------|
| `[strategist]` or task ID `STRATEGY-*` | strategist |
| `[generator]` or task ID `TESTGEN-*` | generator |
| `[executor]` or task ID `TESTRUN-*` | executor |
| `[analyst]` or task ID `TESTANA-*` | analyst |

2. Mark task as completed:

```
TaskUpdate({ taskId: "<task-id>", status: "completed" })
```

3. Record completion in session state

4. **Generator-Critic check** (executor callbacks only):
   - If completed task is TESTRUN-* AND message indicates tests_failed or coverage below target:
   - Read gc_rounds for this layer from session.json
   - Execute **GC Loop Decision** (see below)

5. Checkpoints:

| Completed Task | Checkpoint | Action |
|---------------|------------|--------|
| STRATEGY-001 | CP-1 | Notify user: test strategy ready for review |
| Last TESTRUN-* | CP-2 | Check coverage, decide GC loop or next layer |
| TESTANA-001 | CP-3 | Pipeline complete |

6. Proceed to handleSpawnNext

### GC Loop Decision

When executor reports test results:

| Condition | Action |
|-----------|--------|
| passRate >= 0.95 AND coverage >= target | Log success, proceed to next stage |
| (passRate < 0.95 OR coverage < target) AND gcRound < maxRounds | Create TESTGEN-fix task, increment gc_round |
| gcRound >= maxRounds | Accept current coverage with warning, proceed |

**TESTGEN-fix task creation**:

```
TaskCreate({
  subject: "TESTGEN-<layer>-fix-<round>",
  description: "PURPOSE: Revise tests to fix failures and improve coverage
TASK:
  - Read previous test results and failure details
  - Revise tests to address failures
  - Improve coverage for uncovered areas
CONTEXT:
  - Session: <session-folder>
  - Layer: <layer>
  - Previous results: <session>/results/run-<N>.json
EXPECTED: Revised test files in <session>/tests/<layer>/
---
InnerLoop: true"
})
TaskUpdate({ taskId: "TESTGEN-<layer>-fix-<round>", owner: "generator" })
```

Create TESTRUN-fix blocked on TESTGEN-fix.

### handleSpawnNext

Find and spawn the next ready tasks.

1. Scan task list for tasks where:
   - Status is "pending"
   - All blockedBy tasks have status "completed"

2. For each ready task, determine role from task subject prefix:

| Prefix | Role | Inner Loop |
|--------|------|------------|
| STRATEGY-* | strategist | false |
| TESTGEN-* | generator | true |
| TESTRUN-* | executor | true |
| TESTANA-* | analyst | false |

3. Spawn team-worker:

```
Agent({
  subagent_type: "team-worker",
  description: "Spawn <role> worker for <task-id>",
  team_name: "testing",
  name: "<role>",
  run_in_background: true,
  prompt: `## Role Assignment
role: <role>
role_spec: .claude/skills/team-testing/role-specs/<role>.md
session: <session-folder>
session_id: <session-id>
team_name: testing
requirement: <task-description>
inner_loop: <true|false>

Read role_spec file to load Phase 2-4 domain instructions.
Execute built-in Phase 1 -> role-spec Phase 2-4 -> built-in Phase 5.`
})
```

4. **Parallel spawn** (comprehensive pipeline):

| Scenario | Spawn Behavior |
|----------|---------------|
| TESTGEN-001 + TESTGEN-002 both unblocked | Spawn both in parallel |
| TESTRUN-001 + TESTRUN-002 both unblocked | Spawn both in parallel |

5. STOP after spawning -- wait for next callback

### handleCheck

Output current pipeline status.

```
Pipeline Status (<pipeline-mode>):
  [DONE]  STRATEGY-001  (strategist)  -> test-strategy.md
  [RUN]   TESTGEN-001   (generator)   -> generating L1...
  [WAIT]  TESTRUN-001   (executor)    -> blocked by TESTGEN-001
  [WAIT]  TESTGEN-002   (generator)   -> blocked by TESTRUN-001
  ...

GC Rounds: L1: 0/3, L2: 0/3
Session: <session-id>
```

Output status -- do NOT advance pipeline.

### handleResume

Resume pipeline after user pause or interruption.

1. Audit task list for inconsistencies:
   - Tasks stuck in "in_progress" -> reset to "pending"
   - Tasks with completed blockers but still "pending" -> include in spawn list
2. Proceed to handleSpawnNext

### handleComplete

Triggered when all pipeline tasks are completed and no GC cycles remain.

**Completion check**:

| Pipeline | Completion Condition |
|----------|---------------------|
| targeted | STRATEGY-001 + TESTGEN-001 + TESTRUN-001 (+ any fix tasks) completed |
| standard | All 6 tasks (+ any fix tasks) completed |
| comprehensive | All 8 tasks (+ any fix tasks) completed |

1. If any tasks not completed, return to handleSpawnNext
2. If all completed, transition to coordinator Phase 5

## Phase 4: State Persistence

After every handler execution:

1. Update session.json with current state (active tasks, gc_rounds per layer, last event)
2. Verify task list consistency
3. STOP and wait for next event
