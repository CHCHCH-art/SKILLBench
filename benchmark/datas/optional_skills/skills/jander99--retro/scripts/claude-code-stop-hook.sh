#!/usr/bin/env bash
# ⚠️  SPECULATIVE IMPLEMENTATION
# This script was written based on available documentation and community examples.
# The hook API for this tool may have changed since this was written.
# Before using: verify hook configuration in your tool's official documentation.
# This script is provided as a starting point, not a production-ready solution.
# =============================================================================
# v2 TRIGGER: This hook fires at session END.
# RETRO WORKFLOW:
#   1. Call retro skill to run reflection
#   2. Retrieve lessons with: retro-lessons.sh inject ~/.agents/lessons/LESSONS.md
#      (inject relevant lessons into the NEXT session's context)
#   3. The retro skill writes v2 entries with Trigger/Action/Scope headers
# See: skills/retro/references/auto-trigger.md
# =============================================================================
# Claude Code "Stop" Hook — Auto-trigger retro when task list is done
#
# INSTALL (project-level):
#   1. Copy this file to: .claude/hooks/stop-retro-check.sh
#   2. chmod +x .claude/hooks/stop-retro-check.sh
#   3. In .claude/settings.json, add to hooks:
#
#      {
#        "hooks": {
#          "Stop": [
#            {
#              "matcher": "",
#              "hooks": [
#                {
#                  "type": "command",
#                  "command": ".claude/hooks/stop-retro-check.sh"
#                }
#              ]
#            }
#          ]
#        }
#      }
#
# HOW IT WORKS:
#   Claude Code fires the "Stop" hook every time Claude finishes responding.
#   This script checks whether a .retro-pending sentinel file exists.
#   The agent must create that sentinel when it marks all tasks complete.
#   When found:
#     - Removes the sentinel
#     - Exits with code 2 (blocks Claude from stopping; forces a continuation)
#     - Prints a prompt asking Claude to run the retro skill
#
#   Exit codes:
#     0 = allow Claude to stop (normal)
#     2 = block stop; Claude sees the printed message and continues
#
# SENTINEL-BASED APPROACH:
#   Because the "Stop" hook cannot introspect Claude's task list directly,
#   the agent itself is responsible for creating the sentinel file when it
#   writes the last "completed" task.  The AGENTS.md (or CLAUDE.md) instruction
#   (see retro-agents-md-snippet.md) tells the agent to do this.
#
#   Sentinel file path:  .claude/.retro-pending
#   The file may contain optional context (task count, session summary).
#
# =============================================================================

set -euo pipefail

SENTINEL=".claude/.retro-pending"

if [[ -f "$SENTINEL" ]]; then
  # Read optional context from sentinel (e.g. task summary written by agent)
  CONTEXT=""
  if [[ -s "$SENTINEL" ]]; then
    CONTEXT=$(cat "$SENTINEL")
  fi

  # Remove sentinel so we don't trigger again on the next Stop
  rm -f "$SENTINEL"

  # Exit code 2 causes Claude to continue rather than stop.
  # The text printed to stdout becomes Claude's next "user" prompt.
  if [[ -n "$CONTEXT" ]]; then
    echo "All tasks are complete ($CONTEXT). Please run the retro skill now: follow SKILL.md at skills/retro/SKILL.md, assess the session using the Sailboat+Forward rubric (Wind / Anchor / Rocks / Next), and write the entry to LESSONS.md. Then stop."
  else
    echo "All tasks are complete. Please run the retro skill now: follow SKILL.md at skills/retro/SKILL.md, assess the session using the Sailboat+Forward rubric (Wind / Anchor / Rocks / Next), and write the entry to LESSONS.md. Then stop."
  fi

  exit 2
fi

# No sentinel → nothing to do, let Claude stop normally
exit 0
