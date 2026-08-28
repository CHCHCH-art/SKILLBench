# Technique Catalog

Prompting techniques organized by category. Each entry includes model-class compatibility.
Consult the Selection Heuristic at the end to match techniques to tasks.

---

## Zero-Shot Techniques

Techniques requiring no examples. Start here; add complexity only when these fail.

**Direct Instruction**: State the task explicitly in imperative voice. Works on all models.
Most underrated technique — a clear, specific instruction outperforms clever scaffolding.
```
Summarize the following article in 3 bullet points, each under 20 words.
```

**Role Prompting**: Assign an expert persona to prime domain-appropriate vocabulary and
reasoning frames. `"You are a senior security engineer reviewing this code for
vulnerabilities."` Higher impact on instruction-following models. Minimal effect on
reasoning models — their internal reasoning already adopts relevant expertise.

**Emotion Prompting**: Adding emotional stakes/framing (e.g., `"This is very important to my career"`) can marginally improve instruction-following models; no effect on reasoning models — improve the instruction itself instead.

**Style Transfer**: Specify output style, register, or audience level. Combine with
Direct Instruction for precise tone control. `"Explain like I'm five"` or
`"Write in the style of a technical RFC with numbered requirements."` Works on all models.

**Rephrase and Respond (RaR)**: Ask the model to rephrase the question before answering
(Deng et al., 2023 — arXiv:2311.04205). Slight improvement on ambiguous or poorly worded
queries. `"Rephrase this question for clarity, then answer the rephrased version."`
Works on both classes.

---

## Few-Shot Techniques

Provide input-output examples to demonstrate the task. Critical for instruction-following
models. For reasoning models, use 0-1 examples for format only.

**Standard Few-Shot**: Provide 3-5 input-output examples. High impact on
instruction-following models. Minimal benefit on reasoning models — use at most 1 example
to demonstrate output format. Select examples that are representative of real distribution.

**Diverse Few-Shot**: Select examples covering edge cases and boundary conditions, not
just happy paths. More effective than random selection. Include at least one example near
each decision boundary in classification tasks.

**Chain-of-Thought Few-Shot**: Examples include intermediate reasoning steps before the
answer. ONLY for instruction-following models. Never add to reasoning models — external
CoT competes with their internal reasoning chain (Prompting Inversion —
arXiv:2510.22251).
```
Q: Roger has 5 tennis balls. He buys 2 cans of 3. How many does he have?
A: Roger starts with 5 balls. 2 cans × 3 balls = 6 new balls. 5 + 6 = 11. The answer is 11.
```

**Negative Few-Shot**: Include examples of what NOT to do alongside correct examples.
Mark them explicitly. Useful for classification, content moderation, and formatting tasks
where the model tends toward specific failure modes.
```
CORRECT: "The server returned a 404 error." → Category: Infrastructure
INCORRECT: "The server returned a 404 error." → Category: Security  ← Wrong: 404 is not a security issue
```

---

## Thought Generation (Chain-of-Thought Family)

Techniques that elicit intermediate reasoning. Apply ONLY to instruction-following models
unless explicitly noted otherwise.

**Zero-Shot CoT**: Append "Think step by step" or "Let's work through this." Simplest
CoT technique. ONLY for instruction-following models. On reasoning models, this degrades
performance — the model already thinks internally, and external prompts add noise
(Prompting Inversion — arXiv:2510.22251).

**Structured CoT**: Provide explicit reasoning scaffolding with named stages.
`"First identify the key variables, then evaluate each constraint, finally decide which
option satisfies all constraints."` More effective than generic CoT on complex tasks.
Instruction-following only.

**Thread-of-Thought (ThoT)**: Walk-through reasoning with self-verification at each step.
`"Walk me through this step by step, pausing after each step to verify it before
continuing."` Adds error-checking to the reasoning chain. Instruction-following only.

**Tab-CoT**: Table-based reasoning. Organize reasoning into structured columns to
prevent skipping factors or mixing concerns. Works on both model classes but more
beneficial for instruction-following.
```
Organize your reasoning in a table with columns: Factor | Evidence | Assessment | Weight
```

**Reasoning Model Guidance**: For reasoning models (o3, Claude with extended thinking,
Gemini with thinking), do NOT add external CoT. Instead: provide clear objectives, set
thinking budget/effort if available (e.g., `reasoning_effort: high`), supply reference
material the model needs to reason over, and let the model's internal chain handle the
rest. More constraints on reasoning structure = worse performance.

---

## Decomposition Techniques

Break complex problems into manageable sub-problems. Effective across both model classes.

**Least-to-Most**: Identify sub-problems, order from simplest to most complex, solve
sequentially with each solution informing the next. `"First solve X (the simplest part),
then use that result to solve Y, then tackle Z."` Effective for tasks with natural
dependency chains (Zhou et al., 2022 — arXiv:2205.10625).

**Plan-and-Solve**: Ask the model to create a plan before executing. Two-phase approach
prevents premature commitment to a solution path. `"Create a step-by-step plan for this
task, then follow your plan."` Effective for multi-step tasks on both model classes
(Wang et al., 2023 — arXiv:2305.04091).

**Recursive Decomposition**: Apply decomposition recursively — each sub-problem is itself
decomposed until all pieces are trivially solvable. Best for deeply nested or
hierarchical tasks. Implement via chained calls or instruct the model to self-recurse.

**Tree of Thoughts (ToT)**: Explore multiple reasoning paths in parallel, evaluate each
path's promise, prune dead ends, and select the best trajectory. High compute cost —
requires multiple generation passes. Use only when solution quality justifies the expense
(Yao et al., 2023 — arXiv:2305.10601). Consider only for high-stakes decisions.

---

## Self-Criticism & Refinement

Generate an initial response, then improve it through structured critique. Effective
across both model classes.

**Self-Refine**: Two-phase generate-then-critique loop. `"Now review your answer for
errors, omissions, and unclear explanations. Provide an improved version."` Simple and
effective. Diminishing returns after 2-3 iterations (Madaan et al., 2023 —
arXiv:2303.17651).

**Self-Consistency**: Generate N independent responses (with temperature > 0), then take
the majority vote or synthesize the best elements. Costly but effective for factual and
logical tasks where there is a single correct answer. N=5 is a practical starting point
(Wang et al., 2022 — arXiv:2203.11171).

**Chain-of-Verification (CoVe)**: Generate an answer, extract verifiable factual claims,
verify each claim independently, revise the answer based on verification results. Good
for factual accuracy in knowledge-intensive tasks (Dhuliawala et al., 2023 —
arXiv:2309.11495).

**Reflection**: Append a reflection step before finalizing. `"Before giving your final
answer, reflect on potential mistakes in your reasoning and correct any you find."` Works
on both model classes. Lighter-weight than Self-Refine — single pass, no iteration.

---

## Ensembling

Combine multiple perspectives or prompting strategies for higher-quality outputs.
Inherently higher cost — use when quality justifies the compute.

**Multi-Persona Ensemble**: Have the model adopt multiple expert perspectives and
synthesize them into a unified response. `"Answer as a security expert, then as a UX
designer, then synthesize both views into a balanced recommendation."` Works on both
model classes. Especially effective for multi-stakeholder decisions.

**DiVeRSe**: Diverse Verifier on Reasoning Steps — generate diverse prompts for the
same problem, sample multiple reasoning paths per prompt, verify each reasoning step
(Li et al., 2023 — arXiv:2305.17651). Research technique; high compute cost. Consider
only for mission-critical outputs requiring maximum reliability.

**Meta-Prompting**: Use one LLM call to generate or optimize the prompt for a subsequent
call. The first call analyzes the task and produces a tailored prompt; the second call
executes it. Useful for prompt automation pipelines and self-improving systems.

---

## Multi-Modal Techniques

Techniques for prompts involving images, audio, video, or mixed media. Require
vision-capable or multi-modal models.

**Image-Before-Text Ordering**: Place images before text instructions for better
grounding. The model processes the image first, then reads instructions with visual
context already loaded.
```
Here is the screenshot: [image]
Now describe the navigation elements visible in this interface.
```

**Detail Mode Selection**: Specify detail level when the API supports it (e.g., OpenAI
`detail: high` vs `detail: low`). Use high detail for OCR, fine text, or small UI
elements. Use low detail for general scene understanding — faster and cheaper.

**Multi-Image Labeling**: When providing multiple images, label each explicitly to prevent
confusion. Reference labels in instructions.
```
Image A shows the current design. Image B shows the proposed redesign.
Compare the navigation hierarchy in Image A vs Image B.
```

**OCR Prompting**: For text extraction from images, specify the expected structure to
guide the model's parsing. `"Extract all text from this receipt. Format as a table with
columns: Item, Quantity, Unit Price, Total."` Reduces hallucinated or missed fields.

**Audio/Video Segment Referencing**: Reference specific timestamps or segments rather
than asking about the entire media. `"At 2:30 in the audio, the speaker mentions a
deadline. What is the specific date mentioned?"` Focuses attention and improves accuracy.

**Cross-Modal Grounding**: Anchor reasoning in one modality using evidence from another.
`"The chart (see image) shows declining Q3 sales. Given the earnings call transcript
(text below), explain the factors driving this decline."` Forces the model to integrate
information across modalities rather than relying on one.

---

## Structuring Techniques

How to organize the prompt itself. Structure affects parsing accuracy and maintainability.

**XML Tags** (recommended default): Use semantic tags to delimit sections.
`<instructions>`, `<context>`, `<examples>`, `<output>`. Cross-model compatible — all
4 major labs (Anthropic, OpenAI, Google, Meta) endorse XML tags. Best for complex,
multi-section prompts. Nest freely for hierarchical structure.
```xml
<instructions>Summarize the document below.</instructions>
<context>{{document}}</context>
<output>3 bullet points, each under 20 words.</output>
```

**Markdown Headers**: Use `## Task`, `## Context`, `## Rules` to organize sections.
Natural for developers. Good readability. Slightly less precise than XML for nested
structures, but sufficient for most prompts.

**JSON Structure**: Useful when the prompt itself is programmatically generated or
consumed. Machine-readable. Risk: models may try to "complete" the JSON structure rather
than follow it as instructions. Mitigate by placing JSON in a clearly delimited block.

**TOON Format**: Typed Object-Oriented Notation. 73.9% accuracy on format-following
benchmarks (toonformat.dev). Uses `type: object` notation with clear field definitions.
Best for smaller models needing strict output format adherence. Note: benchmark is from
the format creator; independent verification is limited to small models.

**Delimiter Patterns**: Use consistent delimiters (XML tags, markdown headers, triple backticks) to separate prompt sections. See hardening-checklist.md for delimiter security patterns.

---

## Over-Specification Guidance

See anti-patterns.md #5 and SKILL.md "Avoid over-specification" principle.

---

## Selection Heuristic

Match task characteristics to recommended techniques. Start with the simplest
technique that fits; escalate only when results are insufficient.

| Task Characteristic | Recommended Techniques | Model-Class Notes |
|--------------------|-----------------------|-------------------|
| Simple, well-defined task | Direct Instruction, Role Prompting | Both classes |
| Classification or labeling | Few-Shot (3-5 examples), Negative Few-Shot | Instruction-following: more examples help. Reasoning: 0-1 examples |
| Multi-step reasoning | Plan-and-Solve, Structured CoT | Instruction-following only for CoT. Reasoning: clear objectives only |
| Creative generation | Role Prompting, Style Transfer, Temperature tuning | Both classes |
| Factual accuracy critical | Chain-of-Verification, Self-Consistency | Both classes, high compute cost |
| Code generation | Direct Instruction + examples, Plan-and-Solve | Both classes; reasoning models excel without scaffolding |
| Ambiguous or open-ended | Rephrase and Respond, Decomposition | Both classes |
| Multiple perspectives needed | Multi-Persona Ensemble | Both classes |
| Image understanding | Image-Before-Text, Detail Mode, Cross-Modal Grounding | Vision-capable models only |
| Long document analysis | Decomposition, Tab-CoT | Both classes; watch context limits |
| Agent/tool-calling | 3-Instruction Pattern (persistence, tool-calling, planning) | Both classes; ~20% improvement (OpenAI) |
| Adversarial/safety-critical | Hardening patterns (see hardening-checklist.md) | Both classes |
