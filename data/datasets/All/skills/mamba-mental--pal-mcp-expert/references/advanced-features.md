# Advanced Features & Usage Patterns

## Context Revival After Claude Resets (REVOLUTIONARY)

### The Problem PAL Solves
When Claude's context resets or compacts, traditional conversations lose all history. PAL maintains conversation context even after Claude's memory resets.

### How It Works
Other models (O3, Gemini, Flash) maintain **complete conversation history in memory** and can "remind" Claude of everything discussed in previous sessions.

### Usage Pattern

**Session 1:**
```
"Design a RAG system with gemini pro"
[Detailed discussion about architecture, vector stores, chunking strategies]
[Claude's context resets/compacts]
```

**Session 2:**
```
"Continue our RAG discussion with o3"
→ O3 receives the FULL history from Session 1
→ O3 reminds Claude of all architectural decisions
→ Conversation continues seamlessly
```

### Key Benefits
- **True persistence** across context boundaries
- **No information loss** when Claude resets
- **Seamless handoffs** between models
- **Multi-session workflows** maintained indefinitely

### Technical Architecture
- Conversation threads stored in server memory
- `continuation_id` links conversation across sessions
- Each model has access to complete thread history
- `CONVERSATION_TIMEOUT_HOURS` (default: 5) controls retention

### Configuration
```bash
# .env settings
CONVERSATION_TIMEOUT_HOURS=5  # Auto-purge after this time
MAX_CONVERSATION_TURNS=20     # Each exchange = 2 turns
```

### Best Practices
1. **Always reuse continuation_id** - this is the key to context revival
2. Let Claude reset naturally - other models will restore context
3. Use different models for different phases of long projects
4. Name your continuation flows meaningfully in prompts

---

## MCP 25K Token Limit Bypass

### The Limitation
MCP protocol has a 25,000 token limit for prompts and responses.

### PAL's Solution
Automatically works around this limitation for arbitrarily large prompts/responses to models like Gemini.

### Usage
**No special configuration needed** - PAL handles this transparently:
```
"Analyze this 50K token codebase with gemini pro"
→ PAL automatically chunks and manages the large context
→ Model receives complete information despite MCP limits
```

### What Gets Bypassed
- Large file analysis (50K+ tokens)
- Massive code generation (20K+ token responses)
- Comprehensive documentation requests
- Multi-file codebase analysis

---

## Vision Support

### Supported Models

**Gemini Models:**
- Flash: Up to 20MB total
- Pro: Up to 20MB total
- Excellent for: Diagrams, architecture analysis, UI mockups

**OpenAI Models:**
- O3/O4 series: Up to 20MB total  
- Strong for: Visual debugging, error screenshots

**Claude via OpenRouter:**
- Up to 5MB total
- Good for: Code screenshots, visual analysis

**Custom Models:**
- Up to 40MB maximum (abuse prevention)
- Support varies by model

### Usage Patterns

**Debug with Error Screenshots:**
```
"Use pal to debug this error with the stack trace screenshot and error.py"
```

**Architecture Analysis:**
```
"Analyze this system architecture diagram with gemini pro for bottlenecks"
```

**UI Review:**
```
"Chat with flash about this UI mockup - is the layout intuitive?"
```

**Code Review with Visual Context:**
```
"Review this authentication code along with the error dialog screenshot"
```

### Image Parameters
```javascript
images: [
  "/absolute/path/to/screenshot.png",
  "/absolute/path/to/diagram.jpg",
  "data:image/png;base64,iVBORw0KGgoAAAANS..."  // base64 also supported
]
```

### Best Practices
1. Use Gemini for diagram/architecture analysis (excellent visual understanding)
2. Use O3/O4 for debugging with screenshots
3. Keep images under 5MB each for best performance
4. Include context in prompt: "The screenshot shows the error at line 42"

---

## Web Search Integration

### Automatic Enhancement
PAL integrates web search to enhance responses with current information.

**Enabled by default** for all tools when web search is available in client.

### How It Works
1. Gemini analyzes whether web info would enhance response
2. Provides "Recommended Web Searches for Claude" section
3. Claude executes searches and incorporates findings
4. Live API/SDK documentation lookups during workflows

### Usage
**No special syntax needed** - happens automatically:
```
"Use chat with gemini pro to implement OAuth2 with the latest best practices"
→ Gemini recommends: "Search for OAuth2 2024 security recommendations"
→ Claude searches and incorporates current standards
→ Implementation uses latest practices
```

### When Web Search Activates
- API/SDK version queries
- Current best practices
- Breaking changes in libraries
- Security vulnerability checks
- Migration guides between versions

### Disable If Needed
If you don't want web search for a specific query:
```
"Analyze this code with gemini pro - no web search needed"
```

---

## Advanced Workflow Patterns

### Multi-Model Code Review → Planning → Implementation

**Step 1: Code Review**
```
"Use codereview with gemini pro to analyze auth/ directory"
→ continuation_id: "auth-refactor-001"
```

**Step 2: Planning**
```
"Use planner with continuation_id='auth-refactor-001' to plan the refactoring"
→ Planner receives full code review context
→ Creates actionable plan based on findings
```

**Step 3: Implementation**
```
"Use chat with gpt-5-pro and continuation_id='auth-refactor-001' to implement step 1"
→ GPT-5 Pro receives code review + plan
→ Generates implementation
```

**Step 4: Validation**
```
"Use precommit with continuation_id='auth-refactor-001' to validate changes"
→ Validates against original review findings
```

### Collaborative Debates

**Decision Making:**
```
"Use consensus with models:
  - {model: 'gpt-5-pro', stance: 'for', stance_prompt: 'Argue for microservices'}
  - {model: 'gemini-pro', stance: 'against', stance_prompt: 'Defend modular monolith'}
  - {model: 'o3', stance: 'neutral'}
to decide our architecture"
→ continuation_id: "architecture-decision-001"
```

**Implementation:**
```
"Continue with clink gemini - implement the recommended architecture with continuation_id='architecture-decision-001'"
→ Gemini receives full debate context
→ Starts implementation immediately
```

### CLI Subagent Isolation

**Heavy Task Offloading:**
```
"Use clink with cli_name='codex' role='codereviewer' to audit the entire auth module"
→ Codex spawns in fresh context
→ Explores codebase without polluting your context
→ Returns only final audit report
→ Your session stays clean
```

**Parallel Investigations:**
```
Session A (main): "Design the API interface"
Session B (subagent): clink codex to analyze performance of current database queries
Session C (subagent): clink gemini to research React 19 migration strategy

→ All subagents return results to main session
→ Main context window stays focused on design
```

### Cross-Tool Context Threading

**Example: Security → Performance → Implementation**
```
1. "Use secaudit with gemini pro on auth/"
   → continuation_id: "auth-improvements"
   
2. "Use analyze with continuation_id='auth-improvements' to check performance"
   → Receives security context
   → Adds performance analysis
   
3. "Use chat with gpt-5-pro and continuation_id='auth-improvements' to fix both"
   → Receives security + performance context
   → Implements comprehensive solution
```

---

## Code Generation Workflow

### How PAL Handles Generated Code

**Step 1: Generation**
```
"Use chat with gpt-5-pro to implement the user dashboard"
working_directory_absolute_path: "/home/user/myapp"
```

**Step 2: Storage**
PAL saves generated code to:
```
/home/user/myapp/pal_generated.code
```

**Step 3: Review Instructions**
Your CLI receives instructions to:
1. Review generated code systematically
2. Apply implementation step by step
3. Verify each component

**Step 4: Application**
Claude (or your CLI) continues from context:
1. Reads `pal_generated.code`
2. Applies implementation
3. Runs tests/validation

### Best Practices
1. Always provide `working_directory_absolute_path` for code generation
2. Review generated code before applying
3. Use continuation_id to maintain context during implementation
4. Validate with precommit before committing

---

## Intelligence Scoring & Auto Mode

### How Auto Mode Works
When `DEFAULT_MODEL=auto`, Claude selects best model per subtask based on:
- Intelligence scores (configured per model)
- Task complexity
- Required capabilities

### Intelligence Score Ranges
- **18-20**: Highest reasoning (GPT-5 Pro, Gemini 3.0 Pro, O3)
- **15-17**: Strong capabilities (GPT-5.1-Codex, Gemini Pro)
- **10-14**: Efficient models (Flash, GPT-4o-mini)
- **5-9**: Fast lightweight models

### Model Selection Examples
```
"Debug this complex race condition" 
→ Auto selects: O3 or GPT-5 Pro (score 19-20)

"Format this JSON nicely"
→ Auto selects: Flash (score 12, fast)

"Implement OAuth2 flow with security best practices"
→ Auto selects: GPT-5-Pro or Gemini 3.0 Pro (score 19-20)
```

### Configuration
Edit `conf/gemini_models.json` or `conf/openai_models.json`:
```json
{
  "model_name": "gpt-5-pro",
  "intelligence_score": 19,
  "allow_code_generation": true
}
```

### Override Auto Mode
Per-request override still works:
```
"Use gemini flash to quickly format this code"
→ Ignores auto mode, uses Flash
```

---

## Environment-Based Restrictions

### Use Cases
- **Development**: Enable all models for experimentation
- **Production**: Restrict to cost-effective models
- **High-Performance**: Enable only top-tier models

### Configuration

**Gemini Restrictions:**
```bash
GOOGLE_ALLOWED_MODELS="flash,pro"  # Only these Gemini models
```

**OpenAI Restrictions:**
```bash
OPENAI_ALLOWED_MODELS="gpt-5.1-codex-mini,gpt-5-mini,o4-mini"
```

**Example Configs:**

**Development (Full Access):**
```bash
DEFAULT_MODEL=auto
GEMINI_API_KEY=your-key
OPENAI_API_KEY=your-key
GOOGLE_ALLOWED_MODELS=flash,pro,flash-8b
OPENAI_ALLOWED_MODELS=gpt-5.1-codex-mini,gpt-5-mini,o4-mini
LOG_LEVEL=DEBUG
CONVERSATION_TIMEOUT_HOURS=1
```

**Production (Cost Control):**
```bash
DEFAULT_MODEL=auto
GEMINI_API_KEY=your-key
OPENAI_API_KEY=your-key
GOOGLE_ALLOWED_MODELS=flash  # Only cheapest Gemini
OPENAI_ALLOWED_MODELS=gpt-5.1-codex-mini,o4-mini
LOG_LEVEL=INFO
CONVERSATION_TIMEOUT_HOURS=3
```

**High Performance (Best Models Only):**
```bash
DEFAULT_MODEL=auto
GEMINI_API_KEY=your-key
OPENAI_API_KEY=your-key
GOOGLE_ALLOWED_MODELS=pro
OPENAI_ALLOWED_MODELS=gpt-5-pro,o3
LOG_LEVEL=INFO
```

---

## Tool Timeout Configuration

### MCP Client Defaults
Most MCP clients default to **short timeouts** (30-60 seconds).

### Recommended Setting
**20 minutes (1200 seconds)** for PAL operations.

### Why Longer Timeouts?
- thinkdeep: Multi-step investigation (2-10 minutes)
- consensus: Sequential model consultation (5-15 minutes)  
- codereview: Comprehensive analysis (3-10 minutes)
- analyze: Large codebase analysis (5-20 minutes)

### Configuration

**Claude Code (.mcp.json):**
Setup script auto-configures:
```json
{
  "mcpServers": {
    "pal": {
      "tool_timeout_sec": 1200
    }
  }
}
```

**Claude Desktop (settings.json):**
```json
{
  "mcpServers": {
    "pal": {
      "timeout": 1200000  // milliseconds
    }
  }
}
```

**Manual Override:**
If setup script didn't configure, add timeout manually to your MCP config.

---

## Force .env Override (Multi-Client Conflicts)

### The Problem
Different AI tools (Claude Code, Desktop, Codex) may pass conflicting or cached environment variables that override each other.

### Solution: FORCE_ENV_OVERRIDE
```bash
# .env
FORCE_ENV_OVERRIDE=true
```

### Behavior

**Enabled (true):**
- .env file values take absolute precedence
- Prevents MCP clients from passing outdated/cached API keys
- Ensures consistent configuration across different AI tools
- Solves environment variable conflicts

**Disabled (false - default):**
- System environment variables take precedence
- Standard behavior for production deployments
- Respects container orchestrator configurations
- Works with CI/CD pipeline injections

### When to Enable
- Running multiple AI tools (Claude Desktop + Code + Codex)
- Experiencing API key conflicts
- Tools using different/cached credentials
- Development environment with frequent key rotation

### When to Disable
- Production deployments
- Docker/Kubernetes environments
- CI/CD pipelines
- Single AI tool usage
