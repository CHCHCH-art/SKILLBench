# Lesson Injection Protocol

Injection formats retrieved lessons into a compact, context-ready block and places it in agent context at the right moment. It is the bridge between retrieval and behavior change.

## Two-Layer Injection

### Layer 1: Session-Start Injection

At the start of a new agent session, inject a `## Relevant Lessons` block with the top-N general lessons.

**When:** After loading skills, before first user interaction.

**Source:** `retrieve --recent 5` (see `references/retrieval.md`).

**Purpose:** Primes the agent with recent institutional knowledge, equivalent to reading meeting notes before a standup.

**Format:**

```markdown
## Relevant Lessons

<!-- lessons-injected: git-hygiene tool-use 2026-03-06T09:00:00Z -->

- **[git-hygiene]**: Verify branch and worktree context before any write (Trigger: starting work in multi-worktree repo)
- **[tool-use]**: Read file before writing — never overwrite without seeing current contents (Trigger: any file modification)
- **[planning]**: Ask 1–2 clarifying questions before starting ambiguous tasks (Trigger: underspecified requirements)
```

### Layer 2: Pre-Risk Injection

Before a high-risk operation, inject targeted lessons matching the operation type.

**When:** After detecting high-risk operation intent, before executing the operation.

**Source:** `retrieve --operation <op-type>` (see `references/retrieval.md`).

**Purpose:** Decision-time guidance — surfacing lessons exactly when they are actionable.

**Format:**

```markdown
⚠️ Before proceeding, review these lessons:

<!-- lessons-injected: git-push 2026-03-06T14:23:00Z -->

- **[git-hygiene]**: Check for upstream consumers before pushing (Trigger: before force-pushing to shared branch)
- **[deployment]**: Confirm staging passed before pushing to main (Trigger: before any push to default branch)
```

## Injection Output Format

### Compact Bullet Format

Each lesson renders as one bullet:

```
- **[<tag>]**: <Action text> (Trigger: <trigger text>)
```

Rules:
- Tag: first tag from the entry heading, in bold, in brackets
- Action: the full `> Action:` line value
- Trigger: the full `> Trigger:` line value, in a parenthetical
- Scope is omitted from bullet text (already used for retrieval, not needed at inject time)

### Section Structure

Session-start injection:

```markdown
## Relevant Lessons

<!-- lessons-injected: tag1 tag2 TIMESTAMP -->

- **[tag]**: Action (Trigger: trigger)
...
```

Pre-risk injection:

```markdown
⚠️ Before proceeding, review these lessons:

<!-- lessons-injected: op-type TIMESTAMP -->

- **[tag]**: Action (Trigger: trigger)
...
```

### Audit Trail Comment

Every injection block MUST include:

```html
<!-- lessons-injected: tag1 tag2 ISO8601_TIMESTAMP -->
```

- Tags: space-separated list of tags or operation type that triggered this injection
- Timestamp: ISO 8601 UTC format (e.g., `2026-03-06T14:23:00Z`)
- This comment is read by the audit protocol to identify which lessons were active in a session

See `references/audit.md` for how audit reads these markers.

## Token Budget

| Constraint           | Value                                          |
| -------------------- | ---------------------------------------------- |
| Maximum entries      | 5 per injection block                          |
| Hard token budget    | 500 tokens (estimated as word count × 1.3)     |
| Per-entry truncation | Action and Trigger text truncated at ~80 chars |
| Truncation order     | Oldest entries trimmed first                   |

When context window is near-full, agents MAY skip injection entirely (edge case: context overflow). In that case, add a note: `<!-- lessons-injection-skipped: context-full -->`.

## Generating Injection Output

Use the `inject` subcommand:

```bash
bash skills/retro/scripts/retro-lessons.sh inject [--budget <tokens>] [file]
```

This formats up to 5 recent entries from LESSONS.md directly into a ready-to-paste block.

For targeted pre-risk injection, retrieve first then format manually, or use:

```bash
bash skills/retro/scripts/retro-lessons.sh retrieve --operation git-push | \
  bash skills/retro/scripts/retro-lessons.sh inject --tag git-push --budget 300 -
```

Default file: `~/.agents/lessons/LESSONS.md`

## Where Injection Fits in the Workflow

```
Session start
  └─ inject (Layer 1: session-start) ──→ [## Relevant Lessons block in context]

During work
  └─ detect high-risk intent
       └─ inject (Layer 2: pre-risk) ──→ [⚠️ Before proceeding block in context]

After work
  └─ write retro + audit injected lessons (see references/audit.md)
```

## Anti-Patterns

- **Do not inject the same lesson block twice** — check for existing `<!-- lessons-injected: ... -->` comment before injecting.
- **Do not inject when context is full** — skip and note with `lessons-injection-skipped`.
- **Do not expand the bullet format** — full Sailboat body at injection time bloats context. Agents can retrieve `--full` if they need more detail.
- **Do not include more than 5 entries** — beyond 5, marginal lessons add noise, not signal.
