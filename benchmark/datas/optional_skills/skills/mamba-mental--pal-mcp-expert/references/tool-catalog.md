# Complete Tool Reference

## Core Tools (Always Enabled)

### chat
Multi-model conversation with code generation support.
- **Parameters**: model, prompt, continuation_id, absolute_file_paths, working_directory_absolute_path, images, temperature, thinking_mode
- **Code Generation**: GPT-5-Pro/Gemini Pro generate complete implementations
- **Context Revival**: Supports continuation_id across Claude resets

### thinkdeep  
Extended reasoning with systematic investigation.
- **Confidence Tracking**: exploring → low → medium → high → very_high → almost_certain → certain
- **Step Management**: step, step_number, total_steps, next_step_required, findings, hypothesis
- **Best For**: Complex debugging, architecture decisions, edge case analysis

### planner
Interactive project planning with revision support.
- **Branching**: branch_from_step, branch_id for alternative paths
- **Revision**: is_step_revision, revises_step_number
- **Adaptive**: more_steps_needed extends beyond initial estimate

### consensus
Multi-model expert opinions with stance steering.
- **Stance Options**: "for", "against", "neutral"
- **Custom Prompts**: stance_prompt for specific arguments
- **Models Array**: [{model, stance, stance_prompt}, ...]
- **Example**: Debate microservices vs monolith with opposing stances

### clink (CLI + Link)
Spawn isolated CLI subagents without context pollution.
- **Supported CLIs**: claude, codex, gemini
- **Roles**: default, codereviewer, planner
- **Context Isolation**: Subagent explores full codebase, returns only results
- **Usage**: "clink with cli_name='codex' role='codereviewer' to audit auth/"

## Advanced Workflow Tools

### codereview
Systematic code review with validation.
- **Review Types**: full, security, performance, quick
- **Validation**: external (2 steps: analysis+summary) or internal (1 step)
- **Severity Filter**: critical, high, medium, low, all
- **Standards**: Optional coding standards to enforce

### precommit
Git change validation before commits.
- **Diff Analysis**: compare_to (branch/tag/commit), include_staged, include_unstaged
- **Validation Types**: external (max 3 steps) or internal (1 step)
- **Security**: Checks for secrets, validates test coverage

### debug
Root cause analysis with hypothesis testing.
- **Confidence-Based**: exploring → certain (certain blocks external validation)
- **Valid Outcomes**: "No bug found" is acceptable result
- **Hypothesis Evolution**: Revise theory as evidence emerges

## Specialized Tools (Disabled by Default)

### analyze (DISABLED)
Comprehensive codebase analysis.
- **Types**: architecture, performance, security, quality, general
- **Output**: summary, detailed, actionable
- **Enable**: Remove from DISABLED_TOOLS env var

### refactor (DISABLED)
Code smell detection and improvement opportunities.
- **Types**: codesmells, decompose, modernize, organization
- **Confidence**: incomplete → partial → complete
- **Style Guide**: style_guide_examples for reference patterns

### testgen (DISABLED)
Generate comprehensive test suites.
- **Focus**: Edge cases, boundary conditions, failure modes
- **Framework-Specific**: Adapts to project test framework

### tracer (DISABLED)
Execution flow or dependency mapping.
- **Modes**: precision (execution), dependencies (structure), ask (prompt user)
- **Target**: Specific functions/modules to trace

### secaudit (DISABLED)
Security audit and vulnerability assessment.
- **Focus**: owasp, compliance, infrastructure, dependencies, comprehensive
- **Threat Levels**: low, medium, high, critical
- **Compliance**: SOC2, PCI DSS, HIPAA, GDPR, ISO 27001, NIST

### docgen (DISABLED)
Automated documentation generation.
- **Features**: Docstrings, inline comments, Big O complexity, call flow
- **Options**: comments_on_complex_logic, document_complexity, document_flow
- **Updates**: update_existing polishes outdated docs

## Utility Tools

### listmodels
Display all available models with intelligence scores and capabilities.

### version
Server version and configuration details.

### challenge
Critical analysis to prevent reflexive agreement. Triggers automatically when user questions answers.

### apilookup
Search current API/SDK documentation. Requires web search enabled.

## Global Parameters

### continuation_id (CRITICAL)
**Always reuse last received continuation_id** - maintains context across:
- Claude resets/compaction
- Different tools in same workflow
- Multi-session conversations

### File Paths
**Always absolute paths**:
- ✅ /home/user/project/src/auth.ts
- ❌ src/auth.ts (may fail)

### Temperature (0-1)
- 0: Deterministic
- 0.5: Balanced
- 1: Creative

### Thinking Modes
- minimal: Fast lightweight
- low: Basic reasoning
- medium: Standard
- high: Deep thinking  
- max: Maximum depth

### Working Directory
Required for code generation - where pal_generated.code is saved.

## Tool Configuration

### Environment Variables

**Disable Tools:**
```bash
DISABLED_TOOLS="analyze,refactor,testgen,secaudit,docgen,tracer"  # Default
DISABLED_TOOLS=""  # Enable all
DISABLED_TOOLS="testgen,docgen"  # Selective
```

**Conversation Settings:**
```bash
CONVERSATION_TIMEOUT_HOURS=5  # Thread retention
MAX_CONVERSATION_TURNS=20     # Exchange limit
```

**Model Restrictions:**
```bash
GOOGLE_ALLOWED_MODELS="flash,pro"
OPENAI_ALLOWED_MODELS="gpt-5.1-codex-mini,o4-mini"
```

**Force Override:**
```bash
FORCE_ENV_OVERRIDE=true  # .env takes precedence over system vars
```

**Logging:**
```bash
LOG_LEVEL=DEBUG  # Development
LOG_LEVEL=INFO   # Production
```
