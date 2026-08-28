---
name: highs-dual-market-pricing-report
description: "Convert a solved HiGHS DCOPF/reserve LP into LMP, reserve price, line loading, binding-line, generation and reserve market results using the reference dual-sign conventions."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Reference procedure
1. Require successful HiGHS status. Independently compute max primal violation over equalities, inequalities and variable bounds; abort if it exceeds **1e-3**.
2. Report objective as `c1 @ Pg + sum(c0)`.
3. LMPs are the **negative** equality marginals for the bus-balance rows. Reserve MCP is `max(0, -marginal_of_reserve_requirement_row)`.
4. Branch flow is the constructed `Bf @ phi`. Loading is `abs(flow)/rating` on limited lines; a line is binding when loading meets the Task-provided binding threshold.
5. Preserve the reference 2-decimal rounding for reported market quantities. Do not re-solve to obtain prices with a different LP method.

## Checks

Require successful HiGHS status and independently recomputed maximum primal violation `<=1e-3` before using duals. The LMP vector must contain one finite value per bus-balance row and use the stated negative equality-marginal sign; reserve MCP must be finite and nonnegative after `max(0,-marginal)`. Recomputed branch flows/loadings must be finite, limited-line denominators must be positive, and binding flags must equal the Task-bound loading-threshold test. Reported objective, prices, flows, generation and reserve quantities must follow the stated 2-decimal serialization convention. Solver failure, excessive primal violation, dual-size mismatch, nonfinite prices, or inconsistent binding logic aborts reporting.
