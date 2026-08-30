# Validation Mode

Use this when reviewing existing initiative proposals. The goal is to identify gaps, flag anti-patterns, and provide specific improvement recommendations.

---

## Validation Process

1. **Read the initiative** — Review all provided details
2. **Check completeness** — Identify missing fields
3. **Assess quality** — Evaluate each field against criteria
4. **Identify red flags** — Flag common anti-patterns
5. **Provide recommendations** — Specific improvements

---

## Field-by-Field Validation

For each field, check:

| Field | Quality Criteria | Red Flags |
|-------|------------------|-----------|
| **Name** | Clear, memorable, action-oriented | Vague, internal jargon |
| **Type** | Appropriate for scope and resources | Misclassified (Hero disguised as Support) |
| **Hypothesis** | Follows If/Then/Because structure | No "because", untestable, too vague |
| **Growth Lever** | Specific funnel stage and metric | Generic "growth", multiple stages |
| **Segment** | Defined size, clear targeting | "Everyone", no eligibility criteria |
| **Mechanic** | Clear user journey, specific actions | Unclear steps, missing touchpoints |
| **Budget** | Itemized, realistic | Missing categories, no contingency |
| **KPIs** | Primary + guardrails, specific targets | Vanity metrics, no baseline |
| **Dependencies** | Named teams/partners, approval path | Assumed availability, no owners |
| **Efforts** | Specific hours/people, owner named | "Will figure it out", no owner |
| **Impact Estimate** | Quantified with assumptions stated | "Significant increase", no numbers |
| **Confidence** | Honest assessment with reasoning | Unjustified "High", no reasoning |
| **Risks** | Specific risks with mitigation plans | Generic risks, no mitigations |
| **Timeline** | Start/end dates, milestones | Open-ended, no deadlines |
| **Success Criteria** | Ship/iterate/stop thresholds defined | No kill criteria, moving goalposts |

See [validation-criteria.md](validation-criteria.md) for detailed per-field guidance with stress-test questions.

---

## Common Anti-Patterns

Flag these issues explicitly:

- **Hypothesis Washing**: Generic statements disguised as hypotheses
- **Metric Dumping**: Too many KPIs with no clear primary
- **Scope Creep Built-In**: Success criteria that can be reinterpreted
- **Optimism Bias**: High confidence with no supporting evidence
- **Risk Theater**: Listing risks without real mitigations
- **Dependency Blindness**: Assuming resources without confirming
- **Timeline Fantasy**: Deadlines that ignore dependencies

---

## Validation Output

Provide feedback in this structure:

```markdown
## Initiative Validation: [Name]

### Completeness: [X/15 fields complete]
- [ ] List missing fields

### Strengths
- What's well-defined
- What shows good thinking

### Concerns
- Specific issues found
- Why each is a problem

### Recommendations
1. [Specific action to improve]
2. [Specific action to improve]
3. [Specific action to improve]

### Verdict
- [ ] Ready to proceed
- [ ] Needs minor revisions
- [ ] Needs major revisions
- [ ] Recommend rethinking
```
