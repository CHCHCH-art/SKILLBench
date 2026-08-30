---
name: team-testing
description: Unified team skill for testing team. All roles invoke this skill with --role arg for role-specific execution. Triggers on "team testing".
allowed-tools: TeamCreate(*), TeamDelete(*), SendMessage(*), TaskCreate(*), TaskUpdate(*), TaskList(*), TaskGet(*), Agent(*), AskUserQuestion(*), Read(*), Write(*), Edit(*), Bash(*), Glob(*), Grep(*)
---

# Team Testing

Unified team skill: progressive test coverage through Generator-Critic loops (generator<->executor), shared memory (defect pattern tracking), and dynamic layer selection. All team members invoke with `--role=xxx` to route to role-specific execution.

## Architecture

```
+---------------------------------------------------+
|  Skill(skill="team-testing")                       |
|  args="<task-description>"                         |
+-------------------+-------------------------------+
                    |
         Orchestration Mode (auto -> coordinator)
                    |
              Coordinator (inline)
              Phase 0-5 orchestration
                    |
    +-------+-------+-------+-------+
    v       v       v       v
 [tw]    [tw]    [tw]    [tw]
strate-  genera- execu-  analyst
gist     tor     tor

(tw) = team-worker agent
```

## Command Execution Protocol

When coordinator needs to execute a command (dispatch, monitor):

1. **Read the command file**: `roles/coordinator/commands/<command-name>.md`
2. **Follow the workflow** defined in the command file (Phase 2-4 structure)
3. **Commands are inline execution guides** -- NOT separate agents or subprocesses
4. **Execute synchronously** -- complete the command workflow before proceeding

## Role Router

### Input Parsing

Parse `$ARGUMENTS` to extract `--role`. If absent → Orchestration Mode (auto route to coordinator).

### Role Registry

| Role | Spec | Task Prefix | Inner Loop |
|------|------|-------------|------------|
| coordinator | [roles/coordinator/role.md](roles/coordinator/role.md) | (none) | - |
| strategist | [role-specs/strategist.md](role-specs/strategist.md) | STRATEGY-* | false |
| generator | [role-specs/generator.md](role-specs/generator.md) | TESTGEN-* | true |
| executor | [role-specs/executor.md](role-specs/executor.md) | TESTRUN-* | true |
| analyst | [role-specs/analyst.md](role-specs/analyst.md) | TESTANA-* | false |

> **⚠️ COMPACT PROTECTION**: 角色文件是执行文档，不是参考资料。当 context compression 发生后，角色指令仅剩摘要时，**必须立即 `Read` 对应 role.md 重新加载后再继续执行**。不得基于摘要执行任何 Phase。

### Dispatch

1. Extract `--role` from arguments
2. If no `--role` → route to coordinator (Orchestration Mode)
3. Look up role in registry → Read the role file → Execute its phases

### Orchestration Mode

When invoked without `--role`, coordinator auto-starts. User just provides task description.

**Invocation**: `Skill(skill="team-testing", args="<task-description>")`

**Lifecycle**:
```
User provides task description
  → coordinator Phase 1-3: Change scope analysis → TeamCreate → Create task chain
  → coordinator Phase 4: spawn first batch workers (background) → STOP
  → Worker executes → SendMessage callback → coordinator advances next step
  → Loop until pipeline complete → Phase 5 report
```

**User Commands** (wake paused coordinator):

| Command | Action |
|---------|--------|
| `check` / `status` | Output execution status graph, no advancement |
| `resume` / `continue` | Check worker states, advance next step |

---

## Shared Infrastructure

The following templates apply to all worker roles. Each role.md only needs to write **Phase 2-4** role-specific logic.

### Worker Phase 1: Task Discovery (shared by all workers)

Every worker executes the same task discovery flow on startup:

1. Call `TaskList()` to get all tasks
2. Filter: subject matches this role's prefix + owner is this role + status is pending + blockedBy is empty
3. No tasks → idle wait
4. Has tasks → `TaskGet` for details → `TaskUpdate` mark in_progress

**Resume Artifact Check** (prevent duplicate output after resume):
- Check whether this task's output artifact already exists
- Artifact complete → skip to Phase 5 report completion
- Artifact incomplete or missing → normal Phase 2-4 execution

### Worker Phase 5: Report (shared by all workers)

Standard reporting flow after task completion:

1. **Message Bus**: Call `mcp__ccw-tools__team_msg` to log message
   - Parameters: operation="log", session_id=<session-id>, from=<role>, type=<message-type>, data={ref: "<artifact-path>"}
   - `to` and `summary` auto-defaulted -- do NOT specify explicitly
   - **CLI fallback**: `ccw team log --session-id <session-id> --from <role> --type <type> --json`
2. **SendMessage**: Send result to coordinator (content and summary both prefixed with `[<role>]`)
3. **TaskUpdate**: Mark task completed
4. **Loop**: Return to Phase 1 to check next task

### Wisdom Accumulation (all roles)

Cross-task knowledge accumulation. Coordinator creates `wisdom/` directory at session initialization.

**Directory**:
```
<session-folder>/wisdom/
├── learnings.md      # Patterns and insights
├── decisions.md      # Architecture and design decisions
├── conventions.md    # Codebase conventions
└── issues.md         # Known risks and issues
```

**Worker Load** (Phase 2): Extract `Session: <path>` from task description, read wisdom directory files.
**Worker Contribute** (Phase 4/5): Write this task's discoveries to corresponding wisdom files.

### Role Isolation Rules

| Allowed | Forbidden |
|---------|-----------|
| Process tasks with own prefix | Process tasks with other role prefixes |
| SendMessage to coordinator | Communicate directly with other workers |
| Share state via team_msg(type='state_update') | Create tasks for other roles |
| Delegate to commands/ files | Modify resources outside own responsibility |

Coordinator additional restrictions: Do not write tests directly, do not execute tests, do not analyze coverage, do not bypass workers.

### Output Tagging

All outputs must carry `[role_name]` prefix in both SendMessage content/summary and team_msg summary.

### Message Bus (All Roles)

Every SendMessage **before**, must call `mcp__ccw-tools__team_msg` to log:

**Parameters**: operation="log", session_id=<session-id>, from=<role>, type=<message-type>, data={ref: "<artifact-path>"}

> `to` and `summary` are auto-defaulted by the tool.

**CLI fallback**: When MCP unavailable → `ccw team log --session-id <session-id> --from <role> --type <type> --json`

**Message types by role**:

| Role | Types |
|------|-------|
| coordinator | `pipeline_selected`, `gc_loop_trigger`, `quality_gate`, `task_unblocked`, `error`, `shutdown` |
| strategist | `strategy_ready`, `error` |
| generator | `tests_generated`, `tests_revised`, `error` |
| executor | `tests_passed`, `tests_failed`, `coverage_report`, `error` |
| analyst | `analysis_ready`, `error` |

### Shared State

All roles share state via `team_msg(type='state_update')` + `meta.json`:

| Role | Field |
|------|-------|
| strategist | `test_strategy` |
| generator | `generated_tests` |
| executor | `execution_results`, `defect_patterns` |
| analyst | `analysis_report`, `coverage_history` |

### Team Configuration

| Setting | Value |
|---------|-------|
| Team name | testing |
| Session directory | `.workflow/.team/TST-<slug>-<date>/` |
| Test layers | L1: Unit (80%), L2: Integration (60%), L3: E2E (40%) |

---

## Three-Pipeline Architecture

```
Targeted (small-scope changes):
  STRATEGY-001 → TESTGEN-001(L1 unit) → TESTRUN-001

Standard (progressive):
  STRATEGY-001 → TESTGEN-001(L1) → TESTRUN-001(L1) → TESTGEN-002(L2) → TESTRUN-002(L2) → TESTANA-001

Comprehensive (full coverage):
  STRATEGY-001 → [TESTGEN-001(L1) + TESTGEN-002(L2)](parallel) → [TESTRUN-001(L1) + TESTRUN-002(L2)](parallel) → TESTGEN-003(L3) → TESTRUN-003(L3) → TESTANA-001
```

### Generator-Critic Loop

generator <-> executor loop (revise tests when coverage below target):

```
TESTGEN → TESTRUN → (if coverage < target) → TESTGEN-fix → TESTRUN-2
                     (if coverage >= target) → next layer or TESTANA
```

### Cadence Control

**Beat model**: Event-driven, each beat = coordinator wake → process → spawn → STOP. Testing beat: strategy → generate → execute → analyze.

```
Beat Cycle (single beat)
═══════════════════════════════════════════════════════════
  Event                   Coordinator              Workers
───────────────────────────────────────────────────────────
  callback/resume ──→ ┌─ handleCallback ─┐
                      │  mark completed   │
                      │  check pipeline   │
                      ├─ handleSpawnNext ─┤
                      │  find ready tasks │
                      │  spawn workers ───┼──→ [Worker A] Phase 1-5
                      │  (parallel OK)  ──┼──→ [Worker B] Phase 1-5
                      └─ STOP (idle) ─────┘         │
                                                     │
  callback ←─────────────────────────────────────────┘
  (next beat)              SendMessage + TaskUpdate(completed)
═══════════════════════════════════════════════════════════
```

**Pipeline beat views**:

```
Targeted (3 beats, strictly serial)
──────────────────────────────────────────────────────────
Beat  1            2              3
      │            │              │
      STRATEGY → TESTGEN ──→ TESTRUN
      ▲                           ▲
   pipeline                   pipeline
    start                      done

STRATEGY=strategist  TESTGEN=generator  TESTRUN=executor

Standard (6 beats, progressive layers)
──────────────────────────────────────────────────────────
Beat  1            2           3           4           5           6
      │            │           │           │           │           │
      STRATEGY → TESTGEN-L1 → TESTRUN-L1 → TESTGEN-L2 → TESTRUN-L2 → TESTANA
                                    │
                              coverage check
                        (< target → GC loop)

Comprehensive (5+ beats, parallel windows)
──────────────────────────────────────────────────────────
Beat  1                  2                       3              4         5
      │            ┌─────┴─────┐          ┌──────┴──────┐       │         │
      STRATEGY → TESTGEN-L1 ∥ TESTGEN-L2 → TESTRUN-L1 ∥ TESTRUN-L2 → TESTGEN-L3 → TESTRUN-L3 → TESTANA
                 ▲                          ▲                                                       ▲
            parallel                   parallel                                                  pipeline
            window                     window                                                     done
```

**Checkpoints**:

| Trigger | Location | Behavior |
|---------|----------|----------|
| Coverage below target | After TESTRUN-* | If coverage < target → create TESTGEN-fix task (GC loop); else proceed |
| GC loop limit | Max 3 rounds per layer | Exceeds limit → accept current coverage with warning |
| Pipeline stall | No ready + no running | Check missing tasks, report to user |

**Stall Detection** (coordinator `handleCheck` executes):

| Check | Condition | Resolution |
|-------|-----------|------------|
| Worker no response | in_progress task no callback | Report waiting task list, suggest user `resume` |
| Pipeline deadlock | no ready + no running + has pending | Check blockedBy dependency chain, report blocking point |
| GC loop exceeded | generator/executor iteration > 3 rounds | Terminate loop, accept current coverage with warning |

### Task Metadata Registry

| Task ID | Role | Phase | Dependencies | Description |
|---------|------|-------|-------------|-------------|
| STRATEGY-001 | strategist | strategy | (none) | Analyze git diff, determine test layers, define coverage targets |
| TESTGEN-001 | generator | generate | STRATEGY-001 | Generate L1 unit tests |
| TESTRUN-001 | executor | execute | TESTGEN-001 | Execute L1 tests, collect coverage |
| TESTGEN-002 | generator | generate | TESTRUN-001 | Generate L2 integration tests (Standard/Comprehensive) |
| TESTRUN-002 | executor | execute | TESTGEN-002 | Execute L2 tests, collect coverage |
| TESTGEN-003 | generator | generate | TESTRUN-002 | Generate L3 E2E tests (Comprehensive only) |
| TESTRUN-003 | executor | execute | TESTGEN-003 | Execute L3 tests, collect coverage |
| TESTANA-001 | analyst | analyze | last TESTRUN-* | Defect pattern analysis, coverage gaps, quality report |

---

## Coordinator Spawn Template

### v5 Worker Spawn (all roles)

When coordinator spawns workers, use `team-worker` agent with role-spec path:

```
Agent({
  subagent_type: "team-worker",
  description: "Spawn <role> worker",
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
Execute built-in Phase 1 (task discovery) -> role-spec Phase 2-4 -> built-in Phase 5 (report).`
})
```

**Inner Loop roles** (generator, executor): Set `inner_loop: true`. The team-worker agent handles the loop internally.

**Single-task roles** (strategist, analyst): Set `inner_loop: false`.

---

## Completion Action

When the pipeline completes (all tasks done, coordinator Phase 5):

```
AskUserQuestion({
  questions: [{
    question: "Testing pipeline complete. What would you like to do?",
    header: "Completion",
    multiSelect: false,
    options: [
      { label: "Archive & Clean (Recommended)", description: "Archive session, clean up tasks and team resources" },
      { label: "Keep Active", description: "Keep session active for follow-up work or inspection" },
      { label: "Export Results", description: "Export deliverables to a specified location, then clean" }
    ]
  }]
})
```

| Choice | Action |
|--------|--------|
| Archive & Clean | Update session status="completed" -> TeamDelete() -> output final summary |
| Keep Active | Update session status="paused" -> output resume instructions: `Skill(skill="team-testing", args="resume")` |
| Export Results | AskUserQuestion for target path -> copy deliverables -> Archive & Clean |

---

## Unified Session Directory

```
.workflow/.team/TST-<slug>-<YYYY-MM-DD>/
├── .msg/messages.jsonl          # Message bus log
├── .msg/meta.json               # Session metadata
├── wisdom/                     # Cross-task knowledge
│   ├── learnings.md
│   ├── decisions.md
│   ├── conventions.md
│   └── issues.md
├── strategy/                   # Strategist output
│   └── test-strategy.md
├── tests/                      # Generator output
│   ├── L1-unit/
│   ├── L2-integration/
│   └── L3-e2e/
├── results/                    # Executor output
│   ├── run-001.json
│   └── coverage-001.json
└── analysis/                   # Analyst output
    └── quality-report.md
```

## Error Handling

| Scenario | Resolution |
|----------|------------|
| Unknown --role value | Error with available role list |
| Missing --role arg | Orchestration Mode → auto route to coordinator |
| Role file not found | Error with expected path (roles/<name>.md) |
| Task prefix conflict | Log warning, proceed |
| Coverage never reaches target | After 3 GC loops, accept current coverage with warning |
| Test environment broken | Notify user, suggest manual fix |
