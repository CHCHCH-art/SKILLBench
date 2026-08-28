# Specification Guide

Extended guidance for feature specifications. See SKILL.md for core rules.

---

## Document Boundary

See the Exclusions section in SKILL.md for the complete list.

---

## When to Create an ADR

If a specification establishes a pattern with project-wide implications, create an ADR to document the reusable pattern separately.

| Content | Location | Reason |
|---------|----------|--------|
| "Use message queues for async processing" | ADR | Project-wide pattern |
| "Notification delivery uses message queue" | Spec | Feature-specific application |
| "Use PostgreSQL for persistence" | ADR | Project-wide technology |
| "Notification preferences stored in users table" | Spec | Feature-specific storage |

---

## Archival

Implemented specifications move to `specs/historical/` for reference.
