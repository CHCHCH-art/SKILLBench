# Skill Template

Use this template when creating new skills via the meta-agent.

```markdown
---
name: [kebab-case-name]
description: [Action-oriented description with trigger keywords. Include technology name and key use cases. Example: "Handles Prisma database operations including schema changes, migrations, and seeding. Use for prisma, schema, migration, database."]
allowed-tools: [Comma-separated list of required tools]
model: sonnet
---

# [Technology/Domain] Skill

## Documentation Access

You have UNFETTERED access to documentation. Always consult official docs.

**Primary Documentation:**
- [Official docs URL]
- [API reference URL]
- [Guides/tutorials URL]

## Purpose

[2-3 sentences describing what this skill handles and when it should be used]

## Autonomy Level: Full

- [Key capability 1]
- [Key capability 2]
- Consult documentation freely
- Fix errors autonomously (3 retries)
- Delegate to other skills when appropriate

## When to Activate

This skill auto-invokes when:
- Working with [file patterns, e.g., "*.prisma files"]
- User mentions [keywords, e.g., "database migration"]
- Task involves [domain, e.g., "payment processing"]

## Instructions

### [Workflow 1 Name]

1. [Step 1]
2. [Step 2]
3. [Step 3]

### [Workflow 2 Name]

1. [Step 1]
2. [Step 2]
3. [Step 3]

## Common Patterns

### [Pattern Name]

```[language]
// Example code or configuration
```

**When to use:** [Explanation]

### [Pattern Name]

```[language]
// Example code or configuration
```

**When to use:** [Explanation]

## Configuration

### Required Setup

```bash
# Commands to set up this technology
```

### Environment Variables

```
EXAMPLE_VAR=description
```

## Error Handling

| Error | Cause | Resolution |
|-------|-------|------------|
| [Error message] | [Common cause] | [How to fix] |
| [Error message] | [Common cause] | [How to fix] |

## Best Practices

1. **[Practice 1]**: [Explanation]
2. **[Practice 2]**: [Explanation]
3. **[Practice 3]**: [Explanation]

## Anti-Patterns

- **Don't**: [Bad practice] → **Do**: [Good practice]
- **Don't**: [Bad practice] → **Do**: [Good practice]

## Delegation

Hand off to other skills when:
- [Condition] → Delegate to [skill-name]
- [Condition] → Delegate to [skill-name]

## Related Commands

- `/[command]` - [Description]
- `/[command]` - [Description]

## Files Used

- `[file pattern]` - [Purpose]
- `[file pattern]` - [Purpose]
```

## Checklist for New Skills

Before finalizing a skill, verify:

- [ ] Name is kebab-case and descriptive
- [ ] Description includes trigger keywords
- [ ] Documentation URLs are current and accessible
- [ ] Tools list is minimal but complete
- [ ] Instructions are specific, not generic
- [ ] Common patterns include real code examples
- [ ] Error handling covers likely issues
- [ ] Delegation rules are clear
- [ ] Model choice is appropriate (sonnet default, opus for complex)
