---
name: flask-sequence-classification-api
description: "Serve a locally saved binary sequence classifier through Flask using request validation, tokenizer truncation, no-grad inference, fixed class-index interpretation, probability response, and launch behavior."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Bind route, host, port, request/output field names and model path from the current Task's the current task specification; do not hardcode Task endpoint/path values in the SKILL.
2. For each POST request parse JSON and return the Task-specified error status/payload when the required text field is absent; read that status code from the current task specification.
3. Tokenize the input with `return_tensors="pt"`, `padding=True`, `truncation=True`, and reference `max_length=512`.
4. Run the model under `torch.no_grad()`, apply `softmax(logits, dim=-1)`, and preserve the procedure's binary class convention: index `0` is negative and index `1` is positive; choose positive only when `p1 > p0`, otherwise negative.
5. The reference response includes the original input text, the predicted sentiment, and confidence values for positive/negative classes. Bind actual JSON key names to the Task schema when constructing the artifact while preserving this response content.
6. Launch Flask with the task-bound host/port via a background process, redirect logs, wait the reference **5 seconds**, then exercise the API using validation request path.

## Checks
Confidence values must be raw softmax floats and sum approximately to one. Reload the model from local disk before serving.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

