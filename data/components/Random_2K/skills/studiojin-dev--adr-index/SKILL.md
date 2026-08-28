---
name: adr-index
description: Generate and validate the ADR index for this repo (docs/adr/*.md -> docs/adr/index.json). Use when updating ADRs, checking ADR metadata format, or keeping agent context small; enforce header/metadata rules and never append done-logs to AGENTS.md.
---

# ADR Index

## Workflow

1) Run the generator/validator:

```bash
python .codex/skills/adr-index/scripts/build_adr_index.py
```

2) If duplicate ADR IDs are reported:
- Keep the first ADR for that ID unchanged.
- For each later `change:` path, choose the first suggested replacement ID by default.
- Only choose a later suggestion if repo-specific naming or ordering conventions make it a better fit.
- Update the ADR header to the chosen ID.
- If the filename embeds the old ADR ID, rename the file to match.
- Re-run the generator until it succeeds.

3) Review the short summary output (ADR count + whether index.json changed).

## ADR Rules (enforced by script)

- First line must be `# ADR-YYYYMMDD-####-XXX: <title>` (date, 4 digits, 3 random chars, non-empty title).
- ADR IDs must be unique across `docs/adr/*.md`.
- Optional metadata lines within the first ~40 lines:
  - `Tags: a, b, c`
  - `Status: Proposed | Accepted | Deprecated`
  - `Date: YYYY-MM-DD` (optional, but if present it must match the header date)
  - `TL;DR: one short sentence`

## Output

- Writes `docs/adr/index.json` with fields: id, title, tags[], status, date, tldr, path.
- Sorts by date desc, then id desc.
- Prints only a short summary line.
- On duplicate ADR IDs, prints replacement ID candidates for each later duplicate so the AI can pick one and continue cleanly.

## Guardrails

- Never append done-logs to `AGENTS.md`; decisions belong in ADRs.
- Ensure `AGENTS.md` includes the Documentation Workflow policy block below; add it if missing.

## AGENTS.md Policy Block

```
## Documentation Workflow

The following terms are to be interpreted as described in RFC 2119:
“MUST”, “MUST NOT”, “SHOULD”, and “MAY”.

1. ADRs MUST be written in `docs/adr/*.md`.

2. When an ADR is added or modified, `docs/adr/index.json` MUST be updated accordingly.

3. The ADR index MUST be generated using the `adr-index` skill.

4. AGENTS.md MUST NOT accumulate completed work logs.
   Architectural decisions MUST be recorded in ADRs.
   AGENTS.md MAY contain only links to ADRs or brief summaries.

### ADR Detection Rule

If you make or rely on a decision that:
- introduces architectural constraints,
- involves trade-offs,
- or is not obvious from code alone,

you MUST pause and explicitly state:
"An ADR is required for this decision."
```
