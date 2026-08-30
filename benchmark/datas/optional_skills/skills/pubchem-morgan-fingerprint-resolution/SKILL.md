---
name: pubchem-morgan-fingerprint-resolution
description: "Resolve molecule names through PubChem and compute RDKit Morgan fingerprints with bounded concurrent requests and the reference retry policy."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Resolve the task-selected target name with `pubchempy.get_compounds(name, "name")`; use the first returned compound's SMILES and reject an empty/invalid target.
2. Build the target Morgan fingerprint using the Task-provided fingerprint radius/chirality requirements.
3. Candidate resolution uses a thread pool with 10 workers and a semaphore limiting PubChem calls to 5 concurrent requests.
4. For each candidate, retry at most 5 times. Retry only errors whose message contains `Timeout`, `504`, or `503`; sleep `0.1*(attempt+1)` seconds between retries. Other errors, missing compounds and invalid SMILES reject that candidate.
5. Compute a fingerprint with the same Task-bound settings for every resolved candidate.

## Checks

Validate the invariants stated in the procedure before emitting downstream output. If a check fails and the reference procedure does not define a retry or fallback for that condition, abort this step rather than silently switching algorithms.
