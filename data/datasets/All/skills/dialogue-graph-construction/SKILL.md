---
name: dialogue-graph-construction
description: "Construct and validate a directed dialogue graph from parsed sections, preserving node aggregation, choice-edge labeling, implicit terminal handling, start-node selection, and reachability check."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Bind values, paths, labels, schema names, limits, thresholds, ranges, and output conventions explicitly supplied by the current task specification at execution time. Do not promote task-provided values to SKILL constants. Constants labeled **reference defaults** below apply only when the current task specification does not provide that parameter.

## Procedure

1. Create exactly one graph node per parsed section, preserving section order. Bind any Task-defined node-type strings and implicit terminal identifier from the current task specification rather than hardcoding them as SKILL constants.
2. For an ordinary dialogue section, concatenate its dialogue text fragments with literal newline separators. Set the node speaker only if there is exactly one unique nonempty speaker across the aggregated lines; otherwise use the reference empty-speaker representation.
3. For a choice section, emit the task-defined choice node type with empty text/speaker fields. Choice outgoing edges carry the **full numbered choice text** as their label. Ordinary transition edges use an empty label.
4. Resolve explicit transition targets against defined sections. If the current Task defines an implicit terminal target, allow that target under the reference terminal handling instead of requiring a normal source section.
5. The start node is the first parsed section. Run breadth-first reachability from that start across explicit graph edges and require every explicit section to be reachable under the reference validation rule.

## Checks

Assert one node per section, preserve deterministic source order, and verify every nonterminal edge target resolves. A reachability failure is an error rather than a reason to silently prune nodes.

If any required check fails and no reference retry/fallback is explicitly stated above, abort this step and do not emit downstream output.

