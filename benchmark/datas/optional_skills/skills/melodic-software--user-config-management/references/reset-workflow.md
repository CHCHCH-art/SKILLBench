# Reset Workflow (MCP Preservation)

This guide covers resetting Claude Code to a fresh state while preserving your MCP server configurations.

## Table of Contents

- [Overview](#overview)
- [When to Use](#when-to-use)
- [Workflow Steps](#workflow-steps)
- [Command Reference](#command-reference)
- [Manual Reset](#manual-reset)
- [Troubleshooting](#troubleshooting)

## Overview

Sometimes you need a fresh Claude Code installation but don't want to lose your carefully configured MCP servers. The reset workflow:

1. **Backs up** your MCP server configurations
2. **Guides** you through the wipe process
3. **Restores** MCP servers after fresh install

**Backup Location:** `~/.claude-backups/`

## When to Use

Use the reset workflow when:

- Claude Code is behaving unexpectedly
- You want to clear all session history
- Configuration has become corrupted
- You're troubleshooting persistent issues
- You want a completely fresh start

**Do NOT use if:**

- You just want to clean up storage (use `/user-config prune` instead)
- You only need to clear sessions (use `/user-config cleanup-sessions` instead)

## Workflow Steps

### Step 1: Backup (Automatic)

The `/user-config reset` command automatically backs up:

```text
Backing up configuration...

Extracting mcpServers from ~/.claude.json
  -> ~/.claude-backups/mcp-servers-2025-12-30-143022.json

Copying settings.json (optional)
  -> ~/.claude-backups/settings-2025-12-30-143022.json

Backup complete!
```

**What gets backed up:**

| File | Content | Destination |
| --- | --- | --- |
| ~/.claude.json | mcpServers section only | mcp-servers-{timestamp}.json |
| ~/.claude/settings.json | Full file | settings-{timestamp}.json |
| ~/.claude/history.jsonl | Optional | history-{timestamp}.jsonl |

**What is NOT backed up (security):**

- `.credentials.json` - Contains OAuth tokens
- Plugin cache - Reinstall plugins instead

### Step 2: Confirmation

Before wiping, you'll see exactly what will be deleted:

```text
The following will be DELETED:
  - ~/.claude/ (entire directory)
  - ~/.claude.json

This will remove:
  - All session history
  - All agent transcripts
  - Debug logs
  - Todo states
  - Plugin cache
  - Settings (backed up)
  - MCP servers (backed up)

Your backups are safe at: ~/.claude-backups/

Proceed with reset? [Yes/No]
```

### Step 3: Wipe

If confirmed, the following are deleted:

```bash
rm -rf ~/.claude/
rm ~/.claude.json
```

**After wipe, you must:**

1. Close Claude Code completely
2. Relaunch Claude Code
3. Claude Code will create fresh configuration files

### Step 4: Restore

After relaunching Claude Code with fresh config, run:

```text
/user-config reset --restore
```

This will:

1. Find the most recent backup in ~/.claude-backups/
2. Read the fresh ~/.claude.json
3. Inject the backed-up mcpServers
4. Optionally restore settings.json

```text
Restoring from backup: ~/.claude-backups/mcp-servers-2025-12-30-143022.json

Found 3 MCP servers to restore:
  - context7
  - perplexity
  - microsoft-learn

Injecting into ~/.claude.json...

Restore complete! MCP servers preserved:
  - context7 (npx -y @anthropics/context7-mcp)
  - perplexity (node server.js)
  - microsoft-learn (npx @anthropics/microsoft-learn-mcp)
```

## Command Reference

### Full Reset (Interactive)

```bash
/user-config reset
```

Interactive wizard that:

1. Creates backup
2. Shows what will be deleted
3. Asks for confirmation
4. Provides restore instructions

### Backup Only

```bash
/user-config reset --backup
```

Only creates backup, does not wipe.

### Restore Only

```bash
/user-config reset --restore
```

Restores from most recent backup.

### Restore from Specific Backup

```bash
/user-config reset --restore 2025-12-30-143022
```

Restores from specific timestamped backup.

### List Backups

```bash
/user-config reset --list
```

Shows available backups.

## Manual Reset

If you prefer to reset manually:

### 1. Extract MCP Servers

```bash
# View current MCP servers
cat ~/.claude.json | jq '.mcpServers'

# Save to backup file
cat ~/.claude.json | jq '.mcpServers' > ~/mcp-backup.json
```

### 2. Wipe Configuration

```bash
rm -rf ~/.claude/
rm ~/.claude.json
```

### 3. Relaunch Claude Code

Close and reopen Claude Code. It will create fresh config files.

### 4. Restore MCP Servers

```bash
# Read fresh config
FRESH_CONFIG=$(cat ~/.claude.json)

# Read backed up servers
MCP_SERVERS=$(cat ~/mcp-backup.json)

# Merge (requires jq)
echo "$FRESH_CONFIG" | jq --argjson mcp "$MCP_SERVERS" '.mcpServers = $mcp' > ~/.claude.json
```

## MCP Server Backup Format

The backup file contains the mcpServers section in JSON:

```json
{
  "context7": {
    "command": "npx",
    "args": ["-y", "@anthropics/context7-mcp"]
  },
  "perplexity": {
    "command": "node",
    "args": ["C:/Users/user/mcp-servers/perplexity/server.js"],
    "env": {
      "PERPLEXITY_API_KEY": "${PERPLEXITY_API_KEY}"
    }
  },
  "microsoft-learn": {
    "command": "npx",
    "args": ["@anthropics/microsoft-learn-mcp"]
  }
}
```

## Troubleshooting

### Restore Says "No Backups Found"

Check that backups exist:

```bash
ls -la ~/.claude-backups/
```

If empty, you may need to use manual restoration from any copies you have.

### MCP Servers Not Working After Restore

1. Verify the restore completed:

   ```bash
   cat ~/.claude.json | jq '.mcpServers'
   ```

2. Restart Claude Code completely
3. Check MCP server status in Claude Code

### Fresh Config Not Created

If ~/.claude.json doesn't exist after relaunch:

1. Ensure Claude Code fully closed (check task manager)
2. Launch Claude Code
3. Wait for initial setup to complete

### Backup Location Changed

Default: `~/.claude-backups/`

To use a different location:

```bash
/user-config reset --backup-dir /path/to/backups
```

## Related Commands

- `/user-config backup` - Full backup (not just MCP)
- `/user-config restore` - Full restore
- `/user-config mcp` - View/export MCP configs without reset
