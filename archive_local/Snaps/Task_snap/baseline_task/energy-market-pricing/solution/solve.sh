#!/bin/bash
set -euo pipefail

pip3 install --break-system-packages numpy==1.26.4 scipy==1.11.4 -q

python3 <<'PY'
import json
import time
import numpy as np
import scipy.sparse as sp
from scipy.optimize import linprog

NETWORK_FILE = "/root/network.json"
REPORT_FILE = "/root/report.json"

SCENARIO_FROM_BUS = 64
SCENARIO_TO_BUS = 1501
SCENARIO_DELTA_PCT = 20.0
BINDING_THRESHOLD = 0.99

HIGHS_OPTIONS = {
    "presolve": True,
    "primal_feasibility_tolerance": 1e-7,
    "dual_feasibility_tolerance": 1e-7,
    "disp": False,
}


def require_solved(res, label):
    if not res.success or res.x is None:
        raise RuntimeError(
            f"{label}: HiGHS failed: status={res.status}, message={res.message!r}"
        )


def solve_lp(c, A_ub, b_ub, A_eq, b_eq, bounds, label):
    t0 = time.perf_counter()
    res = linprog(
        c,
        A_ub=A_ub,
        b_ub=b_ub,
        A_eq=A_eq,
        b_eq=b_eq,
        bounds=bounds,
        method="highs-ds",
        options=HIGHS_OPTIONS,
    )
    elapsed = time.perf_counter() - t0
    require_solved(res, label)
    return res, elapsed


def max_primal_violation(x, A_ub, b_ub, A_eq, b_eq, lb, ub):
    vals = []
    if A_eq.shape[0]:
        vals.append(float(np.max(np.abs(A_eq @ x - b_eq))))
    if A_ub.shape[0]:
        vals.append(float(np.max(np.maximum(A_ub @ x - b_ub, 0.0))))
    finite_lb = np.isfinite(lb)
    finite_ub = np.isfinite(ub)
    if np.any(finite_lb):
        vals.append(float(np.max(np.maximum(lb[finite_lb] - x[finite_lb], 0.0))))
    if np.any(finite_ub):
        vals.append(float(np.max(np.maximum(x[finite_ub] - ub[finite_ub], 0.0))))
    return max(vals) if vals else 0.0


t_all = time.perf_counter()

with open(NETWORK_FILE, encoding="utf-8") as f:
    data = json.load(f)

baseMVA = float(data["baseMVA"])
buses = np.asarray(data["bus"], dtype=float)
gens = np.asarray(data["gen"], dtype=float)
branches = np.asarray(data["branch"], dtype=float)
gencost = np.asarray(data["gencost"], dtype=float)
reserve_capacity = np.asarray(data["reserve_capacity"], dtype=float)
reserve_requirement = float(data["reserve_requirement"])

n_bus = buses.shape[0]
n_gen = gens.shape[0]
n_branch = branches.shape[0]

if reserve_capacity.shape[0] != n_gen:
    raise ValueError("reserve_capacity length does not match generator count")
if gencost.shape[0] != n_gen or gencost.shape[1] < 7:
    raise ValueError("Unexpected gencost shape")

bus_num_to_idx = {int(buses[i, 0]): i for i in range(n_bus)}
slack_candidates = np.flatnonzero(buses[:, 1] == 3)
if slack_candidates.size == 0:
    raise ValueError("No slack/reference bus found")
slack_idx = int(slack_candidates[0])

gen_bus = np.fromiter(
    (bus_num_to_idx[int(g[0])] for g in gens), dtype=int, count=n_gen
)
Cg = sp.csc_matrix(
    (np.ones(n_gen), (gen_bus, np.arange(n_gen))),
    shape=(n_bus, n_gen),
)

B_rows, B_cols, B_vals = [], [], []
line_rows, line_cols, line_vals = [], [], []
line_branch_indices = []
line_rates = []
branch_to_limited_row = {}
target_branch_idx = None

for k, br in enumerate(branches):
    f_bus = int(br[0])
    t_bus = int(br[1])
    f = bus_num_to_idx[f_bus]
    t = bus_num_to_idx[t_bus]
    x = float(br[3])
    rate = float(br[5])

    if target_branch_idx is None and (
        (f_bus == SCENARIO_FROM_BUS and t_bus == SCENARIO_TO_BUS)
        or (f_bus == SCENARIO_TO_BUS and t_bus == SCENARIO_FROM_BUS)
    ):
        target_branch_idx = k

    if x == 0.0:
        continue

    b = 1.0 / x
    B_rows.extend((f, t, f, t))
    B_cols.extend((f, t, t, f))
    B_vals.extend((b, b, -b, -b))

    if rate > 0.0:
        r = len(line_branch_indices)
        branch_to_limited_row[k] = r
        line_branch_indices.append(k)
        line_rates.append(rate)
        line_rows.extend((r, r))
        line_cols.extend((f, t))
        line_vals.extend((b, -b))

if target_branch_idx is None:
    raise ValueError(
        f"Target line {SCENARIO_FROM_BUS}<->{SCENARIO_TO_BUS} not found"
    )
if target_branch_idx not in branch_to_limited_row:
    raise ValueError("Target line has no usable thermal limit")

Bbus = sp.coo_matrix(
    (B_vals, (B_rows, B_cols)), shape=(n_bus, n_bus)
).tocsc()
Bbus.sum_duplicates()
Bbus.eliminate_zeros()

n_limited = len(line_branch_indices)
Bf = sp.coo_matrix(
    (line_vals, (line_rows, line_cols)), shape=(n_limited, n_bus)
).tocsc()
Bf.sum_duplicates()
line_rates = np.asarray(line_rates, dtype=float)

print(
    f"Loaded {data.get('name', 'power system')}: {n_bus} buses, "
    f"{n_gen} generators, {n_branch} branches, {n_limited} thermally limited lines"
)
print(
    f"Sparse Bbus: shape={Bbus.shape}, nnz={Bbus.nnz}; "
    f"dense equivalent={n_bus*n_bus*8/1024/1024:.1f} MiB"
)

t_build_start = time.perf_counter()

N_PG = n_gen
N_RG = n_gen
N_PHI = n_bus
N_VAR = N_PG + N_RG + N_PHI
PG0 = 0
RG0 = N_PG
PHI0 = N_PG + N_RG

c2 = np.asarray(gencost[:, 4], dtype=float)
c1 = np.asarray(gencost[:, 5], dtype=float)
c0 = np.asarray(gencost[:, 6], dtype=float)

if np.max(np.abs(c2)) > 1e-12:
    raise ValueError(
        "This sparse-HiGHS route expects linear generator costs, but a nonzero "
        "quadratic coefficient was found."
    )

c = np.zeros(N_VAR, dtype=float)
c[PG0:PG0 + n_gen] = c1
constant_cost = float(np.sum(c0))

Zbg = sp.csc_matrix((n_bus, n_gen))
A_eq = sp.hstack((-Cg, Zbg, Bbus), format="csc")
b_eq = -np.asarray(buses[:, 2], dtype=float)

Ig = sp.eye(n_gen, format="csc")
Zgg = sp.csc_matrix((n_gen, n_gen))
Zgphi = sp.csc_matrix((n_gen, n_bus))

A_coupling = sp.hstack((Ig, Ig, Zgphi), format="csc")
b_coupling = np.asarray(gens[:, 8], dtype=float)

A_reserve = sp.csc_matrix(
    (
        -np.ones(n_gen),
        (np.zeros(n_gen, dtype=int), RG0 + np.arange(n_gen)),
    ),
    shape=(1, N_VAR),
)
b_reserve = np.asarray([-reserve_requirement], dtype=float)

Zline_g = sp.csc_matrix((n_limited, n_gen))
A_line_upper = sp.hstack((Zline_g, Zline_g, Bf), format="csc")
A_line_lower = sp.hstack((Zline_g, Zline_g, -Bf), format="csc")

A_ub = sp.vstack(
    (A_coupling, A_reserve, A_line_upper, A_line_lower), format="csc"
)
b_ub = np.concatenate((b_coupling, b_reserve, line_rates, line_rates))

ROW_COUPLING = 0
ROW_RESERVE = n_gen
ROW_LINE_UPPER = n_gen + 1
ROW_LINE_LOWER = ROW_LINE_UPPER + n_limited

target_line_local_row = branch_to_limited_row[target_branch_idx]
base_target_limit = float(branches[target_branch_idx, 5])
cf_target_limit = base_target_limit * (1.0 + SCENARIO_DELTA_PCT / 100.0)

lb = np.full(N_VAR, -np.inf, dtype=float)
ub = np.full(N_VAR, np.inf, dtype=float)
lb[PG0:PG0 + n_gen] = gens[:, 9]
ub[PG0:PG0 + n_gen] = gens[:, 8]
lb[RG0:RG0 + n_gen] = 0.0
ub[RG0:RG0 + n_gen] = reserve_capacity
lb[PHI0 + slack_idx] = 0.0
ub[PHI0 + slack_idx] = 0.0
bounds = np.column_stack((lb, ub))

t_build = time.perf_counter() - t_build_start

print(
    f"Target line {SCENARIO_FROM_BUS}<->{SCENARIO_TO_BUS}: "
    f"{base_target_limit:.3f} -> {cf_target_limit:.3f} MW"
)
print(
    f"LP: {N_VAR} variables, {A_eq.shape[0]} equalities, "
    f"{A_ub.shape[0]} inequalities, "
    f"Aeq.nnz={A_eq.nnz}, Aub.nnz={A_ub.nnz}"
)


def result_to_report(res, rates, label, this_b_ub):
    z = np.asarray(res.x, dtype=float)
    Pg = z[PG0:PG0 + n_gen]
    Rg = z[RG0:RG0 + n_gen]
    phi = z[PHI0:PHI0 + n_bus]

    violation = max_primal_violation(
        z, A_ub, this_b_ub, A_eq, b_eq, lb, ub
    )
    if violation > 1e-3:
        raise RuntimeError(
            f"{label}: max primal constraint violation {violation:.6g} MW"
        )

    total_cost = float(c1 @ Pg + constant_cost)

    eq_marginals = np.asarray(res.eqlin.marginals, dtype=float)
    lmp = -eq_marginals[:n_bus]
    lmp_by_bus = [
        {
            "bus": int(buses[i, 0]),
            "lmp_dollars_per_MWh": round(float(lmp[i]), 2),
        }
        for i in range(n_bus)
    ]

    reserve_marginals = np.asarray(res.ineqlin.marginals, dtype=float)
    reserve_mcp = max(0.0, -float(reserve_marginals[ROW_RESERVE]))

    flows = np.asarray(Bf @ phi).reshape(-1)
    loading = np.abs(flows) / rates
    binding_idx = np.flatnonzero(loading >= BINDING_THRESHOLD)

    binding_lines = []
    for local_row in binding_idx:
        branch_idx = line_branch_indices[int(local_row)]
        br = branches[branch_idx]
        binding_lines.append(
            {
                "from": int(br[0]),
                "to": int(br[1]),
                "flow_MW": round(float(flows[local_row]), 2),
                "limit_MW": round(float(rates[local_row]), 2),
            }
        )

    print(
        f"{label}: cost=${total_cost:.2f}/hr, "
        f"HiGHS nit={res.nit}, max_violation={violation:.3e} MW, "
        f"binding_lines={len(binding_lines)}"
    )

    return {
        "total_cost_dollars_per_hour": round(total_cost, 2),
        "lmp_by_bus": lmp_by_bus,
        "reserve_mcp_dollars_per_MWh": round(float(reserve_mcp), 2),
        "binding_lines": binding_lines,
    }


base_raw, t_base_solve = solve_lp(
    c, A_ub, b_ub, A_eq, b_eq, bounds, "Base case"
)
base_rates = line_rates.copy()
base_report = result_to_report(base_raw, base_rates, "Base case", b_ub)

b_ub_cf = b_ub.copy()
b_ub_cf[ROW_LINE_UPPER + target_line_local_row] = cf_target_limit
b_ub_cf[ROW_LINE_LOWER + target_line_local_row] = cf_target_limit
cf_rates = line_rates.copy()
cf_rates[target_line_local_row] = cf_target_limit

cf_raw, t_cf_solve = solve_lp(
    c, A_ub, b_ub_cf, A_eq, b_eq, bounds, "Counterfactual"
)
cf_report = result_to_report(cf_raw, cf_rates, "Counterfactual", b_ub_cf)

cost_reduction = (
    base_report["total_cost_dollars_per_hour"]
    - cf_report["total_cost_dollars_per_hour"]
)

base_lmp = {
    e["bus"]: e["lmp_dollars_per_MWh"] for e in base_report["lmp_by_bus"]
}
cf_lmp = {
    e["bus"]: e["lmp_dollars_per_MWh"] for e in cf_report["lmp_by_bus"]
}

lmp_deltas = []
for bus_num in base_lmp:
    b = base_lmp[bus_num]
    cfl = cf_lmp[bus_num]
    lmp_deltas.append(
        {
            "bus": int(bus_num),
            "base_lmp": b,
            "cf_lmp": cfl,
            "delta": round(cfl - b, 2),
        }
    )
lmp_deltas.sort(key=lambda e: e["delta"])


def target_is_binding(binding_lines):
    for line in binding_lines:
        a, b = int(line["from"]), int(line["to"])
        if {a, b} == {SCENARIO_FROM_BUS, SCENARIO_TO_BUS}:
            return True
    return False


was_binding = target_is_binding(base_report["binding_lines"])
is_still_binding = target_is_binding(cf_report["binding_lines"])
congestion_relieved = bool(was_binding and not is_still_binding)

report = {
    "base_case": base_report,
    "counterfactual": cf_report,
    "impact_analysis": {
        "cost_reduction_dollars_per_hour": round(float(cost_reduction), 2),
        "buses_with_largest_lmp_drop": lmp_deltas[:3],
        "congestion_relieved": congestion_relieved,
    },
}

with open(REPORT_FILE, "w", encoding="utf-8") as f:
    json.dump(report, f, indent=2)

elapsed_all = time.perf_counter() - t_all
print("\n" + "=" * 64)
print("SPARSE HiGHS PERFORMANCE")
print("=" * 64)
print(f"matrix/model build:       {t_build:.3f} s")
print(f"base solve:               {t_base_solve:.3f} s")
print(f"counterfactual solve:     {t_cf_solve:.3f} s")
print(f"total Python phase:       {elapsed_all:.3f} s")
print(f"cost reduction:           ${cost_reduction:.2f}/hr")
print(f"congestion relieved:      {congestion_relieved}")
print(f"report:                    {REPORT_FILE}")
PY
