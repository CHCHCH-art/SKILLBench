# Agent README.md Template

Use this template when adding agents to a README.md index.

## Index Table Row

Add a row to the existing table:

```markdown
| agent-name | Brief description of what the agent does | opus | default |
```

Columns: Name | Description | Model | Permission Mode

## Description Section

Add a section below the table:

```markdown
### agent-name

One-paragraph description of the agent's purpose, typical use cases,
and any notable configuration (tools, skills, MCP servers).

**Key fields:**
- Model: opus/sonnet/haiku/inherit
- Permission mode: default/acceptEdits/delegate
- Skills: list of preloaded skills
```

## Checklist

Before submitting:

- [ ] Table row is alphabetically sorted
- [ ] Name matches the agent filename (without .md)
- [ ] Description is concise (one sentence in table, one paragraph in section)
- [ ] Model and permission mode are accurate
- [ ] No duplicate entries in the table
