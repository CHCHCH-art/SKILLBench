# Lesson Entry Schema v2

This document defines the v2 markdown entry format for `LESSONS.md`.
It extends the existing Sailboat+Forward body by inserting three header lines between the `##` heading and the body fields.

## Canonical v2 Entry

```markdown
## YYYY-MM-DD HH:MM | tag1 tag2
> Trigger: <when this lesson applies — situation, operation, or context>
> Action: <what to do differently — concrete behavior>
> Scope: <operation-type, file-path-glob, or general>
**Wind 🌬️:** <what helped or worked well>
**Anchor ⚓:** <what went wrong or slowed progress>
**Rocks 🪨:** <risks or unknowns remaining>
**Next 🧭:** <one concrete action for next session>
```

Placement rule:
- The three new lines (`> Trigger:`, `> Action:`, `> Scope:`) MUST appear directly after the `##` heading and before `**Wind 🌬️:**`.

## SYNTHESIZED v2 Entry Variant

SYNTHESIZED entries use the same three header lines, but the body is freeform synthesis text instead of Sailboat fields.

```markdown
## SYNTHESIZED — <title> | tag1 tag2
> Trigger: <when this applies>
> Action: <behavioral instruction>
> Scope: <scope>
<synthesis text>
```

## Tag Normalization Rules

- Tags MUST be lowercase.
- Multiword tags MUST be hyphenated (example: `error-handling`).
- Aliases are not allowed; each concept uses one canonical tag form.
- If an entry has no explicit tags, the parser assigns `[untagged]`.

## Scope Field Conventions

Allowed `> Scope:` values:
- Operation types: `git-push`, `git-rebase`, `git-commit`, `git-merge`, `file-deletion`, `deployment`, `secrets-handling`
- File path globs: examples include `src/auth/**`, `*.sh`, `skills/retro/**`
- `general` for broad lessons not tied to a specific operation or path

## Entry Counter Contract

`LESSONS.md` MUST retain the counter comment:

```markdown
<!-- retro:entries:N -->
```

Counter rules:
- `N` is the number of raw entries currently represented in the file.
- This counter is used by compaction logic to detect when the file reaches 20+ entries.
- The comment MUST survive all schema revisions and formatting changes.

## Validation Rules

### Well-formed Entry

An entry is well-formed when all of the following are true:
- Heading matches one of:
  - `## YYYY-MM-DD HH:MM | <tags>`
  - `## SYNTHESIZED — <title> | <tags>`
- Heading is followed immediately by exactly three lines in this order:
  - `> Trigger: ...`
  - `> Action: ...`
  - `> Scope: ...`
- For standard entries, all four body fields are present in order:
  - `**Wind 🌬️:**`
  - `**Anchor ⚓:**`
  - `**Rocks 🪨:**`
  - `**Next 🧭:**`
- For SYNTHESIZED entries, at least one non-empty synthesis body line appears after `> Scope:`.

### Malformed or Invalid Entry

An entry is malformed or invalid when any of these conditions occur:
- Missing one or more required header lines.
- Header lines exist but are out of order.
- `> Trigger:`, `> Action:`, or `> Scope:` appears after `**Wind 🌬️:**`.
- Standard entry missing any Sailboat body field.
- SYNTHESIZED entry uses Sailboat body fields instead of synthesis text.
- Heading does not include a tag segment after `|` (parser should normalize to `[untagged]` only when the heading otherwise parses).

## Required Examples

### Example A: Standard v2 entry (all fields)

```markdown
## 2026-03-06 23:10 | tool-use git-hygiene
> Trigger: Before changing files in a shared repo worktree
> Action: Check branch and worktree context first, then edit
> Scope: git-commit
**Wind 🌬️:** Verifying branch before edits prevented accidental writes to main.
**Anchor ⚓:** I previously assumed branch context and lost time unwinding mistakes.
**Rocks 🪨:** In multi-worktree setups, stale assumptions can still leak across sessions.
**Next 🧭:** Run `git branch --show-current` at the start of every coding task.
```

### Example B: SYNTHESIZED v2 entry

```markdown
## SYNTHESIZED — Worktree safety and branch checks | git-hygiene planning
> Trigger: Starting autonomous implementation in repositories with multiple worktrees
> Action: Validate working directory and branch before any write operation
> Scope: general
Branch confusion is a repeated root cause for avoidable rework.
Explicit preflight checks reduce silent scope drift and keep file changes contained.
```

### Example C: Minimal valid entry (well-formed but sparse)

```markdown
## 2026-03-06 23:20 | [untagged]
> Trigger: Any task handoff
> Action: Record one concrete next move
> Scope: general
**Wind 🌬️:** Clear handoff note helped.
**Anchor ⚓:** None notable.
**Rocks 🪨:** Follow-up context can still decay.
**Next 🧭:** Start next session by reading the latest lesson.
```
