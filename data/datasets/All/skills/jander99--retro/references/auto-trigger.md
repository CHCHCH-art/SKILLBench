# Auto-Retro Trigger — AGENTS.md / CLAUDE.md Snippet

Copy the relevant section below into your project's `AGENTS.md`, `CLAUDE.md`, or `.cursorrules`
file to activate the universal (prompt-instruction-based) retro auto-trigger.

This is the **fallback layer** — it works on every tool regardless of whether native hooks exist.
For tools with native hooks (OpenCode, Claude Code, Cline), use the hook scripts in `scripts/`
*in addition* to this snippet for belt-and-suspenders reliability.

---

## Section to add to AGENTS.md / CLAUDE.md / .cursorrules

```markdown
## Auto-Retro Rule

When ALL items in your task/todo list reach a terminal state (every item is either
"completed" or "cancelled", and at least one item is "completed"):

1. **Do not stop immediately.**
2. Run the `retro` skill: load `@skills/retro/SKILL.md` and follow its instructions.
3. Write the retrospective entry to the path resolved by the retro skill (`~/.agents/lessons/LESSONS.md` if `~/.agents/` exists, otherwise `LESSONS.md` in the project root).
4. Only stop after the retro entry has been written.

### For Claude Code only — sentinel file

When you mark the last task as "completed", also create the sentinel file:

    echo "tasks completed" > .claude/.retro-pending

This allows the Stop hook (`.claude/hooks/stop-retro-check.sh`) to re-trigger you
even if the context-window instruction is missed during long sessions.

### Retro Rubric (quick reference)

Use the Sailboat+Forward schema:
- **Wind 🌬️**: What helped or worked well?
- **Anchor ⚓**: What went wrong or slowed progress?
- **Rocks 🪨**: What risks or unknowns remain?
- **Next 🧭**: One concrete action for the next session

Append the entry to the resolved `LESSONS.md` path (see path detection above) with format:

    ## YYYY-MM-DD HH:MM | <tag1> [<tag2>]
    **Wind 🌬️:** ...
    **Anchor ⚓:** ...
    **Rocks 🪨:** ...
    **Next 🧭:** ...
```

---

## Setup Check (Skill Self-Verification)

When invoked via `/retro setup` or when auto-triggered for the first time in a project:

1. **Locate config file**: Check for `AGENTS.md`, `CLAUDE.md`, or `.cursorrules` in the **project root** only. Do not check or modify global config files.
2. **Search for trigger blurb**: `grep -Ei "retro|retrospective" <found-config-file>`
3. **If NOT found**: Display the snippet below and ask: _"I notice this project doesn't have the retro auto-trigger in AGENTS.md. Would you like me to add it?"_
4. **If confirmed**: Append the snippet from the "AGENTS.md/CLAUDE.md Snippet" section to the appropriate project-root file. If neither `AGENTS.md` nor `CLAUDE.md` exists, create `AGENTS.md` at the project root (see [references/promotion.md](promotion.md) Target File Priority).
5. **If declined**: Note the preference and skip auto-trigger checks in future sessions.

> This check runs once per project. After confirming (or declining), the skill will not ask again.

---

## Claude Code settings.json template

Add to `.claude/settings.json` to activate the Stop hook:

```json
{
  "hooks": {
    "Stop": [
      {
        "matcher": "",
        "hooks": [
          {
            "type": "command",
            "command": ".claude/hooks/stop-retro-check.sh"
          }
        ]
      }
    ]
  }
}
```

---

## Cline hooks directory layout

```
.clinerules/
└── hooks/
    └── TaskComplete          ← copy scripts/cline-task-complete-hook.sh here
```

Or globally:

```
~/Documents/Cline/Hooks/
└── TaskComplete              ← copy scripts/cline-task-complete-hook.sh here
```

---

## OpenCode plugin config

In your `opencode.config.ts`:

```typescript
import { defineConfig } from "@opencode-ai/opencode";
import retroAutoTrigger from "./skills/retro/scripts/opencode-plugin-hook";

export default defineConfig({
  plugins: [retroAutoTrigger()],
});
```

---

## Tool Coverage Summary

| Tool      | Trigger Mechanism                   | Reliability | Setup Required |
|-----------|-------------------------------------|-------------|----------------|
| OpenCode  | `tool.execute.after` plugin hook    | ⭐⭐⭐⭐⭐ High  | `opencode.config.ts` |
| Claude Code | `Stop` hook + sentinel file       | ⭐⭐⭐⭐ Good  | `settings.json` + hook script |
| Cline     | `TaskComplete` hook                 | ⭐⭐⭐⭐⭐ High  | Hook script in `.clinerules/hooks/` |
| Cursor    | AGENTS.md prompt instruction only   | ⭐⭐⭐ Medium  | Add snippet to `.cursorrules` |
| Any tool  | AGENTS.md / CLAUDE.md instruction  | ⭐⭐⭐ Medium  | Add snippet to AGENTS.md |

**Two-layer approach (recommended):** Use the native hook for your tool *plus* the
AGENTS.md snippet. The hook catches the trigger even when context is long and the
LLM has "forgotten" the instruction.
