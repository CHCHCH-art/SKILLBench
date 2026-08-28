# Command: Dispatch

Create the testing task chain with correct dependencies and structured task descriptions. Supports targeted, standard, and comprehensive pipelines.

## Phase 2: Context Loading

| Input | Source | Required |
|-------|--------|----------|
| User requirement | From coordinator Phase 1 | Yes |
| Session folder | From coordinator Phase 2 | Yes |
| Pipeline mode | From session.json `pipeline` | Yes |
| Coverage targets | From session.json `coverage_targets` | Yes |

1. Load user requirement and scope from session.json
2. Load pipeline definition from SKILL.md Pipeline Definitions
3. Read `pipeline` mode and `coverage_targets` from session.json

## Phase 3: Task Chain Creation (Mode-Branched)

### Task Description Template

Every task description uses structured format:

```
TaskCreate({
  subject: "<TASK-ID>",
  description: "PURPOSE: <what this task achieves> | Success: <measurable criteria>
TASK:
  - <step 1: specific action>
  - <step 2: specific action>
CONTEXT:
  - Session: <session-folder>
  - Scope: <scope>
  - Layer: <L1-unit|L2-integration|L3-e2e>
  - Upstream artifacts: <artifact-1>, <artifact-2>
  - Shared memory: <session>/wisdom/.msg/meta.json
EXPECTED: <deliverable path> + <quality criteria>
CONSTRAINTS: <scope limits, focus areas>
---
InnerLoop: <true|false>"
})
TaskUpdate({ taskId: "<TASK-ID>", addBlockedBy: [<dependency-list>], owner: "<role>" })
```

### Mode Router

| Mode | Action |
|------|--------|
| `targeted` | Create 3 tasks: STRATEGY -> TESTGEN(L1) -> TESTRUN(L1) |
| `standard` | Create 6 tasks: STRATEGY -> TESTGEN(L1) -> TESTRUN(L1) -> TESTGEN(L2) -> TESTRUN(L2) -> TESTANA |
| `comprehensive` | Create 8 tasks with parallel groups |

---

### Targeted Pipeline

**STRATEGY-001** (strategist):
```
TaskCreate({
  subject: "STRATEGY-001",
  description: "PURPOSE: Analyze change scope, define test strategy | Success: Strategy doc with layer recommendations
TASK:
  - Analyze git diff for changed files and modules
  - Detect test framework and existing patterns
  - Define L1 unit test scope and coverage targets
CONTEXT:
  - Session: <session-folder>
  - Scope: <scope>
EXPECTED: <session>/strategy/test-strategy.md
CONSTRAINTS: Read-only analysis
---
InnerLoop: false"
})
TaskUpdate({ taskId: "STRATEGY-001", owner: "strategist" })
```

**TESTGEN-001** (generator, L1):
```
TaskCreate({
  subject: "TESTGEN-001",
  description: "PURPOSE: Generate L1 unit tests | Success: Executable test files covering priority files
TASK:
  - Read test strategy for priority files and patterns
  - Generate unit tests: happy path, edge cases, error handling
  - Validate syntax
CONTEXT:
  - Session: <session-folder>
  - Layer: L1-unit
  - Upstream artifacts: strategy/test-strategy.md
EXPECTED: <session>/tests/L1-unit/
CONSTRAINTS: Only generate test code, do not modify source
---
InnerLoop: true"
})
TaskUpdate({ taskId: "TESTGEN-001", addBlockedBy: ["STRATEGY-001"], owner: "generator" })
```

**TESTRUN-001** (executor, L1):
```
TaskCreate({
  subject: "TESTRUN-001",
  description: "PURPOSE: Execute L1 unit tests, collect coverage | Success: pass_rate >= 0.95 AND coverage >= target
TASK:
  - Run tests with coverage collection
  - Parse pass rate and coverage metrics
  - Auto-fix failures (max 3 iterations)
CONTEXT:
  - Session: <session-folder>
  - Input: tests/L1-unit
  - Coverage target: <L1-target>%
EXPECTED: <session>/results/run-001.json
CONSTRAINTS: Only fix test files, not source code
---
InnerLoop: true"
})
TaskUpdate({ taskId: "TESTRUN-001", addBlockedBy: ["TESTGEN-001"], owner: "executor" })
```

### Standard Pipeline

Adds to targeted:

**TESTGEN-002** (generator, L2): blockedBy ["TESTRUN-001"], Layer: L2-integration
**TESTRUN-002** (executor, L2): blockedBy ["TESTGEN-002"], Input: tests/L2-integration
**TESTANA-001** (analyst): blockedBy ["TESTRUN-002"]

### Comprehensive Pipeline

**Parallel groups**:
- TESTGEN-001 + TESTGEN-002 both blockedBy ["STRATEGY-001"] (parallel generation)
- TESTRUN-001 blockedBy ["TESTGEN-001"], TESTRUN-002 blockedBy ["TESTGEN-002"] (parallel execution)
- TESTGEN-003 blockedBy ["TESTRUN-001", "TESTRUN-002"], Layer: L3-e2e
- TESTRUN-003 blockedBy ["TESTGEN-003"]
- TESTANA-001 blockedBy ["TESTRUN-003"]

## Phase 4: Validation

1. Verify all tasks created with correct subjects and dependencies
2. Check no circular dependencies
3. Verify blockedBy references exist
4. Log task chain to team_msg:

```
mcp__ccw-tools__team_msg({
  operation: "log",
  session_id: <session-id>,
  from: "coordinator",
  type: "pipeline_selected",
  data: { pipeline: "<mode>", task_count: <N> }
})
```
