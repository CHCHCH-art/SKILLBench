---
name: scifact-prompt-bound-mteb-topk-retrieval
description: "Retrieve the k-th highest document under the baseline MTEB encoding recipe, including its fixed SciFact query/passage prompt binding and deterministic unique-similarity assumption."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Scope
This is the reference retrieval recipe's prompt binding, not a universal MTEB retrieval procedure.

## Reference procedure
1. Bind model ID, model revision, query text, document file and requested rank `k` from `Instruction.md`.
2. Load with `mteb.get_model(model_id, revision=revision)`.
3. Encode the query with `task_name="SciFact"` and `PromptType.query`; encode the full document-line list with the same task name and `PromptType.passage`. The **SciFact** binding is a reference-recipe constant.
4. Compute similarities with the model's `similarity` method.
5. Assert every similarity in the first query row is unique; if not, abort because the reference does not define a tie rule.
6. Use `torch.topk(similarities,k=<task k>).indices`, take index `[0][k-1]`, strip that original document line, and write exactly it to the Task output.

## Checks

Require a nonempty document list and `1 <= k <= number_of_documents`. Query encoding must yield one embedding row, passage encoding must yield one row per input document, and both embedding matrices must have the same finite feature dimension. The similarity call must produce one finite score per document for the single query. Enforce the procedure's uniqueness assertion before `topk`; if any score ties, abort because no tie rule exists. The selected index must be within the original document list, and the emitted text must be exactly that original line after the specified strip operation. Shape mismatch, nonfinite embeddings/similarities, invalid `k`, ties, or index inconsistency abort retrieval.
