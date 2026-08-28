---
name: teach-oh
description: Project setup. Explore the codebase, ask about strategy and aims, write persistent context to AGENTS.md. Run when starting or when aims shift.
---

# /teach-oh

Setup that gathers project context and saves it to AGENTS.md (the cross-agent standard). Run when starting on a project or when strategy/aims have shifted.

## When to Use

Invoke `/teach-oh` when:

- **Starting on a new project** - Before diving into work
- **Context keeps getting lost** - AI assistants don't "get" your project
- **Onboarding a new AI tool** - Establish shared understanding upfront
- **After major strategic shifts** - When aims or constraints have changed

**Do not use when:** You're mid-task. This is setup, not execution.

## The Process

### Step 1: Explore the Codebase

Before asking questions, scan the project independently:

**Structure & Stack**
- Directory layout, key folders
- Package files (package.json, Cargo.toml, go.mod, etc.)
- Build configuration, CI/CD setup

**Existing Context**
- AGENTS.md, CLAUDE.md, README, CONTRIBUTING
- `.oh/`, `docs/adr/` directories
- Any existing project documentation

**Patterns & Conventions**
- Naming conventions in code
- File organization patterns
- Recent git commits for style and focus

**Don't ask about what you can discover.** Use exploration to form better questions.

### Step 2: Ask About What Matters

After exploration, ask targeted questions about what couldn't be inferred. Focus on strategy and aims, not just code.

#### Purpose & Aims
- What is this project trying to achieve?
- Who uses it? What change in their behavior indicates success?
- What's the current focus or priority?

#### Strategic Constraints
- What constraints never bend? (Compliance, performance SLAs, etc.)
- What trade-offs has the team made intentionally?
- What's explicitly out of scope?

#### Team & Decision-Making
- How does the team make decisions?
- What does "done" mean here?
- Any patterns or practices that are sacred?

#### What to Avoid
- Past mistakes that shouldn't be repeated
- Patterns that look tempting but don't fit
- Areas of the codebase that are sensitive

**Ask only what you couldn't discover.** Respect the user's time.

### Step 3: Write Persistent Context

Synthesize findings into a structured section and offer to append to AGENTS.md (or create it if missing).

**Offer two sections:**

1. **Open Horizons Framework** - The strategic framework for AI-assisted work (offer to include if user uses OH skills)
2. **Project Context** - Project-specific aims, constraints, and patterns (always include)

```markdown
# Open Horizons Framework

**The shift:** Action is cheap. Knowing what to do is scarce.

**The sequence:** aim → problem-space → problem-statement → solution-space → execute → ship

**Where to start (triggers):**
- Can't explain why you're building this → `/aim`
- Keep hitting the same blockers → `/problem-space`
- Solutions feel forced → `/problem-statement`
- About to start coding → `/solution-space`
- Work is drifting or reversing → `/salvage`

**Reflection skills (use anytime):**
- `/review` - Check alignment before committing
- `/dissent` - Seek contrary evidence before one-way doors
- `/salvage` - Extract learning, restart clean

**Key insight:** Enter at the altitude you need. Climb back up when you drift.

---

# Project Context

## Purpose
[What this project does and why it matters]

## Current Aims
[Active goals and what success looks like]

## Key Constraints
- [Constraint 1]: [Why it exists]
- [Constraint 2]: [Why it exists]

## Patterns to Follow
- [Pattern]: [When/why to use it]

## Anti-Patterns to Avoid
- [Anti-pattern]: [Why it's problematic here]

## Decision Context
[How the team makes decisions, what "done" means]
```

## Output Format

Present findings for user approval before writing:

```
## Teach-OH Summary

### What I Discovered
- Stack: [technologies found]
- Structure: [key patterns observed]
- Existing context: [what docs already exist]

### Questions I Have
1. [Question about aims/strategy]
2. [Question about constraints]
3. [Question about team practices]

---

After your answers, I'll draft a AGENTS.md section for your approval.
```

After user answers:

```
## Proposed AGENTS.md Addition

[Draft the Project Context section]

---

**Write to AGENTS.md?** [Yes/No - show what will be added/updated]
```

## Example

```
/teach-oh
```

**Agent explores, then:**

```
## Teach-OH Summary

### What I Discovered
- Stack: TypeScript, React, Node.js, PostgreSQL
- Structure: Monorepo with apps/ and packages/
- Existing context: README exists, no AGENTS.md or CLAUDE.md
- Recent focus: Auth refactor (last 12 commits)

### Questions I Have
1. What's the main aim right now? The auth work—is that about security, UX, or maintenance?
2. I see both REST and GraphQL endpoints. Is one preferred, or context-dependent?
3. Any performance constraints? I see a Redis layer but no docs on when to use it.
4. What patterns should I follow vs. avoid?
```

**User answers, agent drafts:**

```
## Proposed AGENTS.md Addition

# Open Horizons Framework

**The shift:** Action is cheap. Knowing what to do is scarce.

**The sequence:** aim → problem-space → problem-statement → solution-space → execute → ship

**Where to start (triggers):**
- Can't explain why you're building this → `/aim`
- Keep hitting the same blockers → `/problem-space`
- Solutions feel forced → `/problem-statement`
- About to start coding → `/solution-space`
- Work is drifting or reversing → `/salvage`

**Reflection skills:** `/review`, `/dissent`, `/salvage`

**Key insight:** Enter at the altitude you need. Climb back up when you drift.

---

# Project Context

## Purpose
Customer portal for B2B SaaS. Users are account admins managing their organization's settings, users, and billing.

## Current Aims
- Simplify auth flow so new SSO providers can be added in <1 day (currently takes 2 weeks)
- Success: Adding Okta support by end of Q1

## Key Constraints
- SOC2 compliance: All auth changes need security review
- <200ms API response time (SLA commitment)
- No breaking changes to existing OAuth integrations

## Patterns to Follow
- REST for public API, GraphQL for internal dashboard
- Redis for session state only, not general caching
- Feature flags via LaunchDarkly for gradual rollouts

## Anti-Patterns to Avoid
- Don't abstract OAuth providers into single interface (they have semantic differences)
- Avoid adding new environment variables without updating .env.example

## Decision Context
Tech lead approves architecture changes. PRs need one review. "Done" = deployed to staging with passing E2E tests.

---

**Write to AGENTS.md?** This will create a new file at ./AGENTS.md
```

## Step 4 (Optional, OMP only): Phase-Aware Hook

If the user is running OMP (oh-my-pi), offer to install the phase-aware skills hook. This hook makes the framework self-guiding — it detects where the user is in the development cycle and suggests the right skill before each prompt.

**When to offer:** After writing AGENTS.md, if the project uses OMP. Detect OMP by checking for `.omp/` directory or `omp` in the shell path.

**What to ask:**
> "Install the phase-aware skills hook? It reads your `.oh/` session files and suggests the right OH skill at the right moment. Copies `oh-skills-phase.ts` to `.omp/hooks/` for auto-discovery."

**If accepted:**

1. Copy `hooks-omp/oh-skills-phase.ts` from the skills installation directory to the project's `.omp/hooks/oh-skills-phase.ts` (create the directory if needed).

2. Optionally create `.oh/skills-config.json` based on what you learned about the project. The config is loaded once at session start (changes require restarting OMP):

```json
{
  "projectSkills": ["aim", "problem-space", "solution-space", "execute", "review", "dissent"],
  "disabledSkills": [],
  "phaseOverrides": {
    "execute": ["dissent"]
  }
}
```

**Customization guidance:**
- `projectSkills`: Include only the skills relevant to this project's workflow. A solo dev doing rapid iteration might skip `problem-space`. A team with compliance requirements might always want `dissent` before `execute`. **Note:** `phaseOverrides` targets must be included in `projectSkills` — override skills are filtered by the same allow list.
- `disabledSkills`: Skills that don't fit this project (e.g., `ship` for a library that publishes via CI).
- `phaseOverrides`: Extra skills to suggest during specific phases. Common: adding `dissent` during `execute` for security-sensitive projects.

**If declined:** Skip. The skills work fine without it — this is an enhancement, not a requirement.

**If the user is not running OMP:** Skip this step entirely. The hook requires the OMP hook API and will not work with other agents. Users can still install it manually later by copying the file to `.omp/hooks/`.

## What This Enables

With project context established:

- `/aim` frames outcomes in your language
- `/problem-space` knows which constraints are real
- `/dissent` understands your risk tolerance
- `/review` checks against your definition of done
- `/execute` follows your patterns

## Notes

- Context lives in AGENTS.md so it persists across sessions
- Keep it focused—this isn't documentation, it's working context
- Re-run when aims shift, constraints change, or context feels stale

---

**Remember:** This is setup, not ongoing work. Invest 10 minutes when starting or when things have shifted.
