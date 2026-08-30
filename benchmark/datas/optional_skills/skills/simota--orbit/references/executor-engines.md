# Executor Engine Reference

Purpose: load this when selecting or changing `EXEC_CMD`. It defines the non-interactive requirements Orbit depends on and gives engine-specific command patterns.

## Contents

1. Shared executor requirements
2. Quick reference
3. Codex
4. Gemini
5. Claude Code
6. Engine selection
7. Custom executor
8. Troubleshooting

## Shared Executor Requirements

Orbit runs `EXEC_CMD` through `portable_timeout`:

```bash
portable_timeout "${EFFECTIVE_TIMEOUT}" ${EXEC_CMD} 2>&1 | tee -a "${LOOP_DIR}/runner.log"
```

Because `EXEC_CMD` is shell-expanded without quoting, the whole command string must already include the binary, flags, and prompt.

Any executor must provide:

| Requirement | Why |
|-------------|-----|
| non-interactive mode | Orbit has no TTY |
| auto-approval or no prompts | loops cannot answer confirmations |
| CWD-based operation | runner changes into project root first |
| standard exit codes | `0` success, non-zero failure |
| stdout/stderr output | runner logs through `tee` |
| SIGTERM handling | `portable_timeout` terminates hung runs |

Recommended prompt pattern:

```bash
EXEC_CMD='codex exec --full-auto "Read goal.md and complete the task described in it"'
```

## Engine Quick Reference

| Engine | Base command | Non-interactive flag | Auto-approve flag | Model flag |
|--------|--------------|----------------------|-------------------|------------|
| Codex | `codex exec` | default | `--full-auto` | `-m <model>` |
| Gemini | `gemini` | `-p "prompt"` | `--yolo` | `-m <model>` |
| Claude Code | `claude` | `-p "prompt"` | `--dangerously-skip-permissions` or `--permission-mode bypassPermissions` | `--model <model>` |

## Codex

### Recommended command

```bash
EXEC_CMD='codex exec --full-auto "Read goal.md and complete the task described in it"'
```

### Key flags

| Flag | Required | Meaning |
|------|----------|---------|
| `--full-auto` | Yes | skip confirmations |
| `-m <model>` | No | choose model |
| `-s <sandbox>` | No | sandbox mode |
| `-C <dir>` | No | override working directory |

Typical models:
- `o4-mini` for Light or Standard loops
- `o3` for Heavy or Marathon loops

## Gemini

### Recommended command

```bash
EXEC_CMD='gemini -p "Read goal.md and complete the task described in it" --yolo'
```

### Key flags

| Flag | Required | Meaning |
|------|----------|---------|
| `-p "prompt"` | Yes | pass prompt non-interactively |
| `--yolo` | Yes | auto-approve actions |
| `--sandbox` | No | sandbox mode |
| `-m <model>` | No | choose model |
| `--approval-mode <mode>` | No | finer approval control |

## Claude Code

### Recommended commands

Full autonomy:

```bash
EXEC_CMD='claude -p "Read goal.md and complete the task described in it" --dangerously-skip-permissions'
```

Restricted tools:

```bash
EXEC_CMD='claude -p "Read goal.md and complete the task described in it" --permission-mode bypassPermissions --allowedTools "Read,Write,Edit,Bash,Glob,Grep"'
```

Budget-constrained:

```bash
EXEC_CMD='claude -p "Read goal.md and complete the task described in it" --dangerously-skip-permissions --max-budget-usd 5.00'
```

### Key flags

| Flag | Required | Meaning |
|------|----------|---------|
| `-p "prompt"` | Yes | non-interactive prompt |
| `--dangerously-skip-permissions` | one of the two | simplest autonomy mode |
| `--permission-mode <mode>` | alternative | use `bypassPermissions` for non-interactive loops |
| `--allowedTools "Tool1,Tool2"` | No | restrict tools |
| `--model <model>` | No | choose model |
| `--max-budget-usd <amount>` | No | cost cap |

## Engine Selection Guide

### Characteristics

| Aspect | Codex | Gemini | Claude Code |
|--------|-------|--------|-------------|
| strength | code generation and refactoring | broad general execution | agentic execution and tool use |
| speed | fast | moderate | moderate |
| cost | low to medium | low to medium | medium to high |
| autonomy | high | high | high |
| special control | sandbox | approval mode | fine-grained tool and budget control |

### Recommended Pairing

| Loop tier | Recommended engine | Rationale |
|-----------|--------------------|-----------|
| Light | Codex `o4-mini` | fastest turnaround |
| Standard | Codex or Claude | balanced speed and capability |
| Heavy | Claude or Codex `o3` | stronger reasoning for complex tasks |
| Marathon | Claude with budget control | predictable long-run cost |

## Custom Executor

Any custom executor is acceptable if it:
- accepts the prompt as part of the command string
- writes to stdout/stderr
- returns standard exit codes
- handles SIGTERM
- runs without prompts

Example wrapper:

```bash
EXEC_CMD='/path/to/my-executor.sh "Read goal.md and complete the task"'
```

```bash
#!/usr/bin/env bash
set -euo pipefail
my-ai-tool --no-interactive --prompt "$1"
```

## Common Troubleshooting

| Problem | Cause | Fix |
|---------|-------|-----|
| timeout kills useful work | `EXEC_TIMEOUT` too short | increase timeout or enable `ADAPTIVE_TIMEOUT=true` |
| malformed prompt | quoting problem in `EXEC_CMD` | use single quotes outside, double quotes inside |
| API key error | key not exported into loop shell | export the key in the same shell or source an env file |
| success treated as failure | non-standard exit codes | normalize through a wrapper script |
