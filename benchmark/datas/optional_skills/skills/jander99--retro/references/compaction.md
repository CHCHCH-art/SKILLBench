# Compaction Pipeline

Triggered when `LESSONS.md` has more than 20 entries (`<!-- retro:entries:N -->` where N > 20).

## When to Compact

- Automatically: after writing any entry that pushes the count past 20
- Manually: user says "compact lessons", "synthesize lessons", "clean up LESSONS.md"

## Algorithm

### Phase 0: Archive Before Compacting

**Always back up before any destructive operation.**

1. Check/create `.retro/` directory: `mkdir -p .retro`
2. Copy current LESSONS.md to timestamped backup:
   - Filename: `.retro/pre-compact-YYYY-MM-DD.md` (use today's date)
   - This is a full copy of LESSONS.md before synthesis overwrites it
3. Only proceed to Phase 1 after backup is confirmed to exist

If `.retro/` directory is not accessible (e.g., non-filesystem environment), log a warning in the final LESSONS.md entry header and proceed.

### Phase 1: Read All Entries

Read the full `LESSONS.md`. Extract all entries as structured data:
- Date/time
- Tags
- Trigger / Action / Scope header lines (v2 schema)
- Wind / Anchor / Rocks / Next content
- Audit section if present (`> Audit:` lines)

### Phase 2: Pattern Detection

For each of the four fields (Wind, Anchor, Rocks, Next), cluster entries by theme.

Clustering heuristic — group entries that share:
- The same root cause (e.g., "assumed path", "wrong branch", "missing clarification")
- The same tag and similar problem description
- Similar "Next" actions pointing at the same fix

**Promotion threshold:** 3 or more entries with the same root cause → promote to durable rule.

**Staleness scoring (v2):** Count the number of times each entry has been classified `Irrelevant` across all audits in the file. Entries with 3 or more `Irrelevant` audit records are stale candidates — deprioritize or remove them during synthesis rather than propagating them to the SYNTHESIZED entry.

### Phase 3: Write Synthesized LESSONS.md

Replace the detailed entries with a synthesized summary section + keep only the most recent 5 raw entries (for recency context).

When writing the SYNTHESIZED entry for a pattern cluster, carry forward the **most specific** Trigger/Action/Scope from the contributing entries. If contributing entries have conflicting Scope values, use the broader scope or `general`.

When merging audit histories: a pattern that was Applied in 3+ source entries is a strong promotion candidate; a pattern that was Irrelevant in 3+ source entries should be omitted from the SYNTHESIZED entry.

```markdown
# Lessons Learned

> Compacted on YYYY-MM-DD. Raw entries before this date synthesized into patterns below.
> Last 5 entries preserved verbatim for recency context.

<!-- retro:entries:5 -->

## Synthesized Patterns

## SYNTHESIZED — Branch verification before writes | git-hygiene planning
> Trigger: Starting autonomous implementation in any repository
> Action: Run git branch --show-current and confirm working directory before any file edit
> Scope: git-commit
Branch confusion is a repeated root cause for avoidable rework across 4 sessions.
Explicit preflight checks reduce silent scope drift and keep file changes contained.

## SYNTHESIZED — Read before write | tool-use
> Trigger: Any operation that modifies an existing file
> Action: Read the file fully before writing or appending — never overwrite blindly
> Scope: file-deletion
Observed 3 times: blind overwrites caused data loss and required manual recovery.

---

## Recent Entries (last 5)

[... last 5 raw entries preserved verbatim ...]
```

### Phase 4: Promote to AGENTS.md / CLAUDE.md

For each pattern that crossed the 3× threshold:

1. Check if `~/.agents/AGENTS.md` exists (universal, preferred); fall back to `~/.config/opencode/AGENTS.md` (OpenCode global), then project `AGENTS.md`, then `CLAUDE.md`; if none, run `mkdir -p ~/.agents` and create `~/.agents/AGENTS.md`
2. Find or create a `## Learned Rules` section
3. Append the promoted rule as a bullet under the relevant heading

Example promotion:

```markdown
## Learned Rules

> Promoted from LESSONS.md by the `retro` skill. Do not edit manually.

### Planning
- Always verify branch with `git branch --show-current` before any file modifications.
- Ask 1–2 clarifying questions before starting any ambiguous task.

### Tool Use
- Locate `package.json` and project root with glob/ls before assuming directory structure.
```

## Anti-Patterns to Avoid

- **Do not** promote overly specific rules ("always make buttons pink") — only abstract, reusable patterns
- **Do not** fabricate patterns — only promote what genuinely appeared 3+ times
- **Do not** delete the `## Learned Rules` section on subsequent compactions — append only
- **Do not** compact if the file has fewer than 20 entries — premature compaction loses signal
