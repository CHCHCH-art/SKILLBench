#!/bin/bash
set -e

cat << 'EOF' > /app/retrieve.py
import heapq
import mteb

MODEL_NAME = "BAAI/bge-small-zh-v1.5"
REVISION = "7999e1d3359715c523056ef9478215996d62a620"

model = mteb.get_model(
    MODEL_NAME,
    revision=REVISION,
)

query_embedding = model.encode(
    "terminal-bench",
    task_name="SciFact",
    prompt_type=mteb.encoder_interface.PromptType.query,
)

top5 = []

seen_scores = set()

with open("/app/data.txt", "r", encoding="utf-8") as f:
    for index, line in enumerate(f):
        document = line.rstrip("\r\n")

        doc_embedding = model.encode(
            [line],
            task_name="SciFact",
            prompt_type=mteb.encoder_interface.PromptType.passage,
        )

        similarity = model.similarity(
            query_embedding,
            doc_embedding,
        )

        score = float(similarity[0][0])

        if score in seen_scores:
            raise AssertionError(
                "Similarities are not unique, cannot determine 5th highest"
            )
        seen_scores.add(score)

        item = (score, index, document)

        if len(top5) < 5:
            heapq.heappush(top5, item)
        elif score > top5[0][0]:
            heapq.heapreplace(top5, item)

if len(top5) < 5:
    raise RuntimeError("data.txt contains fewer than 5 documents")

fifth_score, fifth_index, fifth_document = top5[0]

with open("/app/result.txt", "w", encoding="utf-8") as f:
    f.write(fifth_document)
EOF

cd /app
python retrieve.py