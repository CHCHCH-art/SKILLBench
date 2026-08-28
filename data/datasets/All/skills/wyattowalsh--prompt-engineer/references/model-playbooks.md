# Model Playbooks

Model-family-specific guidance for prompt engineering. Each section includes a
"Last verified" date — verify against current official documentation before
applying recommendations older than 3 months.

## Claude (Anthropic) — Last verified: Feb 2026

### Claude 4.6 (Opus) / Claude 4.5 (Sonnet/Haiku)

- **Model class**: Reasoning (with extended thinking enabled) or
  Instruction-following (without).
- **Adaptive thinking**: Replaces the old `budget_tokens` parameter. The model
  automatically allocates thinking effort based on task complexity. Do not try
  to micromanage thinking — provide clear objectives and let the model reason.
- **Prefilled responses removed**: Attempting to prefill the assistant response
  returns a 400 error on Claude 4.x. This is a hard removal, not a soft
  deprecation. Do not use prefill patterns from Claude 3.x guides.
- **XML tags strongly preferred**: Claude has the strongest XML tag support of
  any model family. Use `<instructions>`, `<context>`, `<examples>`,
  `<output_format>`, `<constraints>`. Nest freely.
- **Scope Discipline blocks**: Use `<scope_discipline>` blocks to constrain
  behavior. "Only respond to questions about X. For anything else, say:
  'That's outside my scope.'" Prevents over-triggering on ambiguous inputs.
- **Over-prompting causes overtriggering**: Claude 4.x models are highly
  instruction-following. Excessive guardrails or negative instructions cause
  the model to be overly cautious and refuse valid requests. Less is more for
  constraints.
- **LaTeX is default for math**: Claude defaults to LaTeX formatting for
  mathematical expressions. If plain text math is needed, explicitly request
  it.
- **System prompt placement**: System prompt is a first-class concept. Place
  role definitions and persistent instructions in the system prompt, not in
  the first user message.
- **Multi-turn best practices**: Use `<turn_context>` or similar tags to inject
  relevant state at the start of each turn rather than relying on the model to
  track conversation history perfectly.

### Prompt Caching

**See `references/context-management.md` § Anthropic for full caching strategy.** Key: explicit breakpoints via `cache_control`, up to 4 per request, 5-minute TTL, 50-90% cost reduction.

### Claude Code / Agent Patterns

- Uses 110+ conditional prompt fragments loaded based on context.
- Modular architecture: core identity, tool instructions, domain rules,
  task-specific instructions — composed at runtime.
- Structured output via XML tags, not JSON mode.
- Tool result management: clear stale tool results to prevent context rot.
- Apply the 3-instruction pattern (persistence + tool-calling + planning) for
  agent loops.

---

## GPT (OpenAI) — Last verified: Feb 2026

### GPT-5.2 / GPT-4.1

- **Model class**: GPT-5 has reasoning mode (reasoning class) and standard mode
  (instruction-following). GPT-4.1 is instruction-following only.
- **4-block pattern**: Effective prompt structure: Context, Task, Constraints,
  Output format.
- **3-instruction pattern**: For agent prompts, the most impactful single change
  (~20% SWE-bench improvement per OpenAI GPT-4.1 guide, continued in GPT-5
  guide):
  1. Persistence instruction: "Keep going until the task is fully complete. Do
     not stop unless explicitly told."
  2. Tool-calling instruction: "Use tools to verify your work. Never guess when
     you can check."
  3. Planning instruction: "Plan your approach before starting. Revise the plan
     as you learn more."
- **Compaction endpoint**: GPT-5 series has a conversation compaction endpoint
  for managing long conversations. Summarizes prior turns while preserving key
  context. Use for multi-turn agents approaching context limits.
- **Responses API with reasoning persistence**: The `reasoning` parameter in the
  Responses API persists reasoning across turns. Tau-Bench improvement: 73.9%
  to 78.2%.
- **Meta-prompting support**: GPT models respond well to meta-prompts ("Generate
  the best prompt for this task"). Use for prompt automation workflows.
- **Structured outputs**: `response_format: { type: "json_schema" }` for
  guaranteed JSON conformance. Define schemas explicitly. Use for any pipeline
  requiring machine-parseable output.

### Prompt Caching

**See `references/context-management.md` § OpenAI for full caching strategy.** Key: automatic prefix caching, 1024-token minimum, 50% discount, keep prefixes byte-identical.

### Reasoning Models (o3, o4-mini)

- Native chain-of-thought — never add external CoT scaffolding. External "think
  step by step" actively degrades performance (Prompting Inversion — see
  `references/technique-catalog.md` § Thought Generation for full guidance).
- `reasoning_effort` parameter: low / medium / high. Match to task complexity.
- Provide constraints and objectives, not step-by-step instructions. Let the
  model determine its own reasoning path.
- Few-shot examples: 0-1 for format demonstration only.
- Longer system prompts can hurt performance — be concise. Trim to essentials.

---

## Gemini (Google) — Last verified: Feb 2026

### Gemini 3 / Gemini 2 Flash

- **Model class**: Gemini 3 with thinking enabled is reasoning class. Gemini 2
  Flash is instruction-following.
- **Constraints at end**: Place constraints and formatting requirements at the
  END of the prompt, not the beginning. Gemini models attend more strongly to
  late-positioned instructions. This is the single most important structural
  difference from other model families.
- **Temperature default 1.0**: Gemini defaults to temperature 1.0 (higher than
  other families). For deterministic tasks, explicitly set temperature to
  0.0-0.3. Forgetting this is a common source of inconsistency.
- **Thinking levels**: Gemini 3 supports thinking levels: off, low, medium,
  high. Maps to reasoning effort. Use low for simple tasks, high for complex
  reasoning. Off disables reasoning entirely.
- **Balanced prompting**: Google's guidance emphasizes balanced detail — enough
  context for the task, not so much that it overwhelms. Aligns with the
  Over-Specification Paradox heuristic.
- **Multi-modal strength**: Gemini has strong native multi-modal capabilities.
  For vision tasks, provide images inline with text context. Use detail-level
  hints where available.
- **Grounding with Google Search**: Gemini can be grounded with Google Search
  results. For RAG-like use cases, consider whether native grounding is
  sufficient before building custom RAG pipelines.
- **System instruction support**: Full system instruction support. Place
  persistent context in system instructions. Equivalent to system prompts in
  other families.

### Prompt Caching

**See `references/context-management.md` § Google for full caching strategy.** Key: context caching API, 32,768-token minimum, best for large stable contexts.

### Gemini Prompt Structure

Place content in this order for best results:

```
[System instruction]      ← role and persistent context
[Task description]        ← what to do
[Input content]           ← user data, retrieved docs
[Examples]                ← format demonstrations
[Constraints]             ← rules, formatting, output spec (END position)
```

---

## Llama (Meta) — Last verified: Feb 2026

### Llama 4

- **Model class**: Llama 4 has reasoning variants (reasoning class) and
  standard variants (instruction-following).
- **Short system prompts preferred**: Llama models perform best with concise
  system prompts. Long, detailed system prompts degrade Llama performance more
  than other model families. Keep system prompts under 500 tokens when
  possible.
- **Prefilled structure**: Llama supports assistant prefill (unlike Claude 4.x).
  Use to steer output format:
  ```json
  {"role": "assistant", "content": "```json\n"}
  ```
  This forces JSON output without relying on prompt instructions alone.
- **Structured output via constrained decoding**: When hosting Llama locally,
  use constrained decoding (grammar-based generation) for guaranteed format
  compliance. More reliable than prompt-based format instructions. Libraries:
  Outlines, llama.cpp grammars, vLLM guided decoding.
- **Chat template sensitivity**: Llama models are sensitive to chat template
  formatting. Use the official chat template for the specific Llama variant.
  Incorrect templates cause significant performance degradation. Verify the
  template matches the model revision.
- **Tool calling**: Llama 4 has native tool calling support. Define tools using
  the standard function-calling format. For older Llama variants, simulate
  tool calling with structured output patterns.

### Self-Hosted Considerations

- No provider-side caching — implement application-layer caching (semantic
  caching, KV cache reuse) yourself.
- Quantization affects instruction following: GPTQ/AWQ at 4-bit may degrade
  complex instruction adherence. Test prompt effectiveness at your target
  quantization level.
- Context window varies by variant: verify the max context for your specific
  model and quantization. Longer contexts may require RoPE scaling
  adjustments.
- Batch inference: group requests with similar prompt prefixes to maximize KV
  cache reuse across the batch.

### Llama Prompt Structure

Keep it lean — every token in the system prompt costs more on Llama than on
hosted API models:

```
[System prompt]           ← under 500 tokens, role + core rules only
[User message]            ← task + context + constraints combined
[Assistant prefill]       ← optional, steer format (e.g., "```json\n")
```

---

## Cross-Model Compatibility

### Conversion Matrix

| Feature | Claude | GPT | Gemini | Llama | Notes |
|---------|--------|-----|--------|-------|-------|
| System prompt | Native | Native | Native | Native | |
| XML tags | Strongest support | Good support | Good support | Good support | |
| Prefilled response | Removed (4.x) | Not supported | Not supported | Supported | Claude 3.x prefill prompts must be rewritten for 4.x — move format-steering to system prompt or XML output tags |
| Prompt caching | Explicit breakpoints | Automatic prefix | Explicit API | N/A (self-hosted) | Fundamentally different mechanisms — must redesign per provider |
| Structured output | XML patterns | JSON schema mode | JSON mode | Constrained decoding | Prompts relying on one mechanism must be restructured for another |
| Thinking/reasoning | Adaptive thinking | reasoning_effort | Thinking levels | Variant-dependent | Reasoning variants of ALL families: no external CoT scaffolding — verify model class before converting |
| Tool calling | Native | Native (parallel) | Native | Native (4.x) | |
| Multi-modal | Vision + docs | Vision + audio | Vision + audio + video | Vision (variant) | |
| Cache min tokens | 4,096 (Opus 4.5+, Haiku 4.5) / 1,024 (Sonnet, Opus 4/4.1) / 2,048 (Haiku 3/3.5) | 1,024 | 32,768 | N/A | |
| Cache TTL | 5 min | ~5-10 min | User-specified | N/A | |
| Prompt length sensitivity | Low | Low | Medium | High | Llama degrades fastest with verbose prompts; trim aggressively (aim for <500 system tokens) |
| Constraint placement | Inline/early | Inline/early | End of prompt | Inline/early | Gemini attends most to late-positioned constraints |

The 3-instruction minimal pattern (persistence + tool-calling + planning) works across all model families — see `architecture-patterns.md` § Agent Patterns for details.

### Conversion Checklist

Use this checklist when porting prompts between model families:

1. Identify source model class (instruction-following or reasoning).
2. Identify target model class. If class changes, rethink CoT and scaffolding.
3. Check the Conversion Matrix for feature gaps.
4. Restructure prompt layout for the target family's ordering preferences.
5. Adapt caching strategy to the target provider's mechanism.
6. Adapt structured output mechanism.
7. Adjust prompt verbosity for the target's length sensitivity.
8. Verify chat template compatibility (especially for Llama).
9. Test with the target model — conversion is a hypothesis until validated.
