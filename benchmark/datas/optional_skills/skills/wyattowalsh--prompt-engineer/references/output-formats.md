# Output Formats

Templates for all skill outputs. Read when formatting any prompt-engineer
skill deliverable.

## Diagnostic Scorecard

Used by Analyze (Mode B) step 4.

```
DIAGNOSTIC SCORECARD
| Dimension    | Score (1-5) | Assessment                              |
|--------------|-------------|-----------------------------------------|
| Clarity      | {N}         | {One-line justification}                |
| Completeness | {N}         | {One-line justification}                |
| Efficiency   | {N}         | {One-line justification}                |
| Robustness   | {N}         | {One-line justification}                |
| Model Fit    | {N}         | {One-line justification}                |
| **Total**    | **{N}/25**  |                                         |

Overall: {One-sentence summary of prompt health}
Priority improvements: {Top 2-3 dimensions to address}
```

**Scoring guide:**
- 1: Fundamentally broken — causes failures or security issues
- 2: Significant problems — works sometimes, fails on edge cases
- 3: Adequate — works for common cases, room for improvement
- 4: Good — handles most cases well, minor issues
- 5: Excellent — robust, efficient, well-suited to model

## Audit Report

Used by Analyze (Mode B), report-only.

```
AUDIT REPORT: {Prompt Name or Description}
Target model: {Model name} ({model class})
Audit date: {Date}

EXECUTIVE SUMMARY
{1-3 sentences: overall assessment, critical findings count, recommendation}

FINDINGS
| # | Severity | Category | Finding | Location |
|---|----------|----------|---------|----------|
| 1 | Critical | {lens}   | {desc}  | {where}  |
| 2 | High     | {lens}   | {desc}  | {where}  |
| ...                                            |

DETAILED FINDINGS

### Finding 1: {Title}
**Severity:** Critical
**Category:** {Ambiguity | Security | Robustness | Efficiency}
**Location:** {Line range or section of the prompt}
**Description:** {What the issue is}
**Impact:** {What goes wrong because of this issue}
**Remediation:** {How to fix it}

{Repeat for each finding}

ANTI-PATTERNS DETECTED
{List of matched anti-patterns from anti-patterns.md, or "None detected"}

MODEL-FIT ASSESSMENT
{Is the prompt well-suited to its target model class? Key observations.}

OVERALL RISK: {Critical | High | Medium | Low}
RECOMMENDED NEXT: {Mode B (Analyze) | Mode D (Evaluate) | Deploy with monitoring}
```

## Conversion Diff

Used by Convert (Mode C) step 7.

```
CONVERSION: {Source Model} → {Target Model}

CONVERSION PLAN
| # | Change | Type | Reason |
|---|--------|------|--------|
| 1 | {desc} | Direct map | {why} |
| 2 | {desc} | Adaptation | {why} |
| 3 | {desc} | Removal | {why} |
| 4 | {desc} | New feature | {why} |

SIDE-BY-SIDE

Source ({Source Model}):
```
{original prompt section}
```

Target ({Target Model}):
```
{converted prompt section}
```

Change: {What changed and why}

---

{Repeat for each significant change}

BEHAVIORAL DIFFERENCES TO EXPECT
- {Difference 1: what will behave differently and why}
- {Difference 2}

FEATURES GAINED: {List of target model features now leveraged}
FEATURES LOST: {List of source model features with no equivalent}

RECOMMENDED: Test with Mode D (Evaluate) using the same test cases on both models
```

## Evaluation Framework

Used by Evaluate (Mode D) step 8.

```
EVALUATION FRAMEWORK: {Prompt Name}
Target model: {Model name}
Created: {Date}

SUCCESS CRITERIA
| # | Criterion | Type | Definition |
|---|-----------|------|------------|
| 1 | {name}    | Functional | {what it means to pass} |
| 2 | {name}    | Quality | {what it means to pass} |
| 3 | {name}    | Safety | {what it means to pass} |

TEST SUITE

### Golden Set ({N} cases)
| # | Input Summary | Expected Behavior | Pass Criteria |
|---|--------------|-------------------|---------------|
| 1 | {brief}      | {expected}        | {how to judge} |

### Edge Cases ({N} cases)
| # | Input Summary | Expected Behavior | Pass Criteria |
|---|--------------|-------------------|---------------|

### Adversarial Cases ({N} cases)
| # | Input Summary | Expected Behavior | Pass Criteria |
|---|--------------|-------------------|---------------|

SCORING RUBRIC
| Dimension | 1 (Poor) | 3 (Adequate) | 5 (Excellent) |
|-----------|----------|--------------|---------------|
| {dim 1}   | {desc}   | {desc}       | {desc}        |
| {dim 2}   | {desc}   | {desc}       | {desc}        |

LLM-AS-JUDGE PROMPT (if applicable):
{Complete judge prompt ready for use}

RECOMMENDED TOOLS: {Promptfoo | Braintrust | Langfuse}
CI/CD INTEGRATION: {Suggested pipeline configuration}
BASELINE EXPECTATIONS: {Expected scores from current prompt version}
```

## Annotated Prompt

Used by Craft (Mode A) step 6.

```
ANNOTATED PROMPT: {Description}
Target model: {Model name} ({model class})
Architecture: {Pattern used}
Caching strategy: {Summary}

{The complete prompt with inline annotations}

<!-- RATIONALE: Role definition establishes expertise and tone -->
<system>
You are a {role}...
</system>

<!-- RATIONALE: Static context placed early for cache efficiency -->
<context>
{Background information}
</context>

<!-- RATIONALE: Core task uses direct instruction pattern -->
<task>
{Task description}
</task>

<!-- RATIONALE: Constraints kept minimal to avoid over-specification -->
<constraints>
{Rules}
</constraints>

<!-- RATIONALE: Output example preferred over abstract format description -->
<output_format>
{Format specification with example}
</output_format>

---
MODEL-CLASS ASSUMPTIONS: {What model class this prompt targets and why}
EVAL CRITERIA: {What "working correctly" means for this prompt}
NEXT STEPS: Run Mode D (Evaluate) to build a test suite
```

## Changelog

Used by Analyze (Mode B) step 9.

```
CHANGELOG: {Prompt Name}
Optimized: {Date}
Target model: {Model name}

| # | Change | Before | After | Rationale |
|---|--------|--------|-------|-----------|
| 1 | {desc} | `{old}` | `{new}` | {technique or principle} |
| 2 | {desc} | `{old}` | `{new}` | {technique or principle} |

SCORE CHANGE
| Dimension    | Before | After | Delta |
|--------------|--------|-------|-------|
| Clarity      | {N}    | {N}   | {+/-} |
| Completeness | {N}    | {N}   | {+/-} |
| Efficiency   | {N}    | {N}   | {+/-} |
| Robustness   | {N}    | {N}   | {+/-} |
| Model Fit    | {N}    | {N}   | {+/-} |
| **Total**    | **{N}**| **{N}**| **{+/-}** |

REMAINING RISKS: {Issues not addressed in this optimization}
RECOMMENDED NEXT: {Mode D (Evaluate) | Mode B audit | Deploy}
```
