#!/usr/bin/env bash
# ⚠️  SPECULATIVE IMPLEMENTATION
# This script was written based on available documentation and community examples.
# The hook API for this tool may have changed since this was written.
# Before using: verify hook configuration in your tool's official documentation.
# This script is provided as a starting point, not a production-ready solution.
# =============================================================================
# v2 TRIGGER: This hook fires when a Cline task COMPLETES.
# RETRO WORKFLOW:
#   1. Call retro skill to run reflection for the completed task
#   2. Audit previous lessons: check Applied/Violated/Irrelevant for each retrieved lesson
#   3. The retro skill writes v2 entries with Trigger/Action/Scope headers
# See: skills/retro/references/audit.md
# =============================================================================
# Cline "TaskComplete" Hook — Auto-trigger retro on task completion
#
# INSTALL (project-level):
#   1. Copy this file to: .clinerules/hooks/TaskComplete
#   2. chmod +x .clinerules/hooks/TaskComplete
#
# INSTALL (global):
#   1. Copy to: ~/Documents/Cline/Hooks/TaskComplete
#   2. chmod +x ~/Documents/Cline/Hooks/TaskComplete
#
# HOW IT WORKS:
#   Cline fires "TaskComplete" when a task finishes successfully.
#   This script receives the hook payload on stdin as JSON:
#
#     {
#       "taskId": "abc123",
#       "hookName": "TaskComplete",
#       "taskComplete": {
#         "task": "The original task description string"
#       }
#     }
#
#   It prints a JSON response instructing Cline to trigger a retro:
#
#     {
#       "cancel": false,
#       "contextModification": "<retro instructions>",
#       "errorMessage": ""
#     }
#
#   The "contextModification" string is injected into Cline's context,
#   which causes the agent to run the retro skill before fully stopping.
#
# DEPENDENCIES: jq (for JSON parsing; falls back gracefully if absent)
# =============================================================================

set -euo pipefail

# Read the full JSON payload from stdin
PAYLOAD=$(cat)

# Extract task description (used in the retro prompt) — requires jq
TASK_DESC=""
if command -v jq &>/dev/null; then
  TASK_DESC=$(echo "$PAYLOAD" | jq -r '.taskComplete.task // "unspecified task"' 2>/dev/null || echo "unspecified task")
fi

# Build the context modification message that will be injected into Cline
RETRO_PROMPT="Task complete: \"${TASK_DESC}\". Please now run the retro skill: load skills/retro/SKILL.md, assess the session using the Sailboat+Forward rubric (Wind / Anchor / Rocks / Next), and write the dated entry to LESSONS.md in the project root (create it if absent)."

# Output the Cline hook response JSON
# cancel: false     = do not cancel the task (it already completed)
# contextModification = text injected into agent context after completion
# errorMessage: ""  = no error
if command -v jq &>/dev/null; then
  jq -n --arg msg "$RETRO_PROMPT" '{"cancel":false,"contextModification":$msg,"errorMessage":""}'
else
  # Fallback: manual escaping (only handles quotes; jq preferred for full safety)
  printf '{"cancel":false,"contextModification":"%s","errorMessage":""}' \
    "$(echo "$RETRO_PROMPT" | sed 's/"/\\"/g')"
fi
