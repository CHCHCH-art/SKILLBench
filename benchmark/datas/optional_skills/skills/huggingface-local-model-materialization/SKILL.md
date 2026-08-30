---
name: huggingface-local-model-materialization
description: "Download a task-specified Hugging Face sequence-classification model/tokenizer and save both into a local inference directory using Auto classes, so a later API serves only from the materialized local model."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure
1. Read the model identifier/revision if supplied and local target directory from the current task specification or the calling task binding.
2. Load with `AutoModelForSequenceClassification.from_pretrained(...)` and `AutoTokenizer.from_pretrained(...)` using the reference default Hugging Face behavior.
3. Save both with `save_pretrained` into the same local model directory. The serving process reloads from this local directory rather than retaining the download-time Python objects.

## Checks
Require both tokenizer and model configuration/weights to reload successfully from the local directory before launching the API.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

