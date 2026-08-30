# Backup and Restore Procedures

This guide covers full backup and restore of Claude Code user configuration.

## Table of Contents

- [Overview](#overview)
- [Backup Location](#backup-location)
- [What Gets Backed Up](#what-gets-backed-up)
- [Backup Command](#backup-command)
- [Restore Command](#restore-command)
- [Manual Backup](#manual-backup)
- [Backup Rotation](#backup-rotation)

## Overview

Full configuration backup preserves your Claude Code setup for:

- Migration to a new machine
- Recovery from corruption
- Sharing configuration (minus secrets)

**Backup Location:** `~/.claude-backups/backup-YYYY-MM-DD-HHmmss/`

## Backup Location

All backups are stored in `~/.claude-backups/` (sibling to `.claude/`).

**Why this location?**

- Won't be affected by cleanup operations
- Easy to find and manage
- Clear separation from active config
- Not inside `.claude/` (won't grow that directory)

**Directory structure:**

```text
~/.claude-backups/
  backup-2025-12-30-143022/
    mcp-servers.json       # ~/.claude.json mcpServers section
    settings.json          # ~/.claude/settings.json
    settings.local.json    # ~/.claude/settings.local.json (if exists)
    history.jsonl          # ~/.claude/history.jsonl (optional)
    user-claude.md         # ~/CLAUDE.md (if exists)
    user-claudeignore      # ~/.claudeignore (if exists)
    manifest.json          # Backup metadata
  backup-2025-12-29-091500/
    ...
```

## What Gets Backed Up

### Always Backed Up

| File | Source | Why |
| --- | --- | --- |
| mcp-servers.json | ~/.claude.json mcpServers | Critical - preserves MCP config |
| settings.json | ~/.claude/settings.json | User preferences and permissions |

### Optionally Backed Up

| File | Source | Flag | Why |
| --- | --- | --- | --- |
| settings.local.json | ~/.claude/settings.local.json | --include-local | Machine-specific settings |
| history.jsonl | ~/.claude/history.jsonl | --include-history | Command history |
| user-claude.md | ~/CLAUDE.md | --include-memory | User instructions |
| user-claudeignore | ~/.claudeignore | --include-ignore | Ignore patterns |

### Never Backed Up

| File | Why |
| --- | --- |
| .credentials.json | Contains OAuth tokens - security risk |
| plugins/ | Reinstall instead - cache can be large |
| projects/ | Session data - too large, not portable |
| debug/ | Debug logs - temporary data |

## Backup Command

### Full Backup

```bash
/user-config backup
```

Creates backup with default options (settings + MCP servers).

### Include Optional Files

```bash
/user-config backup --include-history --include-memory
```

Includes command history and CLAUDE.md.

### All Files

```bash
/user-config backup --all
```

Includes all optional files.

### Custom Location

```bash
/user-config backup --output ~/my-claude-backup/
```

### List Existing Backups

```bash
/user-config backup --list
```

Shows all backups with sizes and dates.

## Restore Command

### Restore Latest

```bash
/user-config restore
```

Restores from most recent backup.

### Restore Specific Backup

```bash
/user-config restore 2025-12-30-143022
```

Restores from specific timestamped backup.

### Preview Restore

```bash
/user-config restore --dry-run
```

Shows what would be restored without making changes.

### Selective Restore

```bash
/user-config restore --only mcp-servers
/user-config restore --only settings
/user-config restore --only history
```

Restores specific files only.

## Manual Backup

### Using Bash

```bash
# Create backup directory
BACKUP_DIR="$HOME/.claude-backups/backup-$(date +%Y-%m-%d-%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup MCP servers from .claude.json
if [ -f "$HOME/.claude.json" ]; then
  cat "$HOME/.claude.json" | jq '.mcpServers // {}' > "$BACKUP_DIR/mcp-servers.json"
fi

# Backup settings
if [ -f "$HOME/.claude/settings.json" ]; then
  cp "$HOME/.claude/settings.json" "$BACKUP_DIR/"
fi

# Backup optional files
[ -f "$HOME/.claude/settings.local.json" ] && cp "$HOME/.claude/settings.local.json" "$BACKUP_DIR/"
[ -f "$HOME/.claude/history.jsonl" ] && cp "$HOME/.claude/history.jsonl" "$BACKUP_DIR/"
[ -f "$HOME/CLAUDE.md" ] && cp "$HOME/CLAUDE.md" "$BACKUP_DIR/user-claude.md"
[ -f "$HOME/.claudeignore" ] && cp "$HOME/.claudeignore" "$BACKUP_DIR/user-claudeignore"

# Create manifest
cat > "$BACKUP_DIR/manifest.json" << EOF
{
  "created": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "claude_version": "unknown",
  "files": $(ls -1 "$BACKUP_DIR" | jq -R -s -c 'split("\n")[:-1]')
}
EOF

echo "Backup created at: $BACKUP_DIR"
```

### Using PowerShell

```powershell
# Create backup directory
$timestamp = Get-Date -Format "yyyy-MM-dd-HHmmss"
$backupDir = "$env:USERPROFILE\.claude-backups\backup-$timestamp"
New-Item -ItemType Directory -Path $backupDir -Force

# Backup MCP servers
$claudeJson = "$env:USERPROFILE\.claude.json"
if (Test-Path $claudeJson) {
    $config = Get-Content $claudeJson | ConvertFrom-Json
    $config.mcpServers | ConvertTo-Json -Depth 10 | Out-File "$backupDir\mcp-servers.json"
}

# Backup settings
$settingsJson = "$env:USERPROFILE\.claude\settings.json"
if (Test-Path $settingsJson) {
    Copy-Item $settingsJson "$backupDir\"
}

Write-Host "Backup created at: $backupDir"
```

## Manual Restore

### Restore MCP Servers

```bash
# Read backup
MCP_BACKUP=$(cat ~/.claude-backups/backup-2025-12-30-143022/mcp-servers.json)

# Read current config
CURRENT=$(cat ~/.claude.json)

# Merge MCP servers
echo "$CURRENT" | jq --argjson mcp "$MCP_BACKUP" '.mcpServers = $mcp' > ~/.claude.json
```

### Restore Settings

```bash
cp ~/.claude-backups/backup-2025-12-30-143022/settings.json ~/.claude/settings.json
```

## Backup Rotation

### Automatic Rotation

By default, backups older than 90 days are NOT automatically deleted.

To enable rotation:

```bash
/user-config backup --rotate 30  # Keep last 30 days
```

### Manual Cleanup

```bash
# List backups
ls -la ~/.claude-backups/

# Remove specific backup
rm -rf ~/.claude-backups/backup-2025-12-01-120000/

# Remove backups older than 30 days
find ~/.claude-backups/ -maxdepth 1 -type d -mtime +30 -exec rm -rf {} \;
```

## Backup Manifest Format

Each backup includes a `manifest.json`:

```json
{
  "created": "2025-12-30T14:30:22Z",
  "claude_version": "2.0.76",
  "hostname": "WORKSTATION",
  "platform": "win32",
  "files": [
    "mcp-servers.json",
    "settings.json",
    "manifest.json"
  ],
  "sizes": {
    "mcp-servers.json": 1234,
    "settings.json": 5678
  },
  "options": {
    "include_history": false,
    "include_memory": false,
    "include_local": false
  }
}
```

## Cross-Platform Considerations

### Windows

- Paths use `%USERPROFILE%` or `$env:USERPROFILE`
- Use PowerShell for native experience
- Git Bash works with Unix-style paths

### macOS/Linux

- Paths use `$HOME` or `~`
- Standard Bash commands work

### Path Examples

| Platform | Backup Location |
| --- | --- |
| Windows | `C:\Users\username\.claude-backups\` |
| macOS | `/Users/username/.claude-backups/` |
| Linux | `/home/username/.claude-backups/` |

## Related Commands

- `/user-config reset` - Reset with MCP preservation
- `/user-config mcp` - View/export MCP configs only
- `/user-config status` - Check current config status
