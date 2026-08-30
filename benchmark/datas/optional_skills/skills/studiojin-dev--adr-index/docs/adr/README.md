# Architecture Decision Records (ADR)

This directory contains Architecture Decision Records (ADRs).

ADRs capture **architectural and design decisions** that:
- affect system structure or constraints
- introduce long-term implications
- may require explanation in the future

They are not task logs or implementation notes.

---

## What Belongs in an ADR

Write an ADR when a decision:

- introduces or changes architectural constraints
- requires trade-off analysis
- affects multiple components or future work
- would be expensive or risky to reverse
- is not obvious from reading the code alone

If in doubt, write an ADR.

---

## What Does NOT Belong in an ADR

Do NOT write an ADR for:

- simple bug fixes
- pure refactoring with no architectural impact
- experimental or exploratory work
- implementations that strictly follow an existing ADR

---

## ADR File Naming

ADR files MUST follow this format: ADR-YYYYMMDD-####-XXX

Example:
```
ADR-20260203-0007-A9F
```

- `YYYYMMDD` : decision date
- `####`     : per-day sequence number
- `XXX`      : random alphanumeric suffix (collision-safe)

This format ensures:
- chronological sorting
- safe parallel work
- scalability for large projects
- globally unique ADR IDs across `docs/adr/*.md`

---

## ADR File Structure

Each ADR MUST start with the following header:

```md
# ADR-YYYYMMDD-####-XXX: <Short descriptive title>

Tags: comma-separated keywords
Status: Proposed | Accepted | Deprecated
Date: YYYY-MM-DD
TL;DR: One short sentence summarizing the decision.
```

If `Date:` is present, it MUST match the `YYYYMMDD` date in the ADR header.
ADR IDs MUST be unique across `docs/adr/*.md`.

# Architecture Decision Records (ADR)

This directory contains Architecture Decision Records (ADRs).

ADRs capture **architectural and design decisions** that:
- affect system structure or constraints
- introduce long-term implications
- may require explanation in the future

They are not task logs or implementation notes.

---

## What Belongs in an ADR

Write an ADR when a decision:

- introduces or changes architectural constraints
- requires trade-off analysis
- affects multiple components or future work
- would be expensive or risky to reverse
- is not obvious from reading the code alone

If in doubt, write an ADR.

---

## What Does NOT Belong in an ADR

Do NOT write an ADR for:

- simple bug fixes
- pure refactoring with no architectural impact
- experimental or exploratory work
- implementations that strictly follow an existing ADR

---

## ADR File Naming

ADR files MUST follow this format:

ADR-YYYYMMDD-####-XXX

Example:

ADR-20260203-0007-A9F

- YYYYMMDD : decision date
- ####     : per-day sequence number
- XXX      : random alphanumeric suffix (collision-safe)

This format ensures:
- chronological sorting
- safe parallel work
- scalability for large projects

---

## ADR File Structure

Each ADR MUST start with the following header:

# ADR-YYYYMMDD-####-XXX: Short descriptive title
Tags: comma-separated keywords
Status: Proposed | Accepted | Deprecated
Date: YYYY-MM-DD
TL;DR: One short sentence summarizing the decision.

Only the first header line is strictly required.
Metadata lines are optional but strongly recommended.
If `Date:` is present, it MUST match the `YYYYMMDD` date in the ADR header.
ADR IDs MUST be unique across `docs/adr/*.md`.

---

## ADR Sections

### Context

Describe the background and problem that led to this decision.
Focus on *why* the decision is needed.

### Decision

State the decision clearly and unambiguously.

### Consequences

Describe the impact, trade-offs, risks, and follow-up considerations.

---

## ADR Lifecycle

1. A decision is made.
2. An ADR is written or updated.
3. The ADR index is regenerated using the adr-index skill.
4. docs/adr/index.json becomes the canonical lookup for agents.
5. Any related entries are removed from AGENTS.md.

AGENTS.md MUST NOT retain completed decision details.

---

## Indexing Requirement

After adding or modifying any ADR, you MUST run:

- $adr-index   (Codex CLI)
- /adr-index   (Claude Code, Gemini CLI)

This updates docs/adr/index.json, which agents use for fast, low-cost lookup.
If duplicate ADR IDs are detected, the tool will print suggested replacement
IDs for each later duplicate ADR instead of writing the index. Choose one of
the suggested IDs, update the ADR header, optionally rename the file, and run
the tool again.

---

## Status Values

- Proposed   : Decision under consideration
- Accepted   : Decision finalized and in effect
- Deprecated : Decision no longer recommended or superseded

Deprecated ADRs MUST NOT be deleted.
They remain as historical context.
---
