# Pattern Promotion to AGENTS.md / CLAUDE.md

Promotion elevates a recurring lesson from a volatile log entry into a durable, always-active rule.

## When to Promote

A pattern is ready to promote when it appears in **3 or more** LESSONS.md entries with the same
root cause — regardless of how similar the surface-level task was.

### Audit-Informed Promotion (v2)

Audit classifications from `references/audit.md` provide an additional signal:

- **Applied 3+ times across distinct sessions** → strong promotion candidate. The lesson demonstrably changed behavior; it belongs in AGENTS.md as a standing rule.
- **Violated 1+ times** → promote with **high urgency**. A lesson that is being ignored despite injection is a systemic failure point. Promote it to AGENTS.md immediately so it fires even without lesson retrieval.
- **Irrelevant 3+ times** → do NOT promote. Staleness is a signal the trigger is too narrow or the situation is rare. Remove from promotion pipeline.

Same-session duplicates still do not count: Applied occurrences must span at least 2 distinct retro sessions.

Examples of promotable patterns:
- 3 entries all have Anchor mentioning "forgot to check current branch" → promotable
- 4 entries have Wind mentioning "reading file before writing prevented data loss" → promotable
- 2 entries mention the same thing → NOT yet promotable (wait for a third)
- **Same-session duplicates do not count**: Multiple entries written in the same session about the same issue count as 1 occurrence. Occurrences must span at least 2 distinct retro sessions.

## What NOT to Promote

Avoid promoting:
- **Task-specific rules**: "Always use Tailwind for this project's buttons" — too narrow
- **coincidental patterns**: Two similar entries in the same session (one task, not a real pattern)
- **Negative rules that are already obvious**: "Don't delete production databases" — not useful
- **Preferences masquerading as patterns**: stylistic choices that aren't errors

The litmus test: *Would this rule have prevented an Anchor event in 3+ different tasks?*
If yes → promote. If unsure → wait for another occurrence.

For Violated lessons: *Did this lesson fail to prevent the exact Anchor it warned about?*
If yes → promote immediately, regardless of Applied count.

## Promotion Format

### Target File Priority

1. `~/.agents/AGENTS.md` (universal, preferred — cross-tool global rules)
2. `~/.config/opencode/AGENTS.md` (OpenCode global)
3. `AGENTS.md` in project root (project-level)
4. `CLAUDE.md` (Claude Code)
    5. Run `mkdir -p ~/.agents` and create `~/.agents/AGENTS.md` if none exists

### Section Structure

Find or create a `## Learned Rules` section. Group rules by tag category:

```markdown
## Learned Rules

> Auto-promoted from LESSONS.md by the `retro` skill on YYYY-MM-DD.
> These rules are active in every session. To remove a rule, delete its bullet.

### Planning
- Always verify the current branch with `git branch --show-current` before any file modification.
- Ask 1–2 clarifying questions before starting any task where the scope is ambiguous.

### Tool Use
- Run `ls` or `glob` to confirm directory structure before assuming file locations.
- Read a file before writing to it — never overwrite without understanding current contents.

### Error Handling
- On first file read failure, check both the path and the working directory before retrying.
```

### Appending Rules

When adding a new promoted rule:

**Step 0 — Dedup check (do this first):**
Take the most distinctive 5–10 word phrase from your new rule.
`grep` (case-insensitive) for that phrase in the target file (AGENTS.md or CLAUDE.md).
- If a ≥80% semantic match is found: **skip the append**. Instead, add a note to the current LESSONS.md entry: `<!-- Rule already promoted on YYYY-MM-DD — skipped dedup -->`
- If no match: proceed to step 1 below.

1. Locate the existing `## Learned Rules` section
2. Find the matching tag subsection (or create it)
3. Append the new bullet — do NOT remove existing bullets
4. Add a comment noting the promotion date: `<!-- promoted: YYYY-MM-DD -->`

## Demotion (Removing a Promoted Rule)

If a promoted rule turns out to be wrong or too aggressive:
1. Delete the specific bullet from `AGENTS.md` / `CLAUDE.md`
2. Add an Anchor entry in `LESSONS.md` noting: "Promoted rule `[X]` was over-broad; removed."

This creates a meta-lesson: what kinds of patterns should NOT be promoted.
