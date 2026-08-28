# Lesson Audit Protocol

The audit is the verify step of the learning loop: **reflect → store → retrieve → inject → verify**. It evaluates whether injected lessons actually changed agent behavior, closing the feedback loop that makes the system self-improving.

## When to Audit

Audit happens **during retrospective writing**, after the Sailboat rubric (Wind/Anchor/Rocks/Next) is complete. It is not a separate step — it is appended to every retro entry that had active injected lessons.

If no lessons were injected in the session, write: `> Audit: no lessons active this session.` and move on.

## Phase 1: Collect Active Lessons

Scan the session context (or recent output) for `<!-- lessons-injected: ... -->` markers left by the injection protocol.

```
<!-- lessons-injected: git-hygiene tool-use 2026-03-06T09:00:00Z -->
```

Each marker identifies which tags and timestamp were injected. Extract the list of injected lessons from LESSONS.md that match those tags and were written before the timestamp.

If markers are absent (e.g., context was compacted mid-session), list any lessons you recall being aware of during the session. Note: `> Audit: no injection markers found; best-effort recall used.`

## Phase 2: Classify Each Injected Lesson

For each lesson identified in Phase 1, assign exactly one classification:

| Classification | Meaning | Evidence Required |
| -------------- | ------- | ----------------- |
| **Applied**    | The lesson's Action was followed. The behavior it prescribes occurred. | Describe what you did that matches the Action. |
| **Violated**   | The lesson's Action was NOT followed, and the Anchor outcome it warns about occurred or could have occurred. | Describe what went wrong or nearly went wrong. |
| **Irrelevant** | The lesson's Trigger condition did not arise during this session. | State briefly why the trigger did not fire. |

### Classification Rules

- **Applied** requires positive evidence — "I did X because the lesson said to do X." If you cannot identify a moment where the lesson changed your behavior, default to **Irrelevant**.
- **Violated** requires the lesson's Trigger to have fired AND the Action to have been skipped. A lesson whose Trigger did not arise cannot be Violated.
- **Irrelevant** is the default classification when neither Applied nor Violated conditions are met.

## Phase 3: Write the Audit Section

Append an `> Audit:` block to the retro entry, after `**Next 🧭:**`, before the next `---` separator.

### Format

```markdown
> Audit:
> - [git-hygiene] Applied: verified branch with git branch --show-current before editing (lesson 2026-03-05)
> - [tool-use] Irrelevant: no file overwrite operations this session
> - [deployment] Violated: pushed to main without confirming staging passed (lesson 2026-03-01)
```

Rules:
- One line per injected lesson
- Format: `> - [<tag>] <Classification>: <brief evidence> (lesson <date>)`
- Date: the date from the lesson's heading (YYYY-MM-DD)
- Keep each line under 120 characters

### Full Entry Example (with audit appended)

```markdown
## 2026-03-06 22:00 | git-hygiene
> Trigger: After any session that involved git operations
> Action: Always confirm staging was clean before marking task done
> Scope: git-commit
**Wind 🌬️:** Caught a dirty working tree before committing.
**Anchor ⚓:** Forgot to run tests before push.
**Rocks 🪨:** CI might still have flaky tests.
**Next 🧭:** Add test step to pre-push checklist.
> Audit:
> - [git-hygiene] Applied: ran git status before every commit this session (lesson 2026-03-05)
> - [testing] Violated: skipped test run before push due to time pressure (lesson 2026-02-28)
```

## Phase 4: Act on Violations

When a lesson is classified **Violated**, generate a new LESSONS.md entry about the violation pattern.

Example: if `[testing] Violated: skipped test run before push` — write a new entry with:
- Tag: `testing` (and `self-discipline` if applicable)
- Trigger: the same or tighter trigger condition
- Action: a more specific or harder-to-bypass behavioral instruction
- Anchor: what actually happened as a result of the violation

This turns violations into higher-signal lessons, increasing their weight for future retrieval.

## Phase 5: The "Did I Miss a Lesson?" Self-Check

After writing the Anchor items in the Sailboat rubric, ask:

> *Is there a lesson in LESSONS.md that would have prevented this Anchor?*

Steps:
1. Run `bash skills/retro/scripts/retro-lessons.sh retrieve --recent 10` or search by relevant tag.
2. If a matching lesson exists that was NOT injected this session: note it as a retrieval gap.
3. Record the gap in the Audit section: `> - [<tag>] Gap: lesson exists (date) but was not injected — trigger condition was present.`

This addresses the known false-negative retrieval limitation and generates signal for improving retrieval query selection.

## Downstream Effects of Audit Classifications

Audit classifications feed into two downstream protocols:

| Classification | Effect |
| -------------- | ------ |
| Applied (3+ sessions) | Lesson becomes a strong compaction and promotion candidate |
| Violated (1+)  | Immediately generates a new reinforcing lesson entry |
| Irrelevant (3+ sessions) | Lesson is deprioritized in retrieval; compaction can remove it |

See `references/compaction.md` for compaction staleness rules.
See `references/promotion.md` for promotion criteria.

## Anti-Patterns

- **Do not skip the audit** because it feels tedious — it is the only signal that proves lessons are being used.
- **Do not classify everything as Applied** to feel good — Applied without evidence is noise.
- **Do not classify as Violated** unless the Trigger actually fired — a lesson about `git-push` is not Violated if you didn't push anything.
- **Do not write audit without looking at actual injection markers** — recall bias inflates Applied rates.
