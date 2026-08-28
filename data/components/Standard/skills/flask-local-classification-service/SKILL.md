---
name: flask-local-classification-service
description: "Expose the local NumPy sequence-classifier through a Flask POST endpoint, manage the reference PID lifecycle, wait for socket readiness, and run startup inference checks."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Bind endpoint path, request/response schema and service port from `Instruction.md`; the reference server runs threaded on all interfaces.
2. For malformed JSON, missing text, or non-string text, return the Task-required error JSON/status. The reference also maps unexpected inference exceptions to the same HTTP error status rather than crashing the server.
3. If a stored PID identifies a running previous server, terminate it and poll up to 50 × 0.1 s for exit.
4. Start Flask under `nohup`, store the PID, and poll the TCP socket up to 240 × 0.25 s. Abort and surface the log if the process exits or never binds.
5. Send three ordinary startup requests through the actual HTTP endpoint. Require success status, a valid class label, and floating positive/negative confidence values. Startup check failure aborts service launch.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
