# Architecture Patterns

Prompt architecture patterns for different deployment contexts. Includes agent
design, tool-calling, RAG, and multi-agent patterns. Used by Craft (Mode A)
for architecture selection.

---

## Single-Turn Patterns

Patterns for one-shot API calls, batch processing, and stateless completions.

**4-Block Pattern** (most common):
```
<context>
{Role definition, background knowledge, relevant state}
</context>

<task>
{What the model should do — the core instruction}
</task>

<constraints>
{Rules, limitations, edge case handling}
</constraints>

<output_format>
{Expected output structure, examples}
</output_format>
```
Note: This is a community synthesis of effective prompt structure from OpenAI's
guidance, not official OpenAI terminology. Widely adopted across model families.

- When to use: API calls, single-turn completions, batch processing
- Model-class note: Works on both instruction-following and reasoning models.
  For reasoning models, keep constraints minimal — excessive structure
  constrains internal reasoning.

**Minimal Pattern** (for simple tasks):
```
<task>{Clear, complete instruction}</task>
```
- When to use: Simple tasks where the model needs no additional context
- Often sufficient for reasoning models on well-defined problems
- Start here; escalate to 4-Block only when output quality is insufficient

**Task Delegation Pattern** (for deep research, autonomous agents, batch processing):
A 4-block variant where the user sends a single prompt to guide an extended autonomous process. Key differences from standard single-turn: (1) scope boundaries are critical — explicitly state what is in/out of scope, (2) output structure must be specified upfront since there are no mid-task corrections, (3) include citation/source requirements if applicable, (4) specify depth vs. breadth trade-off.

---

## Multi-Turn Patterns

Patterns for chat applications, multi-step workflows, and persistent sessions.

**Conversation-Aware Pattern:**
- Inject relevant state at the start of each turn (do not rely on the model
  tracking all prior turns perfectly)
- Use XML tags to delineate injected context: `<conversation_state>`,
  `<relevant_history>`
- Implement conversation compaction for long sessions (GPT-5 compaction
  endpoint, or manual summarization)
- Design for context rot: see context-management.md for context rot mitigation
  strategies

**State Management:**
See context-management.md for state management and compaction patterns.

---

## Agent Patterns

Patterns for autonomous agents that reason, plan, and take actions via tools.

**ReAct Agent Pattern** (Reason + Act):
```
<system>
You are an agent that solves tasks by reasoning and taking actions.

{3-instruction pattern — HIGHEST IMPACT single change for agent prompts:}

1. PERSISTENCE: Keep working until the task is fully complete. Only stop when
   you are confident the task is done or you need user input. Do not stop at
   the first sign of difficulty.

2. TOOL USE: Use your tools to verify your work. Never guess at file contents,
   command outputs, or system state when you can check directly. Prefer
   evidence over assumption.

3. PLANNING: Before starting, think about your approach. Break complex tasks
   into steps. After each step, assess progress and adjust your plan if needed.

Available tools:
{tool definitions}

When you encounter an error, try to understand and fix it rather than
giving up. If you are stuck after 3 attempts, explain the situation and
ask for guidance.
</system>
```
Source: OpenAI GPT-4.1 guide reported ~20% SWE-bench improvement from the
3-instruction pattern. Continued in GPT-5 guide.

**Plan-Then-Execute Pattern** (Cline-style):
- Phase 1 (Plan): Model creates a step-by-step plan, presented for user
  approval
- Phase 2 (Execute): Model follows the approved plan, reporting progress
- Benefits: User oversight, reduced wasted effort on wrong approaches
- Implementation: Use mode flags or separate system prompts for each phase
- Combine with ReAct for execution — the plan provides structure, ReAct
  provides persistence and tool verification

**Modular Conditional Prompt Architecture** (Claude Code style):
- Core identity fragment (always loaded)
- Tool instruction fragments (loaded per available tools)
- Domain rule fragments (loaded per detected context)
- Task-specific fragments (loaded per current task)
- Claude Code uses 110+ conditional fragments; all production agents use this
  pattern at scale
- Benefits: Smaller per-request token cost, targeted instructions, easier
  maintenance, independent versioning of each fragment
- Implementation: Compose the system prompt at runtime from a fragment registry
  based on the current request context

---

## Tool-Calling Patterns

Patterns for designing tool definitions, guiding tool selection, and handling
tool errors.

**Effective Tool Descriptions:**
- Write tool descriptions from the model's perspective: "Use this tool to..."
  not "This tool can..."
- Include specific examples of when to use and when NOT to use each tool
- Describe expected inputs with types, constraints, and examples
- Describe expected outputs and error conditions
- Avoid ambiguous overlap between tools — if two tools could serve the same
  purpose, explain the distinction

**Parameter Design:**
- Use enums for parameters with a known set of valid values
- Provide default values where sensible
- Include example values in parameter descriptions
- Avoid overloading parameters — one parameter, one purpose
- Mark optional parameters explicitly; describe behavior when omitted

**System Prompt Guidance for Tool Selection:**
```
<tool_usage_guidelines>
- Before answering from memory, check if a tool can provide a more accurate
  answer
- Prefer specific tools over general ones (use read_file over bash cat)
- Chain tools when needed: search → read → analyze
- If a tool call fails, try an alternative approach before retrying the same
  call
- Maximum 3 retries per tool, then explain the issue and ask for guidance
</tool_usage_guidelines>
```

**Error Message Design:**
- Tool errors should be actionable: include what went wrong and how to fix it
- Distinguish between user errors (bad input) and system errors (tool failure)
- Include the failed input in error messages for debugging
- Suggest the correct usage when the model passes invalid arguments

**Parallel vs. Sequential Calling:**
- Independent tool calls → parallel (faster, cheaper)
- Dependent tool calls → sequential (output of one feeds the next)
- Budget awareness: track approximate token usage across tool calls
- Instruct the model to batch independent calls in a single response when the
  API supports parallel tool calling

---

## RAG Prompting Patterns

Patterns for retrieval-augmented generation: grounding, citation, and
faithfulness enforcement.

**Grounding Instructions:**
```
<instructions>
Answer the user's question based ONLY on the provided documents below.
If the documents do not contain enough information to answer the question,
say "I don't have enough information to answer that question" and explain
what information is missing.
Do not use prior knowledge to supplement the documents.
</instructions>

<documents>
{retrieved chunks with metadata}
</documents>
```

**Citation Patterns:**
- Inline citations: "According to [Document Title, Section 2.3], ..."
- Footnote citations: "The revenue increased by 15%[1]." with references at end
- Require citations for every factual claim from the documents
- Choose the pattern that matches the output consumer — inline for humans,
  structured for downstream pipelines

**Chunk Formatting with Metadata:**
```
<document id="doc-1" source="quarterly-report-q3.pdf" page="12" relevance="0.92">
{chunk content}
</document>
```
- Include source metadata (title, page, date, relevance score) with each chunk
- Use delimiters between chunks — XML tags are the most reliable
- Order by relevance score (highest first) — models attend more to early content

**Faithfulness Enforcement:**
- Self-RAG: Model generates, then self-checks each claim against source
  documents
- Chain-of-Note: Model takes notes on each document before answering, citing
  which notes support the answer
- "I don't know" handling: Explicitly instruct the model on when and how to
  decline answering — vague instructions like "be accurate" are insufficient

**Position Effects:**
- Models attend more strongly to content at the beginning and end of context
  ("lost in the middle" effect)
- Place the most relevant documents first and last
- For critical information, consider repeating it or placing it in both
  positions
- Long retrieval sets (>20 chunks) are particularly susceptible — consider
  re-ranking and truncating to top-k

**Multi-Hop RAG:**
- For questions requiring synthesis across multiple documents, instruct the
  model to: (1) identify relevant facts from each document, (2) reason about
  connections between facts, (3) synthesize a final answer with citations to
  each source
- Decompose complex queries into sub-queries for better retrieval
- Consider iterative retrieval: first retrieval informs a refined query for
  second retrieval

---

## Multi-Agent Patterns

Patterns for systems with multiple cooperating or specialized agents.

**Orchestrator-Worker:**
- Lead agent decomposes task and delegates to specialized worker agents
- Each worker has a focused system prompt and limited tool access
- Lead synthesizes results
- Define clear input/output contracts between orchestrator and workers

**Security Architectures (6 patterns):**
1. Input validation agent → processing agent → output validation agent
2. Privileged inner agent + unprivileged outer agent (dual-LLM)
3. Human-in-the-loop approval for high-risk actions
4. Read-only agents for analysis, write-capable agents for execution
5. Role-based tool access (each agent gets only the tools it needs)
6. Audit logging agent observing all inter-agent communication

**MCP Integration:**
- MCP (Model Context Protocol) provides standardized tool and resource access
- Define MCP servers in agent configuration for consistent tool availability
- Use MCP resources for shared state across agents
- MCP spec (2025-11-25) standardizes: tools, resources, prompts, sampling

---

## Selection Heuristic

Match deployment context to the recommended architecture pattern. Start with
the simplest pattern that fits; escalate when requirements demand it.

| Deployment Context | Recommended Pattern | Key Consideration |
|-------------------|--------------------|--------------------|
| Simple API call | 4-Block or Minimal | Start minimal; add blocks as needed |
| Chat application | Multi-Turn with state management | Context rot; compaction strategy |
| Coding agent | ReAct + 3-instruction pattern | Persistence and tool verification |
| Plan-then-execute agent | Cline-style two-phase | User oversight and approval gates |
| RAG pipeline | Grounding + citation | Faithfulness enforcement |
| Multi-agent system | Orchestrator-Worker | Security architecture selection |
| Production agent (complex) | Modular conditional architecture | Maintainability and token efficiency |
| Tool-heavy agent | ReAct + tool selection guidance | Error handling and retry limits |
| Task delegation / research | 4-Block with scope + output emphasis | One-shot; scope precision critical; include citation and length guidance |
