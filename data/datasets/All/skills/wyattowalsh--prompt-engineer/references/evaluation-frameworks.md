# Evaluation Frameworks

Evaluation approaches, PromptOps lifecycle, and tool guidance. Used by
Evaluate (Mode D) and recommended after Craft (Mode A) and Analyze (Mode B).

## Evaluation Approaches

### Golden Set Evaluation

The foundation of prompt evaluation. Create a curated set of 5-10
representative inputs with known-good expected outputs.

**Building a golden set:**
1. Select inputs covering the full range of expected use cases
2. Include at least one edge case and one adversarial input
3. Define expected outputs precisely (exact match, semantic match, or rubric)
4. Version the golden set alongside the prompt — changes to one may require changes to the other

**Running golden set evaluation:**
- Pass each input through the prompt
- Compare output to expected using the appropriate matching strategy
- Track pass rate across prompt versions
- A golden set regression (previously passing case now fails) blocks deployment

### LLM-as-Judge

Use a separate LLM call to evaluate the output of the prompt being tested.
More flexible than exact matching but less deterministic.

**Rubric template for LLM-as-judge:**
```
<judge_instructions>
Evaluate the following output against these criteria. For each criterion,
assign a score from 1 to 5 and provide a one-sentence justification.

Criteria:
1. {Criterion name}: {Definition of what 1 vs 5 means}
2. {Criterion name}: {Definition}
3. {Criterion name}: {Definition}

Output to evaluate:
<output>{model_output}</output>

Context (the input that produced this output):
<input>{original_input}</input>

Respond with a JSON object:
{
  "scores": {"criterion_1": N, "criterion_2": N, ...},
  "justifications": {"criterion_1": "...", "criterion_2": "..."},
  "overall": N,
  "summary": "One-sentence overall assessment"
}
</judge_instructions>
```

**Best practices:**
- Use a stronger model as judge than the model being evaluated
- Calibrate the rubric with 5-10 pre-scored examples
- Run each evaluation 3 times and average (LLM judges have variance)
- Include both positive and negative examples in calibration
- Watch for sycophancy — judges tend to rate highly. Counter with explicit "look for flaws" instructions

### A/B Testing

Compare two prompt versions on the same inputs.

**Protocol:**
1. Define the metric(s) to compare (quality score, latency, cost, user satisfaction)
2. Run both versions on the same input set (minimum 50 inputs for statistical significance)
3. Use paired comparison (same input, both versions) to control for input difficulty
4. Report: win rate, average score difference, confidence interval
5. Declare a winner only with statistical significance (p < 0.05)

### Adversarial Testing

Systematically test for failure modes. Categories:

- **Boundary inputs**: Empty, maximum length, minimum length, exactly at limits
- **Format violations**: Wrong input format, missing fields, extra fields
- **Injection attempts**: Direct injection, indirect injection, role-play bypass
- **Out-of-scope requests**: Topics the prompt should decline
- **Ambiguous inputs**: Inputs with multiple valid interpretations
- **Contradictory inputs**: Inputs that conflict with the prompt's constraints

### Rubric Scoring

Define a multi-dimensional rubric for human or LLM evaluation.

**Standard dimensions (adapt per task):**

| Dimension | 1 (Poor) | 3 (Adequate) | 5 (Excellent) |
|-----------|----------|--------------|---------------|
| Accuracy | Factually wrong | Mostly correct, minor errors | Completely accurate |
| Completeness | Missing key information | Covers main points | Comprehensive coverage |
| Relevance | Off-topic or irrelevant | Mostly relevant | Precisely on-topic |
| Clarity | Confusing or ambiguous | Understandable | Clear and well-structured |
| Safety | Contains harmful content | No harmful content | Actively safe and helpful |

Customize dimensions for the specific task. A code review prompt needs
"correctness" and "actionability". A summarization prompt needs "faithfulness"
and "conciseness".

## CI/CD Integration

**Promptfoo GitHub Actions:**
```yaml
# .github/workflows/prompt-eval.yml
- name: Run prompt evaluation
  uses: promptfoo/promptfoo-action@v1
  with:
    config: prompts/eval-config.yaml
    threshold: 0.8  # Fail if score drops below 80%
```

**Braintrust PR Comparisons:**
- Automatically compare prompt performance on PR creation
- Show score diffs in PR comments
- Block merge if regression exceeds threshold

DSPy optimizers (BootstrapFewShot, MIPRO, etc.) can automate prompt optimization but are outside the scope of this skill's workflows.

## Tool Guidance

| Tool | Best For | Notes |
|------|----------|-------|
| promptfoo | CI/CD, regression testing | Open-source, YAML config, GitHub Actions |
| Braintrust | Team collab, PR comparisons | Production monitoring, golden set management |
| Langfuse | Tracing, cost tracking | Open-source, self-hosted or cloud |
| LMQL/guidance | Constrained generation | Structured output, grammar enforcement |

## Eval Design Checklist

Use when building an evaluation framework (Mode D):

- [ ] Golden set defined (5-10 representative inputs with expected outputs)
- [ ] Edge cases identified (boundary inputs, empty inputs, long inputs)
- [ ] Adversarial cases included (injection, out-of-scope, ambiguous)
- [ ] Scoring rubric defined (dimensions, levels, concrete examples per level)
- [ ] LLM-as-judge prompt calibrated (if using automated scoring)
- [ ] Baseline metrics established (current prompt performance before changes)
- [ ] Regression set maintained (previously-failed cases that must keep passing)
- [ ] CI/CD integration planned (tool selected, threshold defined)
- [ ] Monitoring strategy defined (what to track in production)
- [ ] Red-team schedule set (frequency, scope, documentation)
