#!/bin/bash
set -euo pipefail

NETWORK_PATH="/root/network.json"
REPORT_PATH="/root/report.json"
AUDIT_PATH="/root/dispatch_audit.json"
MODEL_SUMMARY_PATH="/root/opf_model_summary.json"

if ! python3 - <<'PY' >/dev/null 2>&1
import numpy
import scipy
PY
then
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -qq
    apt-get install -y --no-install-recommends python3-numpy python3-scipy
fi

rm -f /root/report.json /root/report.json.tmp

echo "Solution build: full-angle-dense-ptdf-v5-20260730"

python3 -u <<'PY'
import json
import math
import os
import time

import numpy as np
from scipy import sparse
from scipy.optimize import linprog
from scipy.sparse.csgraph import connected_components
from scipy.sparse.linalg import splu

NETWORK_PATH = "/root/network.json"
REPORT_PATH = "/root/report.json"
AUDIT_PATH = "/root/dispatch_audit.json"
MODEL_SUMMARY_PATH = "/root/opf_model_summary.json"

SEGMENTS_PER_GENERATOR = 24
FEASIBILITY_TOL_MW = 0.08
OPTIMALITY_TOL = 2e-6


def as_1d(values, name):
    array = np.asarray(values, dtype=float).reshape(-1)
    if not np.all(np.isfinite(array)):
        raise RuntimeError(f"{name} contains non-finite values")
    return array


def load_network(path):
    with open(path, "r", encoding="utf-8") as handle:
        raw = json.load(handle)

    required = ("baseMVA", "bus", "gen", "branch", "gencost", "reserve_capacity", "reserve_requirement")
    missing = [name for name in required if name not in raw]
    if missing:
        raise RuntimeError(f"Missing network fields: {missing}")

    network = {
        "name": raw.get("name", "power_network"),
        "base_mva": float(raw["baseMVA"]),
        "buses": np.asarray(raw["bus"], dtype=float),
        "generators": np.asarray(raw["gen"], dtype=float),
        "branches": np.asarray(raw["branch"], dtype=float),
        "costs": np.asarray(raw["gencost"], dtype=float),
        "reserve_capacity": as_1d(raw["reserve_capacity"], "reserve_capacity"),
        "reserve_requirement": float(raw["reserve_requirement"]),
    }

    buses = network["buses"]
    generators = network["generators"]
    branches = network["branches"]
    costs = network["costs"]
    n_bus = len(buses)
    n_gen = len(generators)

    if buses.ndim != 2 or buses.shape[1] < 3:
        raise RuntimeError("MATPOWER bus table is incomplete")
    if generators.ndim != 2 or generators.shape[1] < 10:
        raise RuntimeError("MATPOWER generator table is incomplete")
    if branches.ndim != 2 or branches.shape[1] < 6:
        raise RuntimeError("MATPOWER branch table is incomplete")
    if costs.ndim != 2 or costs.shape[1] < 7 or len(costs) != n_gen:
        raise RuntimeError("MATPOWER generator cost table is inconsistent")
    if len(network["reserve_capacity"]) != n_gen:
        raise RuntimeError("reserve_capacity length does not match the generator table")
    if network["base_mva"] <= 0:
        raise RuntimeError("baseMVA must be positive")
    if network["reserve_requirement"] < 0 or np.any(network["reserve_capacity"] < 0):
        raise RuntimeError("Reserve data must be non-negative")
    if not np.all(costs[:, 0] == 2) or not np.all(costs[:, 3] == 3):
        raise RuntimeError("This solution requires quadratic polynomial MATPOWER costs")
    if np.any(costs[:, 4] < 0):
        raise RuntimeError("Quadratic cost coefficients must be convex")

    bus_numbers = buses[:, 0].astype(int)
    if len(set(bus_numbers.tolist())) != n_bus:
        raise RuntimeError("Duplicate bus numbers")
    network["bus_numbers"] = bus_numbers
    network["bus_index"] = {number: index for index, number in enumerate(bus_numbers)}

    slack = np.flatnonzero(buses[:, 1] == 3)
    if len(slack) != 1:
        raise RuntimeError(f"Expected exactly one slack bus, found {len(slack)}")
    network["slack"] = int(slack[0])

    pmax_raw = generators[:, 8].copy()
    pmin_raw = generators[:, 9].copy()
    if np.any(pmax_raw < pmin_raw):
        raise RuntimeError("Generator PMAX is below PMIN")

    network["pmax_raw"] = pmax_raw
    network["pmin"] = pmin_raw
    network["pmax"] = pmax_raw
    network["branch_status"] = np.ones(len(branches), dtype=bool)
    return network


def build_canonical_dc_model(network):
    buses = network["buses"]
    generators = network["generators"]
    branches = network["branches"]
    bus_index = network["bus_index"]
    base_mva = network["base_mva"]
    n_bus = len(buses)
    n_gen = len(generators)

    active_branch_indices = np.flatnonzero(network["branch_status"])
    if len(active_branch_indices) == 0:
        raise RuntimeError("The network has no active branches")
    active_branches = branches[active_branch_indices]

    from_bus = np.asarray([bus_index[int(row[0])] for row in active_branches], dtype=int)
    to_bus = np.asarray([bus_index[int(row[1])] for row in active_branches], dtype=int)
    reactance = active_branches[:, 3]
    if np.any(np.abs(reactance) < 1e-12):
        raise RuntimeError("Zero-reactance active branches are unsupported")

    branch_b = 1.0 / reactance
    rows = np.repeat(np.arange(len(active_branches)), 2)
    cols = np.column_stack((from_bus, to_bus)).reshape(-1)
    data = np.tile(np.asarray([1.0, -1.0]), len(active_branches))
    incidence = sparse.coo_matrix((data, (rows, cols)), shape=(len(active_branches), n_bus)).tocsr()

    adjacency = (abs(incidence).T @ abs(incidence)).tocsr()
    components, labels = connected_components(adjacency, directed=False)
    if components != 1:
        counts = np.bincount(labels)
        raise RuntimeError(f"The active network is disconnected into {components} islands: {counts.tolist()}")

    b_bus = (incidence.T @ sparse.diags(branch_b) @ incidence).tocsr()
    non_slack = np.delete(np.arange(n_bus), network["slack"])
    reduced_b = b_bus[non_slack][:, non_slack].tocsc()
    factorization = splu(reduced_b)

    gen_bus_index = np.asarray([bus_index[int(row[0])] for row in generators], dtype=int)
    generator_incidence = sparse.coo_matrix(
        (np.ones(n_gen), (gen_bus_index, np.arange(n_gen))),
        shape=(n_bus, n_gen),
    ).tocsr()

    flow_offset_mw = np.zeros(len(active_branches))
    bus_offset_mw = np.zeros(n_bus)
    flow_theta_matrix = (sparse.diags(branch_b) @ incidence[:, non_slack] * base_mva).tocsr()
    nodal_theta_matrix = (b_bus[:, non_slack] * base_mva).tocsr()

    ratings = active_branches[:, 5].copy()
    constrained_branch_mask = ratings > 0

    return {
        "active_branch_indices": active_branch_indices,
        "active_branches": active_branches,
        "from_bus": from_bus,
        "to_bus": to_bus,
        "branch_b": branch_b,
        "incidence": incidence,
        "b_bus": b_bus,
        "non_slack": non_slack,
        "factorization": factorization,
        "generator_incidence": generator_incidence,
        "flow_offset_mw": flow_offset_mw,
        "bus_offset_mw": bus_offset_mw,
        "flow_theta_matrix": flow_theta_matrix,
        "nodal_theta_matrix": nodal_theta_matrix,
        "ratings": ratings,
        "constrained_branch_mask": constrained_branch_mask,
    }


def stack_rows(rows, n_columns):
    if not rows:
        return sparse.csr_matrix((0, n_columns))
    return sparse.vstack(rows, format="csr")


def build_piecewise_lp(network, model):
    n_gen = len(network["generators"])
    n_theta = len(model["non_slack"])
    pmin = network["pmin"]
    pmax = network["pmax"]
    reserve_cap = network["reserve_capacity"]
    costs = network["costs"]
    load = network["buses"][:, 2]

    segment_gen = []
    segment_width = []
    segment_cost = []
    for gen_index in range(n_gen):
        span = pmax[gen_index] - pmin[gen_index]
        if span <= 1e-12:
            continue
        width = span / SEGMENTS_PER_GENERATOR
        c2, c1 = costs[gen_index, 4], costs[gen_index, 5]
        for segment in range(SEGMENTS_PER_GENERATOR):
            midpoint = pmin[gen_index] + (segment + 0.5) * width
            segment_gen.append(gen_index)
            segment_width.append(width)
            segment_cost.append(2.0 * c2 * midpoint + c1)

    n_segment = len(segment_gen)
    segment_map = sparse.coo_matrix(
        (
            np.ones(n_segment),
            (np.asarray(segment_gen, dtype=int), np.arange(n_segment)),
        ),
        shape=(n_gen, n_segment),
    ).tocsr()

    n_var = n_segment + n_gen + n_theta
    zero_bus_reserve = sparse.csr_matrix((len(load), n_gen))
    a_eq = sparse.hstack(
        [
            model["generator_incidence"] @ segment_map,
            zero_bus_reserve,
            -model["nodal_theta_matrix"],
        ],
        format="csr",
    )
    b_eq = load + model["bus_offset_mw"] - model["generator_incidence"] @ pmin

    rows = []
    rhs = []

    rows.append(
        sparse.hstack(
            [segment_map, sparse.eye(n_gen, format="csr"), sparse.csr_matrix((n_gen, n_theta))],
            format="csr",
        )
    )
    rhs.append(pmax - pmin)

    rows.append(
        sparse.hstack(
            [sparse.csr_matrix((1, n_segment)), -np.ones((1, n_gen)), sparse.csr_matrix((1, n_theta))],
            format="csr",
        )
    )
    rhs.append(np.asarray([-network["reserve_requirement"]]))

    constrained = np.flatnonzero(model["constrained_branch_mask"])
    if len(constrained):
        flow_matrix = model["flow_theta_matrix"][constrained]
        offset = model["flow_offset_mw"][constrained]
        limits = model["ratings"][constrained]
        left_zeros = sparse.csr_matrix((len(constrained), n_segment + n_gen))
        rows.append(sparse.hstack([left_zeros, flow_matrix], format="csr"))
        rhs.append(limits - offset)
        rows.append(sparse.hstack([left_zeros, -flow_matrix], format="csr"))
        rhs.append(limits + offset)

    a_ub = stack_rows(rows, n_var)
    b_ub = np.concatenate(rhs)
    objective = np.concatenate(
        [np.asarray(segment_cost), np.zeros(n_gen + n_theta)]
    )
    bounds = (
        [(0.0, float(width)) for width in segment_width]
        + [(0.0, float(cap)) for cap in reserve_cap]
        + [(None, None)] * n_theta
    )

    return {
        "objective": objective,
        "a_eq": a_eq,
        "b_eq": np.asarray(b_eq).reshape(-1),
        "a_ub": a_ub,
        "b_ub": b_ub,
        "bounds": bounds,
        "segment_map": segment_map,
        "n_segment": n_segment,
        "n_var": n_var,
    }


def solve_piecewise_master(network, model, lp_model):
    started = time.monotonic()
    result = linprog(
        lp_model["objective"],
        A_ub=lp_model["a_ub"],
        b_ub=lp_model["b_ub"],
        A_eq=lp_model["a_eq"],
        b_eq=lp_model["b_eq"],
        bounds=lp_model["bounds"],
        method="highs",
        options={"presolve": True},
    )
    elapsed = time.monotonic() - started
    if not result.success:
        raise RuntimeError(f"Piecewise-linear master failed: {result.message}")

    n_segment = lp_model["n_segment"]
    n_gen = len(network["generators"])
    pmin = network["pmin"]
    y = result.x[:n_segment]
    reserve_availability = result.x[n_segment:n_segment + n_gen]
    theta = result.x[n_segment + n_gen:]
    pg = pmin + np.asarray(lp_model["segment_map"] @ y).reshape(-1)

    return {
        "pg": pg,
        "reserve_availability": reserve_availability,
        "theta": theta,
        "solver_seconds": elapsed,
        "iterations": int(getattr(result, "nit", 0)),
        "message": result.message,
        "piecewise_objective": float(result.fun),
    }


def exact_cost(pg, costs):
    return float(np.sum(costs[:, 4] * pg * pg + costs[:, 5] * pg + costs[:, 6]))



def allocate_reserve(network, pg):
    requirement = network["reserve_requirement"]
    available = np.minimum(
        network["reserve_capacity"], np.maximum(network["pmax"] - pg, 0.0)
    )
    if requirement <= 1e-10:
        return {
            "reserve": np.zeros_like(pg),
            "available": available,
            "max_utilization": 0.0,
            "solver_seconds": 0.0,
            "iterations": 0,
        }
    if np.sum(available) + FEASIBILITY_TOL_MW < requirement:
        raise RuntimeError(
            f"Insufficient post-dispatch reserve headroom: {np.sum(available)} < {requirement}"
        )

    n_gen = len(pg)
    objective = np.concatenate([np.zeros(n_gen), np.ones(1)])
    a_eq = np.zeros((1, n_gen + 1))
    a_eq[0, :n_gen] = 1.0
    b_eq = np.asarray([requirement])
    a_ub = np.zeros((n_gen, n_gen + 1))
    a_ub[:, :n_gen] = np.eye(n_gen)
    a_ub[:, n_gen] = -available
    b_ub = np.zeros(n_gen)
    bounds = [(0.0, float(value)) for value in available] + [(0.0, 1.0)]

    started = time.monotonic()
    result = linprog(
        objective,
        A_ub=a_ub,
        b_ub=b_ub,
        A_eq=a_eq,
        b_eq=b_eq,
        bounds=bounds,
        method="highs",
        options={"presolve": True},
    )
    elapsed = time.monotonic() - started
    if not result.success:
        raise RuntimeError(f"Reserve allocation LP failed: {result.message}")

    reserve = np.asarray(result.x[:n_gen]).reshape(-1)
    return {
        "reserve": reserve,
        "available": available,
        "max_utilization": float(result.x[n_gen]),
        "solver_seconds": elapsed,
        "iterations": int(getattr(result, "nit", 0)),
    }


def physical_load_flow(network, model, pg):
    load = network["buses"][:, 2]
    injection = np.asarray(model["generator_incidence"] @ pg).reshape(-1) - load
    rhs = (injection - model["bus_offset_mw"])[model["non_slack"]] / network["base_mva"]
    theta = np.zeros(len(load))
    theta[model["non_slack"]] = model["factorization"].solve(rhs)
    flows = (
        model["branch_b"]
        * (theta[model["from_bus"]] - theta[model["to_bus"]])
        * network["base_mva"]
        + model["flow_offset_mw"]
    )
    reconstructed = np.asarray(model["b_bus"] @ theta).reshape(-1) * network["base_mva"] + model["bus_offset_mw"]
    residual = injection - reconstructed
    return {
        "theta": theta,
        "flows": flows,
        "power_imbalance_MW": float(abs(np.sum(injection))),
        "max_nodal_residual_MW": float(np.max(np.abs(residual))),
    }


def validate_final(network, model, exact, reserve, load_flow):
    pg = exact["pg"]
    r = reserve["reserve"]
    constrained = model["constrained_branch_mask"]
    line_violation = 0.0
    if np.any(constrained):
        line_violation = float(
            np.max(
                np.maximum(
                    np.abs(load_flow["flows"][constrained]) - model["ratings"][constrained],
                    0.0,
                )
            )
        )

    checks = {
        "generation_balance_MW": float(abs(np.sum(pg) - np.sum(network["buses"][:, 2]))),
        "reserve_shortfall_MW": float(max(network["reserve_requirement"] - np.sum(r), 0.0)),
        "generator_lower_violation_MW": float(np.max(np.maximum(network["pmin"] - pg, 0.0))),
        "generator_upper_violation_MW": float(np.max(np.maximum(pg - network["pmax"], 0.0))),
        "reserve_capacity_violation_MW": float(np.max(np.maximum(r - network["reserve_capacity"], 0.0))),
        "capacity_coupling_violation_MW": float(np.max(np.maximum(pg + r - network["pmax"], 0.0))),
        "line_limit_violation_MW": line_violation,
        "power_imbalance_MW": load_flow["power_imbalance_MW"],
        "max_nodal_residual_MW": load_flow["max_nodal_residual_MW"],
    }
    if any(value > FEASIBILITY_TOL_MW for value in checks.values()):
        raise RuntimeError(f"Final dispatch failed the physical audit: {checks}")
    return checks


def build_dense_spectral_audit(network, model, pg, sparse_flows):
    """Construct a complete dense spectral PTDF representation and cross-check flows.

    This is intentionally a different network representation from the sparse
    angle formulation used for dispatch.  It materializes the full reduced-B
    eigensystem, inverse, bus-to-line PTDF, and generator-to-line sensitivity.
    The additional memory and computation are intrinsic to this consensus path.
    """
    started = time.monotonic()
    reduced_dense = np.asarray(
        model["b_bus"][model["non_slack"]][:, model["non_slack"]].toarray(),
        dtype=np.float64,
        order="F",
    )
    eigenvalues, eigenvectors = np.linalg.eigh(reduced_dense)
    if eigenvalues[0] <= 1e-12:
        raise RuntimeError("Reduced susceptance matrix is not positive definite")

    scaled_vectors = eigenvectors / eigenvalues[np.newaxis, :]
    reduced_inverse = scaled_vectors @ eigenvectors.T

    reduced_incidence = np.asarray(
        model["incidence"][:, model["non_slack"]].toarray(), dtype=np.float64
    )
    ptdf_bus = (model["branch_b"][:, None] * reduced_incidence) @ reduced_inverse
    gen_reduced = np.asarray(
        model["generator_incidence"][model["non_slack"], :].toarray(),
        dtype=np.float64,
    )
    ptdf_generator = ptdf_bus @ gen_reduced
    reduced_load = network["buses"][model["non_slack"], 2]
    spectral_flows = ptdf_generator @ pg - ptdf_bus @ reduced_load
    max_difference = float(np.max(np.abs(spectral_flows - sparse_flows)))
    if max_difference > 0.08:
        raise RuntimeError(
            f"Sparse-angle and dense-spectral flows disagree by {max_difference} MW"
        )
    return {
        "seconds": time.monotonic() - started,
        "max_flow_difference_MW": max_difference,
        "reduced_dense": reduced_dense,
        "eigenvalues": eigenvalues,
        "eigenvectors": eigenvectors,
        "reduced_inverse": reduced_inverse,
        "ptdf_bus": ptdf_bus,
        "ptdf_generator": ptdf_generator,
        "spectral_flows": spectral_flows,
    }


def solve_dense_ptdf_outer_approximation(network, model, spectral, incumbent_pg, incumbent_cost):
    """Solve an independent dense PTDF cost-epigraph master.

    The model uses direct generator outputs, reserve variables, and one cost
    epigraph per generator.  Every constrained line is present simultaneously
    through the fully materialized generator shift-factor matrix.  Tangent cuts
    are refined until the master lower bound nearly meets the feasible incumbent.
    """
    started = time.monotonic()
    n_gen = len(network["generators"])
    n_var = 3 * n_gen
    pmin = network["pmin"]
    pmax = network["pmax"]
    costs = network["costs"]
    load_total = float(np.sum(network["buses"][:, 2]))

    constrained = np.flatnonzero(model["constrained_branch_mask"])
    hgen = spectral["ptdf_generator"][constrained]
    hload = spectral["ptdf_bus"][constrained] @ network["buses"][model["non_slack"], 2]
    limits = model["ratings"][constrained]

    base_rows = 2 * len(constrained) + n_gen + 1
    base_a = np.zeros((base_rows, n_var), dtype=np.float64)
    base_b = np.empty(base_rows, dtype=np.float64)
    cursor = 0
    base_a[cursor:cursor + len(constrained), :n_gen] = hgen
    base_b[cursor:cursor + len(constrained)] = limits + hload
    cursor += len(constrained)
    base_a[cursor:cursor + len(constrained), :n_gen] = -hgen
    base_b[cursor:cursor + len(constrained)] = limits - hload
    cursor += len(constrained)
    idx = np.arange(n_gen)
    base_a[cursor + idx, idx] = 1.0
    base_a[cursor + idx, n_gen + idx] = 1.0
    base_b[cursor:cursor + n_gen] = pmax
    cursor += n_gen
    base_a[cursor, n_gen:2 * n_gen] = -1.0
    base_b[cursor] = -network["reserve_requirement"]

    tangent_points = [pmin.copy(), 0.5 * (pmin + pmax), pmax.copy(), incumbent_pg.copy()]
    objective = np.concatenate([np.zeros(2 * n_gen), np.ones(n_gen)])
    a_eq = np.zeros((1, n_var), dtype=np.float64)
    a_eq[0, :n_gen] = 1.0
    b_eq = np.asarray([load_total])
    bounds = (
        [(float(pmin[i]), float(pmax[i])) for i in range(n_gen)]
        + [(0.0, float(network["reserve_capacity"][i])) for i in range(n_gen)]
        + [(None, None)] * n_gen
    )

    history = []
    retained_a = None
    retained_b = None
    last_result = None
    best_pg = incumbent_pg.copy()
    best_cost = float(incumbent_cost)
    for iteration in range(1, 13):
        n_tangent_sets = len(tangent_points)
        tangent_a = np.zeros((n_tangent_sets * n_gen, n_var), dtype=np.float64)
        tangent_b = np.empty(n_tangent_sets * n_gen, dtype=np.float64)
        row = 0
        for points in tangent_points:
            derivative = 2.0 * costs[:, 4] * points + costs[:, 5]
            value = costs[:, 4] * points * points + costs[:, 5] * points + costs[:, 6]
            rows = row + np.arange(n_gen)
            tangent_a[rows, np.arange(n_gen)] = derivative
            tangent_a[rows, 2 * n_gen + np.arange(n_gen)] = -1.0
            tangent_b[rows] = derivative * points - value
            row += n_gen

        retained_a = np.vstack([base_a, tangent_a])
        retained_b = np.concatenate([base_b, tangent_b])
        result = linprog(
            objective,
            A_ub=retained_a,
            b_ub=retained_b,
            A_eq=a_eq,
            b_eq=b_eq,
            bounds=bounds,
            method="highs",
            options={"presolve": True},
        )
        if not result.success:
            raise RuntimeError(f"Dense PTDF epigraph master failed: {result.message}")
        pg = np.asarray(result.x[:n_gen]).reshape(-1)
        true_cost = exact_cost(pg, costs)
        lower_bound = float(result.fun)
        if true_cost < best_cost:
            best_cost = true_cost
            best_pg = pg.copy()
        incumbent_gap = best_cost - lower_bound
        history.append(
            {
                "iteration": iteration,
                "rows": int(retained_a.shape[0]),
                "lower_bound": lower_bound,
                "candidate_true_cost": true_cost,
                "incumbent_gap": incumbent_gap,
            }
        )
        last_result = result
        if incumbent_gap <= 0.05:
            break
        tangent_points.append(pg.copy())

    if best_cost + 0.05 < float(last_result.fun):
        raise RuntimeError("Dense PTDF lower bound exceeds the best feasible dispatch")
    return {
        "seconds": time.monotonic() - started,
        "history": history,
        "lower_bound": float(last_result.fun),
        "candidate_pg": np.asarray(last_result.x[:n_gen]).reshape(-1),
        "candidate_true_cost": exact_cost(last_result.x[:n_gen], costs),
        "best_pg": best_pg,
        "best_cost": best_cost,
        "constraint_matrix": retained_a,
        "constraint_rhs": retained_b,
    }


def rounded(value):
    result = round(float(value), 2)
    return 0.0 if abs(result) < 0.005 else result


def build_report(network, model, exact, reserve, load_flow):
    generators = network["generators"]
    pg_report = [rounded(value) for value in exact["pg"]]
    reserve_report = [rounded(value) for value in reserve["reserve"]]

    dispatch = []
    for index in range(len(generators)):
        dispatch.append(
            {
                "id": index + 1,
                "bus": int(generators[index, 0]),
                "output_MW": pg_report[index],
                "reserve_MW": reserve_report[index],
                "pmax_MW": rounded(network["pmax_raw"][index]),
            }
        )

    loading = np.full(len(model["active_branches"]), -np.inf)
    positive_rating = model["ratings"] > 0
    loading[positive_rating] = (
        np.abs(load_flow["flows"][positive_rating])
        / model["ratings"][positive_rating]
        * 100.0
    )
    eligible = np.flatnonzero(np.isfinite(loading))
    ordered = eligible[np.argsort(-loading[eligible], kind="stable")[:3]]
    most_loaded = [
        {
            "from": int(model["active_branches"][index, 0]),
            "to": int(model["active_branches"][index, 1]),
            "loading_pct": rounded(loading[index]),
        }
        for index in ordered
    ]

    generation_total = rounded(sum(pg_report))
    reserve_total = rounded(sum(reserve_report))
    operating_margin = rounded(
        sum(
            item["pmax_MW"] - item["output_MW"] - item["reserve_MW"]
            for item in dispatch
        )
    )

    return {
        "generator_dispatch": dispatch,
        "totals": {
            "cost_dollars_per_hour": rounded(exact["cost"]),
            "load_MW": rounded(np.sum(network["buses"][:, 2])),
            "generation_MW": generation_total,
            "reserve_MW": reserve_total,
        },
        "most_loaded_lines": most_loaded,
        "operating_margin_MW": operating_margin,
    }


def atomic_json_write(path, value):
    temporary = path + ".tmp"
    with open(temporary, "w", encoding="utf-8") as handle:
        json.dump(value, handle, indent=2)
    os.replace(temporary, path)


overall_started = time.monotonic()
network = load_network(NETWORK_PATH)
model = build_canonical_dc_model(network)
print(
    f"Loaded {network['name']}: {len(network['buses'])} buses, "
    f"{len(network['generators'])} generators, "
    f"{len(model['active_branches'])} active branches"
)

lp_model = build_piecewise_lp(network, model)
atomic_json_write(
    MODEL_SUMMARY_PATH,
    {
        "method": "full_angle_piecewise_master_plus_dense_spectral_ptdf_outer_approximation",
        "segments_per_generator": SEGMENTS_PER_GENERATOR,
        "piecewise_variables": lp_model["n_var"],
        "piecewise_segments": lp_model["n_segment"],
        "piecewise_equalities": int(lp_model["a_eq"].shape[0]),
        "piecewise_inequalities": int(lp_model["a_ub"].shape[0]),
        "active_branches": int(len(model["active_branches"])),
        "constrained_branches": int(np.sum(model["constrained_branch_mask"])),
    },
)

warm_start = solve_piecewise_master(network, model, lp_model)
print(
    f"Piecewise master: variables={lp_model['n_var']}, "
    f"segments={lp_model['n_segment']}, iterations={warm_start['iterations']}"
)

piecewise_cost = exact_cost(warm_start["pg"], network["costs"])
print(f"Quadratic evaluation at master dispatch: cost=${piecewise_cost:.6f}/h")

warm_load_flow = physical_load_flow(network, model, warm_start["pg"])
spectral = build_dense_spectral_audit(
    network, model, warm_start["pg"], warm_load_flow["flows"]
)
print(
    f"Dense spectral consensus: seconds={spectral['seconds']:.3f}, "
    f"max_flow_difference={spectral['max_flow_difference_MW']:.6f} MW"
)
dense_master = solve_dense_ptdf_outer_approximation(
    network, model, spectral, warm_start["pg"], piecewise_cost
)
exact = {
    "pg": dense_master["best_pg"],
    "cost": dense_master["best_cost"],
}
print(
    f"Dense PTDF optimality certificate: seconds={dense_master['seconds']:.3f}, "
    f"iterations={len(dense_master['history'])}, "
    f"gap=${exact['cost'] - dense_master['lower_bound']:.6f}/h"
)

reserve = allocate_reserve(network, exact["pg"])
load_flow = physical_load_flow(network, model, exact["pg"])
final_spectral_flows = (
    spectral["ptdf_generator"] @ exact["pg"]
    - spectral["ptdf_bus"] @ network["buses"][model["non_slack"], 2]
)
final_flow_difference = float(np.max(np.abs(final_spectral_flows - load_flow["flows"])))
if final_flow_difference > FEASIBILITY_TOL_MW:
    raise RuntimeError(
        f"Final sparse-angle and dense-PTDF flows disagree by {final_flow_difference} MW"
    )
checks = validate_final(network, model, exact, reserve, load_flow)
report = build_report(network, model, exact, reserve, load_flow)

atomic_json_write(REPORT_PATH, report)
atomic_json_write(
    AUDIT_PATH,
    {
        "method": {
            "primary_master": "24-segment convex piecewise-linear full-angle DC-OPF",
            "dense_consensus": "complete spectral PTDF with dense quadratic-cost epigraph outer approximation",
            "reserve_allocation": "minimum maximum headroom-utilization LP",
            "physical_audit": "independent reduced-B DC load-flow reconstruction",
        },
        "piecewise_master": {
            "solver_seconds": warm_start["solver_seconds"],
            "iterations": warm_start["iterations"],
            "message": warm_start["message"],
            "piecewise_objective": warm_start["piecewise_objective"],
            "exact_cost_at_master_dispatch": exact_cost(warm_start["pg"], network["costs"]),
        },
        "dense_spectral_consensus": {
            "solver_seconds": spectral["seconds"],
            "initial_max_flow_difference_MW": spectral["max_flow_difference_MW"],
            "final_max_flow_difference_MW": final_flow_difference,
            "reduced_matrix_shape": list(spectral["reduced_dense"].shape),
            "ptdf_bus_shape": list(spectral["ptdf_bus"].shape),
            "ptdf_generator_shape": list(spectral["ptdf_generator"].shape),
        },
        "dense_ptdf_optimality_certificate": {
            "solver_seconds": dense_master["seconds"],
            "lower_bound": dense_master["lower_bound"],
            "best_feasible_cost": dense_master["best_cost"],
            "certified_gap": dense_master["best_cost"] - dense_master["lower_bound"],
            "constraint_matrix_shape": list(dense_master["constraint_matrix"].shape),
            "iterations": dense_master["history"],
        },
        "reserve_allocation": {
            "solver_seconds": reserve["solver_seconds"],
            "iterations": reserve["iterations"],
            "max_available_utilization": reserve["max_utilization"],
            "total_available_MW": float(np.sum(reserve["available"])),
            "allocated_MW": float(np.sum(reserve["reserve"])),
        },
        "physical_audit": checks,
        "overall_solver_seconds_excluding_package_install": time.monotonic() - overall_started,
    },
)

print(
    f"Dispatch complete: cost=${exact['cost']:.2f}/h, "
    f"reserve={np.sum(reserve['reserve']):.2f} MW, "
    f"overall_python_seconds={time.monotonic() - overall_started:.3f}"
)
PY
