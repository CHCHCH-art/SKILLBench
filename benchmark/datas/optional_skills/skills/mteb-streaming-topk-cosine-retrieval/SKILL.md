---
name: mteb-streaming-topk-cosine-retrieval
description: "Perform streaming top-k cosine retrieval with an MTEB-compatible encoder, including deterministic prompt-template selection, asymmetric query/passage encoding, one-line-at-a-time scoring, strict score uniqueness, and fixed-size heap rank selection. Use when a task specifies an embedding model/revision and asks for an exact similarity rank from a text-line corpus."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding

Read the following from the current task specification at execution time:

- query text;
- model identifier and exact model revision;
- corpus path;
- requested rank `k`;
- output path and output formatting requirements;
- any explicitly specified prompt/task binding.

Do not turn those task-provided values into SKILL constants.

The prompt/task binding is an encoding-template choice. If the task explicitly specifies it, use that binding. If the task is silent, use the decision policy below.

## Prompt-template decision policy

Choose one prompt policy before encoding anything, and keep it fixed for the query and the entire corpus.

### A. Reference-compatible MTEB task prompt — default

Use this when reproducing a fixed reference recipe is the priority, or when the task gives no prompt requirement and there is no evidence that another template should replace the reference binding.

```python
query_task_name = "SciFact"
passage_task_name = "SciFact"
query_prompt_type = mteb.encoder_interface.PromptType.query
passage_prompt_type = mteb.encoder_interface.PromptType.passage
```

This is a task-specific MTEB prompt template, not a universal property of cosine retrieval. Keep the query/passage asymmetry: query uses `PromptType.query`; corpus entries use `PromptType.passage`.

### B. Explicit task-specific MTEB prompt

Use this when the current task or invocation metadata supplies a specific MTEB task/prompt binding. It overrides the default above. Apply its query and passage prompt types consistently to every encoded item.

This is appropriate when the retrieval problem is intentionally aligned with a known MTEB task and the caller wants that task's prompt semantics.

### C. Generic retrieval-level prompt

Use this only when adaptive prompt selection is allowed and the loaded MTEB/SentenceTransformer wrapper exposes a generic retrieval prompt, such as a prompt keyed by `Retrieval`, `Retrieval-query`, `query`, or the corresponding passage/document key.

Prefer this over borrowing an unrelated named benchmark task when the problem is ordinary query-to-document retrieval and no task-specific semantic match is intended. Verify that the chosen prompt key actually exists in the loaded model/wrapper; do not invent a prompt name.

### D. Model-native BGE retrieval instruction

For BGE v1/v1.5 models, a model-native short-query-to-passage retrieval template is a valid adaptive choice when the query is short and corpus entries are document-like passages. For `bge-*-zh-v1.5`, the model-family query instruction is:

```text
为这个句子生成表示以用于检索相关文章：
```

Apply the instruction to the query only; do not prepend it to passages. Use this mode only when the model wrapper exposes a direct prompt/instruction mechanism or when the caller explicitly permits constructing the prompted query text.

### E. No prompt / symmetric raw encoding

Encode raw query and raw passages without an instruction when adaptive prompt selection is allowed and either:

- the inputs behave more like symmetric semantic-similarity text than short-query-to-document retrieval; or
- no reliable task-specific or model-native prompt is available.

BGE v1.5 models are designed to remain usable without a retrieval instruction, although short-query-to-passage retrieval generally benefits from the query instruction.

### Selection rule

Use **A** by default for reproducibility. Move to **B–E** only when the task/caller permits prompt adaptation. Do not test several prompt templates against the corpus and pick whichever changes the requested rank in a desirable direction; that would turn prompt selection into answer-driven tuning rather than a declared encoding convention.

If an explicitly required prompt binding cannot be instantiated by the installed MTEB/model wrapper, fail rather than silently changing prompt semantics.

## Retrieval procedure

1. Load the exact requested model revision through the MTEB model API.
2. Resolve the prompt policy once using the rules above.
3. Encode the query once with the selected query-side template. In reference-compatible mode:

```python
query_embedding = model.encode(
    query_text,
    task_name="SciFact",
    prompt_type=mteb.encoder_interface.PromptType.query,
)
```

4. Initialize:

```python
topk = []
seen_scores = set()
```

5. Stream the corpus one physical line at a time. Preserve the distinction between text used for encoding and text written as the result:

```python
for index, line in enumerate(f):
    output_text = line.rstrip("\r\n")
```

In reference-compatible mode, pass the original physical line, including its line terminator when present, as a one-element passage batch:

```python
doc_embedding = model.encode(
    [line],
    task_name="SciFact",
    prompt_type=mteb.encoder_interface.PromptType.passage,
)
```

For an adaptive prompt policy, change only the declared prompt/template binding; keep the same streaming and ranking procedure.

6. Compute the model's cosine-similarity value and convert the scalar to `float`:

```python
similarity = model.similarity(query_embedding, doc_embedding)
score = float(similarity[0][0])
```

7. Require every corpus similarity score to be unique. If `score` has already appeared, abort because the rank is ambiguous under this procedure:

```python
if score in seen_scores:
    raise AssertionError("similarity scores are not unique")
seen_scores.add(score)
```

8. Maintain a min-heap of exactly the best `k` seen candidates. Store `(score, line_index, output_text)`:

```python
item = (score, index, output_text)
if len(topk) < k:
    heapq.heappush(topk, item)
elif score > topk[0][0]:
    heapq.heapreplace(topk, item)
```

Do not replace the root on equal score; equality should already have failed the uniqueness check.

9. After the stream ends, require at least `k` documents. The min-heap root is then the requested `k`-th highest-scoring item.
10. Write that item's newline-stripped text to the requested output path. Do not add an output newline unless the task specification requires one.

## Checks

Before accepting the result, verify all of the following:

- the exact requested model revision was loaded;
- one prompt policy was selected before encoding and remained unchanged for every item;
- query and passage embeddings are finite and dimensionally compatible;
- each physical corpus line was scored exactly once;
- every similarity score is finite and globally unique;
- after at least `k` lines, the heap size remains exactly `k`;
- no candidate with score greater than the heap root is absent from the final heap;
- the returned item is the heap root after the full scan and is therefore rank `k` under the strict-score ordering;
- the emitted text equals the selected corpus line after removing only trailing `\r`/`\n` characters.

Abort on a missing/unsupported required prompt binding, embedding-shape mismatch, non-finite score, duplicate score, fewer than `k` corpus lines, or heap/rank inconsistency.
