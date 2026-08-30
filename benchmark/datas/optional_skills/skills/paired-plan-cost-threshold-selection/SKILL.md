---
name: paired-plan-cost-threshold-selection
description: "Evaluate paired shared-shape batch plans with the task cost model, enforce task-provided thresholds, and choose among reference shape-selector candidates deterministically."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Import the Task-provided cost model and instantiate it with the Task alignment granularity. Compute metrics separately for both request buckets from emitted records.
2. Bind all feasibility thresholds from `Instruction.md`; do not embed those threshold numbers in this SKILL. A candidate is feasible only if both buckets satisfy every required cost, padding, p95 latency and sequential-time threshold.
3. Sweep all shape sets produced by the reference k-medoids/weighted-quantile selectors. The candidate sweep also iterates reference lambda values `0.5,1,1.5,2,2.5,3`; preserve this candidate order even where the emitted plan is unchanged by lambda.
4. Rank candidates with the same reference normalized composite based on Task thresholds, then p95 sum and padding sum as tie metrics; feasible candidates are preferred over infeasible candidates.
5. Write the chosen records to the two Task output JSONL files. Re-evaluate the written plans; if schema validation or any required threshold fails, abort instead of selecting a new unlisted algorithm.

## Checks

For each candidate, require the cost model to return finite metrics for both request buckets and verify every Task-specified threshold against those metrics using the same comparison direction as the Task. The two written JSONL plans must contain exactly the requests assigned to their respective buckets, with no duplicate or missing request IDs. Re-evaluate the serialized plans and require their metrics to match the metrics used for candidate selection within numeric tolerance. If the chosen plan fails schema validation, coverage, or any required threshold, abort; do not silently choose an unlisted fallback algorithm.
