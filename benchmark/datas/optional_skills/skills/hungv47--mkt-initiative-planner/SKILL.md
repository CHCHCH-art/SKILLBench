---
name: mkt-initiative-planner
description: This skill should be used when the user asks to "plan an initiative", "create initiative", "validate initiative", "new growth initiative", "initiative proposal", "initiative planning", "build a campaign brief", "review my initiative", "generate ideas", "brainstorm initiatives", "score initiatives", "ICE scoring", "prioritize initiatives", or mentions initiative planning, growth initiative, campaign brief, initiative validation, idea generation, or ICE scoring.
license: MIT
metadata:
  author: hungv47
  version: "2.0.0"
---

# Initiative Planner

*Part of the Problem → Solution → Communicate framework. Drives the **Solution** phase — generating, prioritizing, and planning initiatives.*

Generate, prioritize, and plan growth initiatives. Every initiative is a bet — this skill helps you make better bets.

## Philosophy

Most teams either skip straight to execution (no hypothesis) or over-plan (analysis paralysis). The right process is: generate many ideas, score them honestly, then plan the top few thoroughly. Cheap ideas first, expensive planning later.

## Mode Detection

| User says... | Mode |
|-------------|------|
| "Generate ideas", "brainstorm", "what should we try" | **Generate** |
| "Score these", "prioritize", "ICE scoring", "rank initiatives" | **Prioritize** |
| "Plan an initiative", "create initiative", "new initiative" | **Plan** |
| "Validate initiative", "review my initiative" | **Validate** |

If unclear, ask: *"Do you want to brainstorm ideas, score/prioritize existing ideas, plan a specific initiative, or validate an existing proposal?"*

---

## Generate Mode

Interview-driven brainstorming. Output: 5-10 initiative ideas.

### Step 1: Understand the Context

Ask:

> **Problem context**: What problem are you solving? (If they've used `mkt-diagnosis`, reference the root cause statement.)

> **Funnel stage**: Where in the funnel is the gap? (Awareness / Acquisition / Activation / Retention / Revenue / Referral)

> **Constraints**: What can't you do? (Budget limits, team size, timeline, tech limitations)

> **What you've tried**: What's been attempted? What worked, what didn't?

### Step 2: Generate Ideas

Produce 5-10 initiative ideas. For each, provide:

| # | Initiative Name | Target Metric | Mechanic (1-2 sentences) | Effort Estimate |
|---|----------------|---------------|--------------------------|-----------------|
| 1 | [Name] | [Metric] | [How it works] | [S/M/L] |
| 2 | ... | ... | ... | ... |

**Generation principles:**
- Mix proven tactics (high confidence) with experimental bets (high potential impact)
- Include at least one "boring but effective" option
- Include at least one unconventional option
- Vary effort levels — not all should be big bets
- Each idea should be distinct, not variations of the same approach

### Step 3: Discuss and Refine

Ask: *"Which of these resonate? Any you'd immediately cut? Any that spark a different idea?"*

Refine the list based on feedback. Add new ideas if the discussion surfaces them.

### Output

A refined list of 5-10 ideas ready for ICE scoring in Prioritize mode.

---

## Prioritize Mode (ICE Scoring)

Score initiatives on Impact × Confidence × Ease. Output: ranked table with top 2-3 proceeding to Plan mode.

### Step 1: Confirm the List

Ask: *"Which initiatives are we scoring? Do you have a list, or should we generate ideas first?"*

If no list exists, switch to Generate mode first.

### Step 2: Score Each Initiative

For each initiative, score 1-10 on three dimensions:

| Dimension | Question | 1-3 | 4-6 | 7-10 |
|-----------|----------|-----|-----|------|
| **Impact** | How much will it move the target metric? | Minor, barely noticeable | Meaningful improvement | Significant or transformative |
| **Confidence** | How sure are we this will work? | Gut feeling, no data | Some supporting data | Direct evidence, proven playbook |
| **Ease** | How easy is this to execute? | Multi-team, months, complex | Moderate effort, manageable | Small team, quick turnaround |

See [references/ice-scoring-rubric.md](references/ice-scoring-rubric.md) for detailed calibration with scored examples.

### Step 3: Build the Ranked Table

| Rank | Initiative | Impact | Confidence | Ease | ICE Score | Notes |
|------|-----------|--------|------------|------|-----------|-------|
| 1 | [Name] | [1-10] | [1-10] | [1-10] | [Sum] | [Key reasoning] |
| 2 | ... | ... | ... | ... | ... | ... |

### Step 4: Draw the Line

Ask: *"How many initiatives can you execute well simultaneously? (Usually 2-3)"*

Mark the cut line. Initiatives above proceed to Plan mode. Below the line: park for later or kill.

### Output

A ranked ICE table with clear proceed/park/kill decisions.

---

## Plan Mode

Structured planning for a specific initiative. Output: complete initiative document.

### Planning Process

```
Foundation → Strategy → Resources → Success → Risk
```

### Phase 1: Foundation

Ask:

> **Initiative Name & Type**: Working name? Hero (major, significant resources) or Support (smaller, complementary)?

> **Hypothesis**: What do you believe will happen? Structure as: "If we [action], then [outcome] because [reason]"

See [references/initiative-types.md](references/initiative-types.md) for Hero vs Support guidance.
See [references/hypothesis-framework.md](references/hypothesis-framework.md) for hypothesis templates.

### Phase 2: Strategy

Ask:

> **Growth Lever**: Which funnel stage? What specific metric?

> **Segment**: Who is this targeting? How large? What are the eligibility criteria?

> **Mechanic**: How does this actually work? Walk through the user journey. What's the core action?

### Phase 3: Resources

Ask:

> **Budget**: Media/advertising? Incentive costs? Operational expenses?

> **Dependencies**: Which teams? External partners? Assets to create? Approvals needed?

> **Effort**: Internal resources required? Who owns it? Team bandwidth?

### Phase 4: Success Criteria

Ask:

> **KPIs**: Primary metric? Guardrail metrics? CAC/CPI/CPA assumptions?

> **Impact Estimate**: Qualitative expected impact? Quantitative target? (Be specific: "Increase signups by 20%" not "More signups")

> **Timeline**: Start date? End date? Key milestones?

> **Thresholds**: What result means "ship" (scale)? "Iterate" (adjust)? "Stop" (kill)?

### Phase 5: Risk Assessment

Ask:

> **Confidence**: How confident? (Low/Medium/High) Why? What would increase confidence?

> **Risks**: Top 3 risks? Mitigation plan for each? Kill switch if things go wrong?

### Synthesis

After gathering all information, compile into the Initiative Document Template below.

---

## Validate Mode

Review existing initiative proposals against quality criteria. See [references/validation-mode.md](references/validation-mode.md) for the full validation process, field-by-field checks, anti-patterns, and output format.

See [references/validation-criteria.md](references/validation-criteria.md) for detailed per-field validation guidance.

---

## Initiative Document Template

```markdown
# Initiative: [Name]

## Overview
| Field | Value |
|-------|-------|
| **Type** | [Hero / Support] |
| **Owner** | [Name] |
| **Timeline** | [Start] → [End] |
| **Confidence** | [Low / Medium / High] |
| **ICE Score** | [Score] (if scored) |

## Hypothesis
**If** [we take this action]
**Then** [this outcome will happen]
**Because** [this underlying reason/insight]

## Strategy
### Growth Lever
- **Funnel Stage**: [Stage]
- **Target Metric**: [Metric]

### Segment
- **Target**: [Who]
- **Size**: [Estimated reach]
- **Eligibility**: [Criteria]

### Mechanic
[Step-by-step description]

## Resources
### Budget
| Category | Amount |
|----------|--------|
| Media | $ |
| Incentives | $ |
| Operations | $ |
| **Total** | $ |

### Dependencies
| Dependency | Owner | Status |
|------------|-------|--------|
| [Item] | [Who] | [Pending/Confirmed] |

### Effort
| Role | Hours/Week | Duration |
|------|------------|----------|
| [Role] | [Hours] | [Weeks] |

## Success Criteria
### KPIs
| KPI | Target | Baseline |
|-----|--------|----------|
| Primary: [Metric] | [Target] | [Current] |
| Guardrail: [Metric] | [Min acceptable] | [Current] |

### Impact Estimate
- **Qualitative**: [Expected impact description]
- **Quantitative**: [Specific numbers with assumptions stated]

### Decision Thresholds
| Outcome | Criteria | Action |
|---------|----------|--------|
| Ship | [Metric] > [Value] | Scale up |
| Iterate | [Metric] between [X-Y] | Adjust and retry |
| Stop | [Metric] < [Value] | Kill initiative |

## Risk Assessment
### Risks & Mitigations
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| [Risk 1] | [H/M/L] | [H/M/L] | [Plan] |

### Kill Switch
[What triggers immediate shutdown and how]
```

---

## Additional Resources

- [references/initiative-types.md](references/initiative-types.md) — Hero vs Support initiatives
- [references/hypothesis-framework.md](references/hypothesis-framework.md) — Writing strong hypotheses
- [references/ice-scoring-rubric.md](references/ice-scoring-rubric.md) — ICE calibration and examples
- [references/validation-mode.md](references/validation-mode.md) — Full validation process
- [references/validation-criteria.md](references/validation-criteria.md) — Per-field quality checklist

---

## Next Steps

After initiatives are planned:
- Use `mkt-icp-research` to deeply understand the target audience before building messaging
- Or go directly to `mkt-imc` if you have enough audience context (it has a Quick ICP mode)
- Use `mkt-attribution` to map planned initiatives to KPIs and check coverage

## How to Work

- **Generate**: Breadth over depth. Get ideas on the table fast, refine later.
- **Prioritize**: Be honest. Optimism bias kills prioritization. Score for "likely case" not "best case."
- **Plan**: Ask questions, don't assume. Build the initiative together.
- **Validate**: Be direct about problems. Vague feedback doesn't help.
- All modes: Explain the "why" behind recommendations.
