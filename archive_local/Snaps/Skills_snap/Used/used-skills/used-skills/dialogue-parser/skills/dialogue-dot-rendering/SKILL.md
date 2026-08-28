---
name: dialogue-dot-rendering
description: "Render a validated dialogue graph to deterministic Graphviz DOT using the reference layout and styling conventions for line and choice nodes, while preserving task-provided identifiers and edge labels."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Reference rendering

1. Serialize the validated graph with `rankdir=TB`, `splines=ortho`, `nodesep=0.5`, and `ranksep=0.8`.
2. Use the reference font settings: Arial size 10 for nodes and Arial size 8 for edges.
3. Ordinary dialogue nodes use a rounded white box. Choice nodes use a light-blue diamond. Bind the actual task node-type values/field names from the current task specification before deciding which style applies.
4. Escape DOT identifiers/labels deterministically. Preserve embedded line breaks from graph text rather than flattening them.
5. Emit edge labels exactly from graph construction: full choice labels for choice transitions and empty labels for ordinary transitions.

## Checks

Run Graphviz parsing/rendering when available to catch quoting errors, and compare emitted node/edge counts to the validated graph.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

