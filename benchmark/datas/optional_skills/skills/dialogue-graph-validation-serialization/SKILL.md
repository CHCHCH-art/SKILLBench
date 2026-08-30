---
name: dialogue-graph-validation-serialization
description: "Validate and serialize parsed branching dialogue graphs to JSON and Graphviz DOT while preserving the reference node/edge schema and validation behavior."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Represent nodes with `id,text,speaker,type` and edges with source, target and edge text; map edge fields to the Task-requested JSON names at serialization time.
2. Validate every edge source exists. Validate every edge target exists unless it equals the terminal sentinel bound from `Instruction.md`. The reference validator does **not** perform a reachability traversal even if the Instruction asks for one; do not add a different graph algorithm inside this SKILL.
3. Serialize JSON with top-level node and edge arrays and indentation level 2.
4. For DOT, use a top-to-bottom directed graph; line nodes are boxes and choice nodes are diamonds. Create a terminal node if referenced. Label edges with choice text where present.
5. If structural validation fails, abort JSON/DOT emission rather than dropping the bad edge.

## Checks

Before writing either format, require unique node IDs, every edge source to reference a node, and every nonterminal edge target to reference a node. JSON node/edge counts must equal the in-memory graph counts and every serialized edge must preserve its source, target and text. DOT must contain one declared graph node per JSON node plus the terminal sentinel only when referenced. Any dangling edge, duplicate node ID, or serialization count mismatch aborts both outputs; do not drop malformed graph elements.
