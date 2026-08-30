---
name: baseline-fasttext-small-supervised-training
description: "Build fastText from source and train the baseline compact supervised model with the reference word-ngram and embedding-dimension settings."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Ensure git and a C/C++ build toolchain, clone the official FacebookResearch fastText repository, and run `make`; add the built executable to PATH.
2. Train with `fasttext supervised -input <converted_train> -output <task_model_prefix> -wordNgrams 2 -dim 5`.
3. The constants **wordNgrams=2** and **dim=5** are reference model choices. Do not add autotuning, epochs, learning-rate searches, quantization or pruning because this reference recipe does not include those stages.
4. Bind final model location and Task model-size/accuracy constraints from `Instruction.md`. The reference does not explicitly validate those constraints after training; perform only non-algorithmic output-existence/size inspection and report failure if the produced model violates a hard Task requirement rather than silently retraining with a different recipe.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
