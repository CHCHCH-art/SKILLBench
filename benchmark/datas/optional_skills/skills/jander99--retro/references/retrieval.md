# Lesson Retrieval Protocol

Retrieval fetches relevant lessons from `LESSONS.md` before or during work, so accumulated knowledge actively shapes agent behavior rather than sitting idle in a log.

## When to Retrieve

There are two retrieval contexts:

### 1. Session-Start Retrieval

At the start of a new agent session, retrieve the 5 most recent general lessons to prime situational awareness.

**Trigger:** Session begins (tool loaded, task starts).

**Command:**

```bash
bash skills/retro/scripts/retro-lessons.sh retrieve --recent 5
```

**Purpose:** Surfaces institutional knowledge the agent might not have loaded otherwise. Equivalent to a pre-flight checklist read at the start of a flight.

### 2. Pre-Risk Retrieval

Before executing a high-risk operation, retrieve lessons specifically matching that operation type.

**Trigger:** Agent recognizes it is about to perform a high-risk operation (see taxonomy below).

**Command:**

```bash
bash skills/retro/scripts/retro-lessons.sh retrieve --operation <op-type>
```

**Purpose:** Targeted recall of hard-won lessons exactly when they are actionable. This is decision-time guidance — the closer retrieval is to the decision, the higher the application rate.

## High-Risk Operation Taxonomy

Retrieval MUST be triggered before any of the following:

| Operation Type        | Description                                     |
| --------------------- | ----------------------------------------------- |
| `git-push`            | Pushing commits to remote branch or fork        |
| `git-commit`          | Creating a commit                               |
| `git-rebase`          | Rebasing, squashing, or rewriting history       |
| `git-merge`           | Merging branches                                |
| `file-deletion`       | Deleting or overwriting files irreversibly      |
| `deployment`          | Deploying to staging or production environments |
| `secrets-handling`    | Reading, writing, or rotating credentials       |

Agents should also retrieve for any operation where a past Anchor in LESSONS.md suggests elevated risk.

## Retrieval Algorithm

The parser applies these rules in order:

1. **Tag match** (`--tag <tag>`): Return all entries whose heading tags contain the given tag (case-insensitive, normalized).
2. **Scope match** (`--operation <op>` or `--scope <scope>`): Return entries whose `> Scope:` line value contains the given string (case-insensitive substring match).
3. **Recency** (`--recent <N>`): Return the N most recent entries regardless of tag or scope.
4. **Combined**: Tag and scope filters can be combined; entries satisfying both are ranked first.

### Zero-Match Fallback

If no entries match the tag or scope query, the parser returns the 3 most recent entries with `scope: general`. This prevents silent empty results from leaving the agent contextless.

### Limits

- **Maximum per retrieval:** 5 entries.
- **Estimated token budget:** ~500 tokens (enforced by `inject` subcommand, not by `retrieve`).
- **Order:** Most recent first within each match tier.

### Staleness Handling

Entries classified as `irrelevant` in 3 or more audits are deprioritized: they appear only when no higher-ranked match exists. The parser does not delete them; compaction is responsible for removal. *(not yet implemented — planned for v2.1)*

See `references/compaction.md` for compaction policy.

## Retrieval in Practice

### Agent instruction form

> Before committing, retrieve lessons for `git-commit`:
>
> ```bash
> bash skills/retro/scripts/retro-lessons.sh retrieve --operation git-commit
> ```

### Script subcommand reference

```
retrieve --tag <tag>          [file]   # entries matching tag, newest first
retrieve --scope <scope>      [file]   # entries matching scope exactly/glob
retrieve --recent <N>         [file]   # N most recent entries
retrieve --operation <op>     [file]   # entries matching operation scope
retrieve --tag <tag> --recent <N>      # tag match, limited to N
```

Default file: `~/.agents/lessons/LESSONS.md`

## Retrieval Output Format

`retrieve` returns entries separated by `---`, each showing the heading and Trigger/Action/Scope lines:

```
## 2026-03-06 12:00 | git-hygiene
> Trigger: Before force-pushing to shared branches
> Action: Verify no upstream consumers exist first
> Scope: git-push
---
## 2026-03-05 09:30 | git-hygiene tool-use
> Trigger: Starting work in a multi-worktree repository
> Action: Run git worktree list and confirm current branch
> Scope: git-commit
```

Full Sailboat body is omitted by default. Pass `--full` to include it.

## Known Limitation

False-negative retrieval — a lesson that should have triggered but did not — is a known risk. It is addressed at retro time by the audit protocol's "did I miss a lesson?" self-check.

See `references/audit.md` for the audit protocol.
