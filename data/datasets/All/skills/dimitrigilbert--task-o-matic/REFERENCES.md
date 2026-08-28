# Task-O-Matic Complete Command Reference

Complete reference for all task-o-matic CLI commands and options.

## Table of Contents

- [init](#init) - Initialize projects
- [config](#config) - Manage configuration
- [prd](#prd) - Manage PRDs
- [tasks](#tasks) - Manage tasks
- [workflow](#workflow) - Interactive workflow
- [prompt](#prompt) - Build AI prompts
- [install](#install) - Install documentation

---

## init

Initialize task-o-matic project and bootstrap projects.

### init init

Initialize a new task-o-matic project in the current directory.

```bash
task-o-matic init init [options]
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `--ai-provider <provider>` | AI provider (openrouter/anthropic/openai/custom) | `openrouter` |
| `--ai-model <model>` | AI model | `z-ai/glm-4.6` |
| `--ai-key <key>` | AI API key | - |
| `--ai-provider-url <url>` | AI provider URL | - |
| `--max-tokens <tokens>` | Max tokens for AI (min 32768 for 2025) | `32768` |
| `--temperature <temp>` | AI temperature | `0.5` |
| `--no-bootstrap` | Skip bootstrap after initialization | - |
| `--project-name <name>` | Project name for bootstrap | - |
| `--frontend <frontends...>` | Frontend framework(s) - space/comma-separated | `next` |
| `--backend <backend>` | Backend framework for bootstrap | `convex` |
| `--database <database>` | Database for bootstrap | - |
| `--auth <auth>` | Authentication for bootstrap | `better-auth` |
| `--context7-api-key <key>` | Context7 API key | - |
| `--directory <dir>` | Working directory for the project | - |
| `--package-manager <pm>` | Package manager (npm/pnpm/bun) | `npm` |
| `--runtime <runtime>` | Runtime (bun/node) | `node` |
| `--payment <payment>` | Payment provider (none/polar) | `none` |
| `--cli-deps <level>` | CLI dependency level | `standard` |

**Frontend options:** next, native-bare, cli, etc.
**Backend options:** convex, etc.
**CLI dependency levels:** minimal, standard, full, task-o-matic

### init bootstrap

Bootstrap a new project (web/native/cli).

```bash
task-o-matic init bootstrap [options] <name>
```

**Arguments:**
- `name` - Project name

### init attach

Attach task-o-matic to an existing project with automatic stack detection.

```bash
task-o-matic init attach [options]
```

**Options:**

| Option | Description | Default |
|--------|-------------|---------|
| `--analyze` | Run full project analysis (TODOs, features, structure) | - |
| `--create-prd` | Auto-generate a PRD from codebase analysis | - |
| `--dry-run` | Just detect stack, don't create files | - |
| `--redetect` | Force re-detection (overwrites cached stack.json) | - |
| `--ai-provider <provider>` | AI provider (openrouter/anthropic/openai/custom) | `openrouter` |
| `--ai-model <model>` | AI model | `z-ai/glm-4.6` |
| `--ai-key <key>` | AI API key | - |
| `--ai-provider-url <url>` | AI provider URL | - |
| `--max-tokens <tokens>` | Max tokens for AI | `32768` |
| `--temperature <temp>` | AI temperature | `0.5` |
| `--context7-api-key <key>` | Context7 API key | - |

**Stack Detection:**

The command automatically detects:
- Language (TypeScript/JavaScript/Python/Go/Rust)
- Framework(s) (Next.js, Express, Hono, Vue, Svelte, etc.)
- Database (Postgres, MongoDB, SQLite, MySQL, Redis)
- ORM (Prisma, Drizzle, TypeORM, Mongoose)
- Auth (Better-Auth, Clerk, NextAuth, Auth0, Lucia)
- Package Manager (npm, pnpm, bun, yarn)
- Runtime (Node, Bun, Deno)
- API style (tRPC, GraphQL, REST, oRPC)
- Testing frameworks (Jest, Vitest, Mocha, Playwright)
- Build tools (Vite, Webpack, esbuild, Turborepo)

**Created Files:**

```
.task-o-matic/
├── config.json       # AI configuration
├── stack.json        # Cached stack detection (used by all AI operations)
├── mcp.json          # Context7 configuration
├── tasks/            # Task storage
├── prd/              # PRD storage
├── logs/             # Operation logs
└── docs/             # Documentation
```

**Examples:**
```bash
# Basic attach (auto-detect stack)
task-o-matic init attach

# With full analysis (TODOs, features, structure)
task-o-matic init attach --analyze

# Dry run to preview detection
task-o-matic init attach --dry-run

# Re-detect after stack changes
task-o-matic init attach --redetect

# With custom AI provider
task-o-matic init attach --ai-provider openrouter --ai-model anthropic/claude-3.5-sonnet
```

---

## config

Manage task-o-matic configuration.

### config get-ai-config

Get the current AI configuration.

```bash
task-o-matic config get-ai-config
```

### config set-ai-provider

Set the AI provider and model.

```bash
task-o-matic config set-ai-provider <provider> [model]
```

**Arguments:**
- `provider` - AI provider (openrouter, anthropic, openai, custom URL)
- `model` - Model name (optional)

**Examples:**
```bash
task-o-matic config set-ai-provider openrouter xiaomi/mimo-v2-flash:free
task-o-matic config set-ai-provider anthropic claude-3-5-sonnet-20241022
task-o-matic config set-ai-provider custom https://api.example.com
```

### config info

Get information about the current task-o-matic project.

```bash
task-o-matic config info
```

---

## prd

Manage PRDs and generate tasks.

### prd create

Generate PRD(s) from a product description.

```bash
task-o-matic prd create [options] <description>
```

**Options:**

| Option | Description |
|--------|-------------|
| `--output <file>` | Output file path |
| `--stream` | Show streaming AI output |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |
| `--ai-key <key>` | AI API key override |
| `--ai-provider-url <url>` | AI provider URL override |

### prd generate

Generate a PRD from an existing codebase (reverse-engineering).

```bash
task-o-matic prd generate [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--from-codebase` | Analyze the current project and generate a PRD (default) |
| `--output <filename>` | Output filename (default: current-state.md) |
| `--ai <model>` | AI model to use (format: provider:model) |
| `--stream` | Enable streaming output |
| `--tools` | Enable filesystem tools for deeper analysis |
| `--json` | Output result as JSON |

### prd combine

Combine multiple PRD files into a master PRD.

```bash
task-o-matic prd combine [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--files <paths>` | Comma-separated list of PRD files |
| `--output <file>` | Output file path |
| `--stream` | Show streaming AI output |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |

### prd parse

Parse a PRD file into structured tasks.

```bash
task-o-matic prd parse [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--file <path>` | Path to PRD file |
| `--ai <models...>` | AI model(s) to use. Format: [provider:]model[;reasoning[=budget]] |
| `--combine-ai <provider:model>` | AI model to combine multiple parsed results |
| `--prompt <prompt>` | Override prompt |
| `--message <message>` | User message |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |
| `--ai-key <key>` | AI API key override |
| `--ai-provider-url <url>` | AI provider URL override |
| `--ai-reasoning <tokens>` | Enable reasoning for OpenRouter models (max reasoning tokens) |
| `--stream` | Show streaming AI output during parsing |
| `--tools` | Enable filesystem tools for project analysis |

**Examples:**
```bash
# Basic parse
task-o-matic prd parse --file prd.md

# With streaming and reasoning
task-o-matic prd parse --file prd.md --stream --ai-reasoning 4000

# Multiple models
task-o-matic prd parse --file prd.md --ai openrouter:model1 openrouter:model2 --combine-ai openrouter:combine-model
```

### prd rework

Rework a PRD based on user feedback.

```bash
task-o-matic prd rework [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--file <path>` | Path to PRD file |
| `--feedback <feedback>` | Feedback for rework |
| `--output <file>` | Output file path |
| `--stream` | Show streaming AI output |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |

### prd question

Generate clarifying questions for a PRD.

```bash
task-o-matic prd question [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--file <path>` | Path to PRD file |
| `--stream` | Show streaming AI output |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |

### prd refine

Refine PRD by answering clarifying questions.

```bash
task-o-matic prd refine [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--file <path>` | Path to PRD file |
| `--output <file>` | Output file path |
| `--stream` | Show streaming AI output |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |

**Interactive flow:**
1. AI generates clarifying questions
2. User answers each question
3. AI refines PRD based on answers

### prd get-stack

Suggest optimal technology stack based on PRD analysis.

```bash
task-o-matic prd get-stack [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--file <path>` | Path to PRD file (optional, uses current PRD if not specified) |
| `--stream` | Show streaming AI output |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |

---

## tasks

Manage tasks.

### tasks list

List all tasks.

```bash
task-o-matic tasks list [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--status <status>` | Filter by status (todo/in-progress/completed) |
| `--tag <tag>` | Filter by tag |
| `--json` | Output as JSON |

### tasks create

Create a new task with AI enhancement using Context7.

```bash
task-o-matic tasks create [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--title <title>` | Task title |
| `--content <content>` | Task content/description |
| `--status <status>` | Initial status |
| `--tags <tags>` | Comma-separated tags |
| `--parent <id>` | Parent task ID |
| `--ai-enhance` | Enhance with AI using Context7 |
| `--stream` | Show streaming AI output |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |

**Examples:**
```bash
# Manual creation
task-o-matic tasks create --title "Add auth" --content "Implement OAuth2"

# With AI enhancement
task-o-matic tasks create --title "Add auth" --ai-enhance --stream
```

### tasks show

Show detailed information about a task.

```bash
task-o-matic tasks show [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--json` | Output as JSON |

### tasks update

Update an existing task.

```bash
task-o-matic tasks update [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--title <title>` | New title |
| `--content <content>` | New content |
| `--status <status>` | New status |

### tasks delete

Delete a task.

```bash
task-o-matic tasks delete [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--force` | Skip confirmation |

### tasks status

Set task status.

```bash
task-o-matic tasks status [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--status <status>` | New status (todo/in-progress/completed) |

**Examples:**
```bash
task-o-matic tasks status --task-id 1 --status in-progress
task-o-matic tasks status --task-id 1 --status completed
```

### tasks add-tags

Add tags to a task.

```bash
task-o-matic tasks add-tags [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--tags <tags>` | Comma-separated tags to add |

### tasks remove-tags

Remove tags from a task.

```bash
task-o-matic tasks remove-tags [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--tags <tags>` | Comma-separated tags to remove |

### tasks plan

Create detailed implementation plan for a task or subtask.

```bash
task-o-matic tasks plan [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--subtask-id <id>` | Subtask ID |
| `--stream` | Show streaming AI output |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |
| `--reasoning <tokens>` | Enable reasoning tokens |

### tasks get-plan

View existing implementation plan for a task or subtask.

```bash
task-o-matic tasks get-plan [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--subtask-id <id>` | Subtask ID |

### tasks list-plan

List all available implementation plans.

```bash
task-o-matic tasks list-plan
```

### tasks delete-plan

Delete implementation plan for a task.

```bash
task-o-matic tasks delete-plan [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--subtask-id <id>` | Subtask ID |

### tasks set-plan

Set implementation plan for a task.

```bash
task-o-matic tasks set-plan [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--subtask-id <id>` | Subtask ID |
| `--plan <file>` | Plan file path |

### tasks enhance

Enhance an existing task with AI using Context7 documentation.

```bash
task-o-matic tasks enhance [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID to enhance |
| `--all` | Enhance all existing tasks |
| `--status <status>` | Filter tasks by status (todo/in-progress/completed) |
| `--tag <tag>` | Filter tasks by tag |
| `--dry` | Preview what would be enhanced without making changes |
| `--force` | Skip confirmation prompt for bulk operations |
| `--stream` | Show streaming AI output during enhancement |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |
| `--ai-key <key>` | AI API key override |
| `--ai-provider-url <url>` | AI provider URL override |
| `--reasoning <tokens>` | Enable reasoning for OpenRouter models (max reasoning tokens) |

**Examples:**
```bash
# Enhance specific task
task-o-matic tasks enhance --task-id 1 --stream

# Enhance all todo tasks
task-o-matic tasks enhance --all --status todo --stream

# Dry run first
task-o-matic tasks enhance --all --dry
```

### tasks split

Split a task into smaller subtasks using AI.

```bash
task-o-matic tasks split [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID to split |
| `--all` | Split all existing tasks that don't have subtasks |
| `--status <status>` | Filter tasks by status (todo/in-progress/completed) |
| `--tag <tag>` | Filter tasks by tag |
| `--dry` | Preview what would be split without making changes |
| `--force` | Skip confirmation prompt for bulk operations |
| `--stream` | Show streaming AI output during breakdown |
| `--ai-provider <provider>` | AI provider override |
| `--ai-key <key>` | AI API key override |
| `--ai-provider-url <url>` | AI provider URL override |
| `--ai <models...>` | AI model(s) to use. Format: [provider:]model[;reasoning[=budget]] |
| `--combine-ai <provider:model>` | AI model to combine multiple split results |
| `--reasoning <tokens>` | Enable reasoning for OpenRouter models (max reasoning tokens) |
| `--tools` | Enable filesystem tools for project analysis |

**Examples:**
```bash
# Split specific task
task-o-matic tasks split --task-id 1 --stream

# Split all tasks
task-o-matic tasks split --all --stream --reasoning 4000

# Dry run
task-o-matic tasks split --all --dry
```

### tasks document

Analyze and fetch documentation for a task using AI with Context7.

```bash
task-o-matic tasks document [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--stream` | Show streaming AI output |

### tasks get-documentation

Get existing documentation for a task.

```bash
task-o-matic tasks get-documentation [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |

### tasks add-documentation

Add documentation to a task from a file.

```bash
task-o-matic tasks add-documentation [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--file <path>` | Documentation file path |

### tasks execute

Execute a task using an external coding assistant.

```bash
task-o-matic tasks execute [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID to execute |
| `--tool <tool>` | External tool (opencode/claude/gemini/codex) |
| `--model <model>` | Model to force for execution |
| `--message <message>` | Custom message to send to the tool |
| `--continue-session` | Continue the last session (for error feedback) |
| `--auto-commit` | Automatically commit changes after task |
| `--plan` | Generate an implementation plan before execution |
| `--plan-model <model>` | Model/executor to use for planning |
| `--review-plan` | Pause for human review of the plan |
| `--review` | Run AI review after execution |
| `--review-model <model>` | Model/executor to use for review |

### tasks execute-loop

Execute multiple tasks in a loop with retry logic and verification.

```bash
task-o-matic tasks execute-loop [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--status <status>` | Filter tasks by status (todo/in-progress/completed) |
| `--tag <tag>` | Filter tasks by tag |
| `--ids <ids>` | Comma-separated list of task IDs to execute |
| `--tool <tool>` | External tool to use (opencode/claude/gemini/codex) |
| `--max-retries <number>` | Maximum number of retries per task |
| `--try-models <models>` | Progressive model/executor configs for each retry |
| `-m, --model <model>` | Model to force for execution |
| `--verify <command>` | Verification command to run after each task (can be used multiple times) |
| `--validate <command>` | Alias for --verify |
| `--message <message>` | Custom message to send to the tool (overrides task plan) |
| `--continue-session` | Continue the last session (for error feedback) |
| `--auto-commit` | Automatically commit changes after each task |
| `--plan` | Generate an implementation plan before execution |
| `--plan-model <model>` | Model/executor to use for planning |
| `--plan-tool <tool>` | Tool/Executor to use for planning |
| `--review-plan` | Pause for human review of the plan |
| `--review` | Run AI review after execution |
| `--review-model <model>` | Model/executor to use for review |
| `--include-completed` | Include already-completed tasks in execution |
| `--include-prd` | Include PRD content in execution context |
| `--notify <target>` | Notify on completion via URL or command (can be used multiple times) |
| `--dry` | Show what would be executed without running it |

**Examples:**
```bash
# Execute all todo tasks
task-o-matic tasks execute-loop --status todo

# With verification
task-o-matic tasks execute-loop --verify "bun run test" --verify "bun run type-check"

# With planning and review
task-o-matic tasks execute-loop --plan --review-plan --review

# Progressive model escalation
task-o-matic tasks execute-loop --try-models "gpt-4o-mini,gpt-4o,claude:sonnet-4"
```

### tasks subtasks

List subtasks for a task.

```bash
task-o-matic tasks subtasks [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--task-id <id>` | Task ID |
| `--json` | Output as JSON |

### tasks tree

Display hierarchical task tree.

```bash
task-o-matic tasks tree [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--json` | Output as JSON |

### tasks get-next

Get the next task to work on (defaults to hierarchical order).

```bash
task-o-matic tasks get-next [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--status <status>` | Filter by status |
| `--tag <tag>` | Filter by tag |

---

## workflow

Interactive workflow for complete project setup and task management.

```bash
task-o-matic workflow [options]
```

**Options:**

| Option | Description |
|--------|-------------|
| `--stream` | Show streaming AI output |
| `--ai-provider <provider>` | AI provider override |
| `--ai-model <model>` | AI model override |
| `--ai-key <key>` | AI API key override |
| `--ai-provider-url <url>` | AI provider URL override |
| `--skip-all` | Skip all optional steps (use defaults) |
| `--auto-accept` | Auto-accept all AI suggestions |
| `--config-file <path>` | Load workflow options from JSON file |
| `--skip-init` | Skip initialization step |
| `--project-name <name>` | Project name |
| `--init-method <method>` | Initialization method: quick, custom, ai |
| `--project-description <desc>` | Project description for AI-assisted init |
| `--use-existing-config` | Use existing configuration if found |
| `--frontend <framework>` | Frontend framework |
| `--backend <framework>` | Backend framework |
| `--database <db>` | Database choice |
| `--auth` | Include authentication |
| `--no-auth` | Exclude authentication |
| `--bootstrap` | Bootstrap with Better-T-Stack |
| `--no-bootstrap` | Skip bootstrapping |
| `--include-docs` | Include Task-O-Matic documentation in new project |
| `--no-include-docs` | Skip including documentation |
| `--skip-prd` | Skip PRD definition |
| `--prd-method <method>` | PRD method: upload, manual, ai, skip |
| `--prd-file <path>` | Path to existing PRD file |
| `--prd-description <desc>` | Product description for AI-assisted PRD |
| `--prd-content <content>` | Direct PRD content |
| `--prd-multi-generation` | Generate multiple PRDs and compare |
| `--skip-prd-multi-generation` | Skip PRD multi-generation |
| `--prd-multi-generation-models <models>` | Comma-separated list of models for multi-generation |
| `--prd-combine` | Combine generated PRDs into a master PRD |
| `--skip-prd-combine` | Skip PRD combination |
| `--prd-combine-model <model>` | Model to use for combining PRDs |
| `--skip-stack-suggestion` | Skip stack suggestion step |
| `--suggest-stack-from-prd [path]` | Get stack from PRD |
| `--skip-bootstrap` | Skip bootstrap step |
| `--skip-prd-question-refine` | Skip PRD question/refine step |
| `--prd-question-refine` | Use question-based PRD refinement |
| `--prd-answer-mode <mode>` | Who answers questions: user, ai |
| `--prd-answer-ai-provider <provider>` | AI provider for answering |
| `--prd-answer-ai-model <model>` | AI model for answering |
| `--prd-answer-ai-reasoning` | Enable reasoning for AI answering model |
| `--skip-refine` | Skip PRD refinement |
| `--refine-method <method>` | Refinement method: manual, ai, skip |
| `--refine-feedback <feedback>` | Feedback for AI refinement |
| `--skip-generate` | Skip task generation |
| `--generate-method <method>` | Generation method: standard, ai |
| `--generate-instructions <instructions>` | Custom task generation instructions |
| `--skip-split` | Skip task splitting |
| `--split-tasks <ids>` | Comma-separated task IDs to split |
| `--split-all` | Split all tasks |
| `--split-method <method>` | Split method: interactive, standard, custom |
| `--split-instructions <instructions>` | Custom split instructions |
| `--execute` | Execute generated tasks immediately |
| `--execute-concurrency <number>` | Number of concurrent tasks |
| `--no-auto-commit` | Disable auto-commit during execution |
| `--execute-tool <tool>` | Executor tool |
| `--execute-model <model>` | Model override for execution |
| `--execute-max-retries <number>` | Max retries per task |
| `--execute-plan` | Enable planning phase |
| `--execute-plan-model <model>` | Model for planning |
| `--execute-review` | Enable review phase |
| `--execute-review-model <model>` | Model for review |
| `--verify <command>` | Verification command (can be used multiple times) |
| `--validate <command>` | Alias for --verify |
| `--try-models <models>` | Progressive model/executor configs |

---

## prompt

Build AI service prompts with variable replacement for external tools.

```bash
task-o-matic prompt [options] [name]
```

**Arguments:**
- `name` - Prompt name

**Options:**

| Option | Description |
|--------|-------------|
| `--var <key=value>` | Variable to replace (can be used multiple times) |
| `--output <file>` | Output file |
| `--list` | List available prompts |

---

## install

Install task-o-matic documentation and agent guides into current project.

```bash
task-o-matic install [options] <target>
```

**Arguments:**
- `target` - Installation target

**Options:**

| Option | Description |
|--------|-------------|
| `--docs` | Install documentation |
| `--agents` | Install agent guides |

---

## Global Options

These options can be used with any command:

| Option | Description |
|--------|-------------|
| `-v, --verbose` | Enable verbose logging |
| `-V, --version` | Output the version number |
| `-h, --help` | Display help for command |

---

## Environment Variables

| Variable | Description |
|----------|-------------|
| `AI_PROVIDER` | Default AI provider |
| `AI_MODEL` | Default AI model |
| `OPENROUTER_API_KEY` | OpenRouter API key |
| `ANTHROPIC_API_KEY` | Anthropic API key |
| `OPENAI_API_KEY` | OpenAI API key |
| `CONTEXT7_API_KEY` | Context7 API key |
