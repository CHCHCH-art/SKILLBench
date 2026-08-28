# Command Inventory

Complete reference for all user configuration management commands.

## Table of Contents

- [Namespace](#namespace)
- [Command Summary](#command-summary)
- [Cleanup Commands](#cleanup-commands)
- [Status Commands](#status-commands)
- [Backup Commands](#backup-commands)
- [Data Commands](#data-commands)
- [Deprecated Commands](#deprecated-commands)

## Namespace

All user configuration actions are consolidated under the `/user-config <action>` skill.

**Old commands still work** but display a deprecation notice pointing to the new command name.

## Command Summary

### Cleanup Commands (Migrated)

| Command | Purpose | Args | Default |
| --- | --- | --- | --- |
| `/user-config cleanup-sessions` | Session file cleanup | [days] [--dry-run] [--all-projects] | 7 days, current project |
| `/user-config cleanup-agents` | Agent transcript cleanup | [days] [--dry-run] [--all-projects] | 7 days, current project |
| `/user-config cleanup-debug` | Debug log cleanup | [days] [--dry-run] [--nuclear] | 7 days |
| `/user-config cleanup-hook-logs` | Hook log cleanup | [days] | 30 days |
| `/user-config prune` | Comprehensive cleanup | [days] [--dry-run] [--nuclear] [--all-projects] | 7 days |

### Status Commands (Migrated)

| Command | Purpose | Args |
| --- | --- | --- |
| `/user-config storage` | Storage analysis | [--verbose] |
| `/user-config session-stats` | Session statistics | none |

### New Commands

| Command | Purpose | Args | Priority |
| --- | --- | --- | --- |
| `/user-config status` | Unified overview | [--verbose] | P0 |
| `/user-config reset` | Reset with MCP preservation | [--backup] [--restore] [--list] | P0 |
| `/user-config audit` | Structure drift detection | [--fix] | P0 |
| `/user-config backup` | Full config backup | [--all] [--include-history] | P1 |
| `/user-config restore` | Restore from backup | [timestamp] [--dry-run] | P1 |
| `/user-config history` | Search/export history | [search] [--export] [--stats] | P1 |
| `/user-config plans` | Manage plan files | [--list] [--archive] [--cleanup] | P1 |
| `/user-config global` | Edit ~/.claude.json | [section] [--view] | P1 |
| `/user-config mcp` | Manage MCP servers | [--list] [--export] [--backup] | P1 |

## Cleanup Commands

### /user-config cleanup-sessions

Remove old session files from project cache.

```text
/user-config cleanup-sessions                    # Default: 7 days, current project
/user-config cleanup-sessions 14                 # 14 days
/user-config cleanup-sessions --dry-run          # Preview only
/user-config cleanup-sessions --all-projects     # All projects
```

**Targets:** `~/.claude/projects/*/*.jsonl` (excludes agent-*.jsonl)

### /user-config cleanup-agents

Remove old agent transcript files.

```text
/user-config cleanup-agents                      # Default: 7 days, current project
/user-config cleanup-agents 3                    # Aggressive: 3 days
/user-config cleanup-agents --dry-run            # Preview only
/user-config cleanup-agents --all-projects       # All projects
```

**Targets:** `~/.claude/projects/*/agent-*.jsonl`

### /user-config cleanup-debug

Remove old debug transcript files.

```text
/user-config cleanup-debug                       # Default: 7 days
/user-config cleanup-debug 14                    # 14 days
/user-config cleanup-debug --dry-run             # Preview only
/user-config cleanup-debug --nuclear             # All debug files
```

**Targets:** `~/.claude/debug/*`

### /user-config cleanup-hook-logs

Remove old hook execution logs.

```text
/user-config cleanup-hook-logs                   # Default: 30 days
/user-config cleanup-hook-logs 7                 # 7 days
```

**Targets:** Hook log files (location configurable via env var)

### /user-config prune

Comprehensive cleanup - the "nuclear option".

```text
/user-config prune                               # Default: 7 days
/user-config prune 3                             # Aggressive: 3 days
/user-config prune --dry-run                     # Preview only
/user-config prune --nuclear                     # 0 days, all flags, stale locks
/user-config prune --include-debug               # Also clean debug/
/user-config prune --include-todos               # Also clean todos/
/user-config prune --all-projects                # All projects
```

**What --nuclear does:**

- Sets days to 0 (all files regardless of age)
- Enables --include-debug
- Enables --include-todos
- Enables --all-projects
- Cleans stale lock files (`~/.local/state/claude/locks/`)

**Always cleaned:**

- Sessions and agents in projects/
- Statsig cache
- Shell snapshots
- Plans

**Never cleaned:**

- settings.json, CLAUDE.md, commands/, skills/, agents/, hooks/
- history.jsonl
- plugins/ (use /plugin uninstall)
- file-history/ (loses undo capability)

## Status Commands

### /user-config storage

Analyze storage usage with breakdown by category.

```text
/user-config storage                             # Summary
/user-config storage --verbose                   # Detailed file listings
```

**Output includes:**

- Total ~/.claude/ size
- Size by category (projects, debug, plugins, etc.)
- Top 5 projects by size
- Current project session analysis
- Large files (>10MB)
- Reclaimable space
- Recommendations

### /user-config session-stats

View session statistics and trends.

```text
/user-config session-stats
```

**Output includes:**

- Session counts by time period
- Average session size
- Growth rate
- Trends

### /user-config status (New)

Unified overview of all configuration status.

```text
/user-config status                              # Quick overview
/user-config status --verbose                    # Detailed
```

**Output includes:**

- Config file health (exists, valid JSON)
- Storage summary (delegates to /storage for details)
- MCP server count
- Recent activity
- Quick links to relevant commands

## Backup Commands

### /user-config backup

Full configuration backup.

```text
/user-config backup                              # Default backup
/user-config backup --all                        # Include all optional files
/user-config backup --include-history            # Include history.jsonl
/user-config backup --include-memory             # Include CLAUDE.md
/user-config backup --list                       # List existing backups
/user-config backup --rotate 30                  # Keep last 30 days
```

**Backup location:** `~/.claude-backups/backup-YYYY-MM-DD-HHmmss/`

### /user-config restore

Restore from backup.

```text
/user-config restore                             # Restore latest
/user-config restore 2025-12-30-143022           # Restore specific
/user-config restore --dry-run                   # Preview only
/user-config restore --only mcp-servers          # MCP servers only
/user-config restore --only settings             # Settings only
```

### /user-config reset

Reset with MCP server preservation.

```text
/user-config reset                               # Interactive wizard
/user-config reset --backup                      # Backup only
/user-config reset --restore                     # Restore only
/user-config reset --restore 2025-12-30-143022   # Restore specific
/user-config reset --list                        # List backups
```

**Workflow:**

1. Backup mcpServers and settings
2. Show what will be deleted
3. Confirm with user
4. User wipes and relaunches
5. User runs --restore to inject MCP servers

## Data Commands

### /user-config history

Search and export command history.

```text
/user-config history                             # Recent history
/user-config history search "commit"             # Search for keyword
/user-config history --export                    # Export to file
/user-config history --stats                     # Usage statistics
/user-config history --clear                     # Clear history (with confirm)
```

**Targets:** `~/.claude/history.jsonl`

### /user-config plans

Manage plan files.

```text
/user-config plans                               # List plans
/user-config plans --list                        # List with details
/user-config plans view <plan-name>              # View specific plan
/user-config plans --archive                     # Archive old plans
/user-config plans --cleanup 30                  # Remove plans >30 days
```

**Targets:** `~/.claude/plans/*.md`

### /user-config global

View and edit ~/.claude.json safely.

```text
/user-config global                              # View all
/user-config global --view mcpServers            # View section
/user-config global edit mcpServers              # Edit section (interactive)
/user-config global backup                       # Backup before editing
```

**Sections:** mcpServers, oauthAccount, statsigFeatureFlags, growthBookFeatureFlags

### /user-config mcp

Manage MCP server configurations.

```text
/user-config mcp                                 # List servers
/user-config mcp --list                          # Detailed list
/user-config mcp --export                        # Export to file
/user-config mcp --backup                        # Backup servers only
```

### /user-config audit

Audit configuration health and detect drift.

```text
/user-config audit                               # Full audit
/user-config audit --fix                         # Auto-fix issues
```

**Checks:**

- JSON validity
- Orphaned files
- Stale locks
- Unknown directories (drift detection)
- Security (no exposed keys)

## Deprecated Commands

Old command names still work but show deprecation notice:

| Old Command | New Command | Notice |
| --- | --- | --- |
| `/cleanup-sessions` | `/user-config cleanup-sessions` | "Deprecated: Use /user-config cleanup-sessions" |
| `/cleanup-agents` | `/user-config cleanup-agents` | "Deprecated: Use /user-config cleanup-agents" |
| `/cleanup-debug` | `/user-config cleanup-debug` | "Deprecated: Use /user-config cleanup-debug" |
| `/prune-cache` | `/user-config prune` | "Deprecated: Use /user-config prune" |
| `/cleanup-hook-logs` | `/user-config cleanup-hook-logs` | "Deprecated: Use /user-config cleanup-hook-logs" |
| `/check-claude-storage` | `/user-config storage` | "Deprecated: Use /user-config storage" |
| `/session-stats` | `/user-config session-stats` | "Deprecated: Use /user-config session-stats" |

**Deprecation wrappers will be removed after 1-2 releases.**
