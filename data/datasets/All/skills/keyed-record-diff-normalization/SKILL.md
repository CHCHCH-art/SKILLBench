---
name: keyed-record-diff-normalization
description: "Compare original PDF-derived and current Excel keyed records, normalize scalar values for stable JSON, and emit deterministic deleted/modified record differences."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Load current Excel with pandas and bind the Task key field. Deleted IDs are original-key values absent from current data; sort them deterministically.
2. For IDs common to both sources, compare every original field except the key. Treat two NaNs as equal.
3. Normalize output scalars to ordinary Python types. For floats, integer-valued values become integers; otherwise round to **1 decimal** before comparison/output, matching the reference convention.
4. Record a modification only when normalized values differ. Sort modifications by key then field in stable ascending order.
5. Bind top-level JSON schema/field names from Instruction and serialize without leaking dataframe-specific scalar objects.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
