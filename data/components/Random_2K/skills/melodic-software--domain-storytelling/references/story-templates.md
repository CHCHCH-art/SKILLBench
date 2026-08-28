# Story Templates

## Overview

This document provides templates for capturing and documenting domain stories.

## Story Document Template

### Full Template

```markdown
---
title: [Story Name]
type: AS-IS | TO-BE
domain: [Domain Name]
subdomain: [Subdomain if applicable]
date: YYYY-MM-DD
version: 1.0
status: draft | validated | approved
participants:
  - role: Domain Expert
    name: [Name]
  - role: Facilitator
    name: [Name]
tags:
  - [tag1]
  - [tag2]
---

# Domain Story: [Story Name]

## Narrative Summary

[2-3 sentence plain language description of what this story captures.
Written in business language, not technical terms.]

## Context

**Trigger:** [What initiates this story - event, request, schedule]
**Goal:** [What is the desired outcome]
**Frequency:** [How often does this happen - daily, weekly, on-demand]
**Volume:** [Typical volume - orders per day, requests per hour]

## Story Sequence

① **[Actor 1]** [verb] **[Work Object]** to/in/from **[Target/System]**
② **[Actor 2]** [verb] **[Work Object]** using **[Reference]**
③ **[Actor 2]** [verb] **[Work Object]** in **[System]**
④ **[System]** [verb] **[Actor 3]** with **[Work Object]**
⑤ **[Actor 3]** [verb] **[Work Object]**
...

### Alternative Path: [Name]

When [condition]:

③' **[Actor]** [different action] **[Work Object]**
④' **[Actor]** [continues differently]...

### Exception Path: [Name]

When [error condition]:

③e **[Actor]** [handles exception] **[Work Object]**
④e **[System]** [error notification]...

## Actors

| Actor | Type | Responsibilities | Notes |
| --- | --- | --- | --- |
| [Actor Name] | Human (Internal/External) / System | [What they do] | [Optional notes] |

## Work Objects

| Work Object | Type | Created By | Used By | Description |
| --- | --- | --- | --- | --- |
| [Object Name] | Document/Data/Physical | [Actor] | [Actors] | [Brief description] |

## Annotations

**[A1]** [Annotation about specific step or general observation]
**[A2]** [Another annotation]

## Glossary Additions

| Term | Definition | Aliases |
| --- | --- | --- |
| [Term] | [Business definition] | [Other names used] |

## Bounded Context Hints

[Observations about potential bounded context boundaries discovered in this story]

- [Hint 1]: [Observation]
- [Hint 2]: [Observation]

## Open Questions

- [ ] [Question 1 requiring follow-up]
- [ ] [Question 2 requiring follow-up]

## Related Stories

- [Link to related AS-IS story]
- [Link to related TO-BE story]

---

**Captured by:** [Facilitator name/AI]
**Validated by:** [Domain expert]
**Last Updated:** YYYY-MM-DD
```

### Minimal Template

For quick capture:

```markdown
# Domain Story: [Story Name]

**Type:** AS-IS | TO-BE
**Domain:** [Domain Name]
**Date:** YYYY-MM-DD

## Story Sequence

① **[Actor]** [verb] **[Object]**
② **[Actor]** [verb] **[Object]**
③ **[Actor]** [verb] **[Object]**

## Actors

- [Actor 1]: [Type]
- [Actor 2]: [Type]

## Work Objects

- [Object 1]: [Description]
- [Object 2]: [Description]
```

## Session Capture Template

For capturing a storytelling session:

```markdown
# Storytelling Session: [Session Name]

**Date:** YYYY-MM-DD
**Duration:** [X] minutes
**Domain:** [Domain Name]

## Participants

| Role | Name | Expertise |
| --- | --- | --- |
| Domain Expert | [Name] | [Area] |
| Facilitator | [Name] | - |

## Session Goals

1. [Goal 1]
2. [Goal 2]

## Stories Captured

### Story 1: [Name]

[Story content...]

### Story 2: [Name]

[Story content...]

## Session Observations

- [Observation 1]
- [Observation 2]

## Follow-up Actions

- [ ] [Action 1]
- [ ] [Action 2]

## Next Session

**Focus:** [What to explore next]
**Participants needed:** [Who else to involve]
```

## Actor Catalog Template

```markdown
# Actor Catalog: [Domain Name]

## Human Actors

### Internal

| Actor | Department | Primary Activities | Systems Used |
| --- | --- | --- | --- |
| [Role] | [Dept] | [Activities] | [Systems] |

### External

| Actor | Organization Type | Interactions | Access Level |
| --- | --- | --- | --- |
| [Role] | [Type] | [Interactions] | [Level] |

## System Actors

### Internal Systems

| System | Purpose | Integrations | Owner |
| --- | --- | --- | --- |
| [System] | [Purpose] | [Connected systems] | [Team] |

### External Systems

| System | Provider | Purpose | Integration Type |
| --- | --- | --- | --- |
| [System] | [Provider] | [Purpose] | [Type] |
```

## Work Object Catalog Template

```markdown
# Work Object Catalog: [Domain Name]

## Documents

| Work Object | Format | Created By | Lifecycle | Retention |
| --- | --- | --- | --- | --- |
| [Object] | [Format] | [Actor] | [States] | [Period] |

## Data Entities

| Work Object | System of Record | Key Attributes | Relationships |
| --- | --- | --- | --- |
| [Object] | [System] | [Attributes] | [Related objects] |

## Physical Items

| Work Object | Description | Tracked By | Lifecycle |
| --- | --- | --- | --- |
| [Object] | [Description] | [System] | [States] |
```

## Glossary Template

```markdown
# Domain Glossary: [Domain Name]

## Terms

### [Term A]

**Definition:** [Business definition in plain language]

**Context:** [Where/when this term is used]

**Aliases:** [Other terms used for the same concept]

**Disambiguation:** [How this differs from similar terms]

**Examples:**

- [Example 1]
- [Example 2]

---

### [Term B]

...
```

## Comparison Template

For AS-IS vs TO-BE comparison:

```markdown
# Story Comparison: [Story Name]

## Overview

| Aspect | AS-IS | TO-BE |
| --- | --- | --- |
| Actors | [Count] | [Count] |
| Steps | [Count] | [Count] |
| Systems | [List] | [List] |
| Duration | [Estimate] | [Target] |

## Side-by-Side Sequence

| Step | AS-IS | TO-BE | Change |
| --- | --- | --- | --- |
| 1 | [AS-IS step] | [TO-BE step] | [Automated/Removed/Added/Modified] |
| 2 | [AS-IS step] | [TO-BE step] | [Change type] |

## Key Changes

### Removed

- [What was removed and why]

### Added

- [What was added and why]

### Modified

- [What changed and why]

## Expected Benefits

- [Benefit 1]
- [Benefit 2]

## Risks and Considerations

- [Risk 1]
- [Risk 2]
```

## Mermaid Diagram Templates

### Sequence Diagram

```text
sequenceDiagram
    autonumber
    participant A as Actor 1
    participant B as Actor 2
    participant S as System

    A->>B: activity with Work Object
    B->>S: activity with Work Object
    S-->>A: response with Work Object

    Note over B: Annotation
```

### Activity Diagram (Flowchart)

```text
flowchart TD
    A[Start: Trigger] --> B{Decision}
    B -->|Yes| C[Activity 1]
    B -->|No| D[Activity 2]
    C --> E[Activity 3]
    D --> E
    E --> F[End: Outcome]
```

### Participant Diagram

```text
flowchart LR
    subgraph Sales
        SR[Sales Rep]
        SM[Sales Manager]
    end
    subgraph Operations
        WS[Warehouse Staff]
        WM[Warehouse Manager]
    end
    subgraph Systems
        OS[Order System]
        IS[Inventory System]
    end

    SR --> OS
    OS --> WS
    WS --> IS
```

---

**Related:** `pictographic-notation.md`, `boundary-discovery.md`
