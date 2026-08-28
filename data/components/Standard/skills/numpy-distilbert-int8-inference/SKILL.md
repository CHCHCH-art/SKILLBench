---
name: numpy-distilbert-int8-inference
description: "Run the local Hugging Face sentiment-classification service model by executing a DistilBERT-style classifier directly in NumPy from row-int8 weights, reproducing attention, normalization, GELU, logits, and confidence probabilities."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference math and flow
1. Read dimensions/head/layer counts from model config. Use `EPS=1e-12`, `head_dim=dim/n_heads`, attention scale `1/sqrt(head_dim)`, and tokenizer truncation at **512 tokens**.
2. Dequantize a matrix on use as `q.astype(float32)*scale[:,None]`; embedding lookup dequantizes only selected rows. Linear layer is `x @ W.T + b`.
3. Layer norm uses float32 mean/variance over the last axis: `(x-mean)/sqrt(var+1e-12)*gamma+beta`.
4. GELU is the tanh approximation `0.5*x*(1+tanh(sqrt(2/pi)*(x+0.044715*x^3)))`.
5. Attention forms Q/K/V, reshapes `(seq,heads,head_dim)`→`(heads,seq,head_dim)`, computes stabilized softmax of `QK^T/sqrt(head_dim)`, then output projection. Residual+SA layer norm precedes FFN; FFN is lin1→GELU→lin2→residual output layer norm.
6. Embeddings are word+position followed by embedding LayerNorm. Run every transformer layer. Use token 0 as pooled representation, apply pre-classifier, ReLU, classifier, then stabilized softmax.
7. Reference binary decision is positive only when positive probability is strictly greater than negative; ties map to negative. Bind actual label/schema names from Instruction.

## Checks

At load time, require every tensor named by the model architecture to exist in the runtime manifest with the expected rank and compatible dimensions. During inference require finite activations/logits, attention head divisibility, token count within the reference truncation limit, and softmax probabilities finite, nonnegative and summing to approximately 1. A missing/incompatible tensor or nonfinite result is a hard inference failure; do not skip a transformer layer or substitute random/default weights.
