# Hypothesis Framework

A well-formed hypothesis is the foundation of any good initiative. It makes assumptions explicit, enables testing, and provides clear success/failure criteria.

## The Structure

```
If [we take this action]
Then [this outcome will happen]
Because [this underlying reason/insight]
```

### Why Each Part Matters

| Component | Purpose | What Happens Without It |
|-----------|---------|------------------------|
| **If** | Defines the specific action | No clarity on what to do |
| **Then** | States the expected outcome | No way to measure success |
| **Because** | Explains the underlying logic | No learning if it fails |

The "Because" is the most important and most often skipped. Without it, you can't learn from failures or understand why something worked.

---

## Writing Strong Hypotheses

### Level 1: Basic (Acceptable)

```
If we run a 20% discount promotion
Then signups will increase by 15%
Because price is a barrier for our target segment
```

### Level 2: Specific (Better)

```
If we run a 20% discount promotion targeted at users who abandoned checkout
Then conversion rate will increase from 2% to 5%
Because exit survey data shows 60% cite price as their primary objection
```

### Level 3: Testable with Kill Criteria (Best)

```
If we run a 20% discount promotion targeted at users who abandoned checkout in the last 7 days
Then conversion rate will increase from 2% to 5% within 14 days
Because exit survey data (n=500) shows 60% cite price as their primary objection, and competitor analysis shows we're 25% above market average

Kill if: Conversion stays below 3% after 7 days, or CAC exceeds $50
```

---

## Common Hypothesis Weaknesses

### Weak: No "Because"

**Bad**: "If we add social login, then signups will increase."

**Problem**: Why do you think this? What insight supports it?

**Better**: "If we add social login, then signup completion will increase by 20% because heatmap data shows 40% of users abandon at the password creation step, and competitor A saw 25% improvement after adding Google login."

### Weak: Vague Outcome

**Bad**: "If we improve onboarding, then retention will improve."

**Problem**: What does "improve" mean? How much? By when?

**Better**: "If we add a progress indicator to onboarding, then Day-7 retention will increase from 35% to 45% because user interviews revealed the top complaint is 'not knowing what's next.'"

### Weak: Untestable

**Bad**: "If we build brand awareness, then people will trust us more."

**Problem**: How do you measure "trust"? What's the action?

**Better**: "If we publish 12 educational blog posts over 3 months, then organic traffic will increase by 50% and demo requests will increase by 20% because our target audience searches for these topics (keyword research attached) and our current content gap analysis shows competitors ranking for these terms."

### Weak: Multiple Variables

**Bad**: "If we redesign the homepage and add social proof and change the CTA, then conversion will improve."

**Problem**: If it works (or doesn't), you won't know which change mattered.

**Better**: Test one variable at a time, or explicitly design for multivariate testing with sufficient sample size.

---

## Hypothesis Templates by Initiative Type

### Acquisition Initiative

```
If we [channel/tactic] targeting [specific segment]
Then [acquisition metric] will [change by X%]
Because [data/insight about why this segment responds to this channel]
```

Example:
```
If we run TikTok ads featuring customer testimonials targeting 25-34 year olds interested in fitness
Then CAC will decrease from $45 to $35 and volume will increase by 200 signups/week
Because this demographic over-indexes on TikTok (2x platform average) and testimonial ads outperformed product ads 3:1 in our Meta tests
```

### Retention Initiative

```
If we [intervention] for users who [behavior/trigger]
Then [retention metric] will improve by [X%]
Because [reason these users churn and why this intervention addresses it]
```

Example:
```
If we send a personalized email with feature recommendations to users who haven't logged in for 7 days
Then Day-30 retention will improve from 25% to 35%
Because cohort analysis shows Day 7-14 is the critical churn window, and users who discover 3+ features have 2x better retention
```

### Revenue Initiative

```
If we [pricing/monetization change] for [segment]
Then [revenue metric] will [change by X]
Because [reason this segment will respond positively]
```

Example:
```
If we introduce an annual plan with 2 months free for monthly subscribers at renewal
Then annual plan adoption will reach 30% and LTV will increase by 20%
Because survey data shows 45% of monthly users would switch for savings, and annual users have 3x better retention
```

### Activation Initiative

```
If we [onboarding change] for new users
Then [activation metric] will improve from [X] to [Y]
Because [insight about what blocks activation currently]
```

Example:
```
If we add an interactive product tour that guides users to complete their first [key action]
Then activation rate (users who complete [action] in first session) will improve from 20% to 40%
Because session recordings show 60% of churned users never discovered this feature, and users who complete it have 4x better Week-1 retention
```

---

## Validating Your Hypothesis

Before finalizing, check:

### Specificity Check
- [ ] Action is concrete and implementable
- [ ] Outcome has a number attached
- [ ] Timeline is defined
- [ ] Segment is specific

### Evidence Check
- [ ] "Because" cites actual data or research
- [ ] You can explain why this will work to a skeptic
- [ ] You've considered why this might NOT work

### Testability Check
- [ ] You can measure the outcome
- [ ] Sample size is sufficient for statistical significance
- [ ] You have a baseline to compare against
- [ ] You know what "failure" looks like

### Learning Check
- [ ] If it fails, you'll learn something useful
- [ ] If it succeeds, you know what to do next
- [ ] The "because" can be validated or invalidated

---

## When Hypotheses Fail

A failed hypothesis isn't a failed initiative if you learn something.

### Good Failure
- Hypothesis was clear and testable
- Data shows the "because" was wrong
- You now have new insight for next iteration

### Bad Failure
- Hypothesis was vague
- Can't tell what went wrong
- No learning, just wasted resources

### Post-Failure Questions
1. Was the action executed correctly?
2. Was the outcome measured accurately?
3. Was the "because" actually wrong, or was execution flawed?
4. What new hypothesis does this suggest?

---

## Hypothesis Evolution

Strong initiatives evolve their hypotheses through testing:

```
Hypothesis v1: If we offer free trial, signups increase
→ Result: Signups increased but conversions dropped

Hypothesis v2: If we offer 7-day trial (not 14), conversion improves
→ Result: No significant change

Hypothesis v3: If we offer 7-day trial with onboarding calls for enterprise, conversion improves
→ Result: Enterprise conversion up 40%

Final Learning: Free trials work for enterprise when paired with high-touch onboarding
```

This is the goal: iterative learning that compounds into real understanding.
