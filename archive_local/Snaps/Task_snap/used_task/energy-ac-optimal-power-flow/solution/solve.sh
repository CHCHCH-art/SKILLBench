#!/bin/bash
set -euo pipefail

apt-get update -qq
apt-get install -y -qq libgfortran5 > /dev/null 2>&1

pip3 install --break-system-packages numpy==1.26.4 casadi==3.6.7 -q

python3 <<'PY'
"""
Cartesian lifted AC optimal power flow.

This is an alternative formulation of the model in /root/math-model.md (or the
network task's equivalent model document):

  * bus voltage is represented in rectangular coordinates V = E + jF;
  * forward/reverse branch complex powers are explicit decision variables;
  * branch-flow definition equations are local quadratic constraints;
  * bus balance uses sparse incidence matrices;
  * branch thermal limits are imposed directly on the explicit P/Q flows;
  * voltage-angle-difference limits are represented directly in the Cartesian
    plane when the admissible wedge is <= 180 degrees.

The formulation remains an exact, non-convex AC-OPF and is solved with IPOPT.
The report schema is unchanged from the task specification.
"""

from __future__ import annotations

import json
import math
from typing import Iterable

import casadi as ca
import numpy as np


NETWORK_PATH = "/root/network.json"
REPORT_PATH = "/root/report.json"
ANGLE_EPS = 1e-10


def deg2rad(x: float) -> float:
    return x * math.pi / 180.0


def sparse_selector(nrow: int, ncol: int, rows: Iterable[int], cols: Iterable[int]) -> ca.DM:
    """Sparse 0/1 matrix with one entry for each (row, col) pair."""
    rows = list(map(int, rows))
    cols = list(map(int, cols))
    sp = ca.Sparsity.triplet(nrow, ncol, rows, cols)
    return ca.DM(sp, [1.0] * len(rows))


def numeric_branch_flows(
    E: np.ndarray,
    F: np.ndarray,
    f: np.ndarray,
    t: np.ndarray,
    g: np.ndarray,
    bser: np.ndarray,
    bchg: np.ndarray,
    tap: np.ndarray,
    shift: np.ndarray,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    """Evaluate the pi-model branch flows in per unit from Cartesian voltages."""
    Ef = E[f]
    Ff = F[f]
    Et = E[t]
    Ft = F[t]

    vf2 = Ef * Ef + Ff * Ff
    vt2 = Et * Et + Ft * Ft
    dot = Ef * Et + Ff * Ft
    cross = Ff * Et - Ef * Ft

    cshift = np.cos(shift)
    sshift = np.sin(shift)
    inv_tap = 1.0 / tap
    inv_tap2 = inv_tap * inv_tap

    a = (dot * cshift + cross * sshift) * inv_tap
    c = (cross * cshift - dot * sshift) * inv_tap

    Pft = g * vf2 * inv_tap2 - (g * a + bser * c)
    Qft = -(bser + bchg / 2.0) * vf2 * inv_tap2 - (g * c - bser * a)
    Ptf = g * vt2 - g * a + bser * c
    Qtf = -(bser + bchg / 2.0) * vt2 + g * c + bser * a
    return Pft, Qft, Ptf, Qtf


def main() -> None:
    with open(NETWORK_PATH, encoding="utf-8") as fobj:
        data = json.load(fobj)

    baseMVA = float(data["baseMVA"])
    bus = np.asarray(data["bus"], dtype=float)
    gen = np.asarray(data["gen"], dtype=float)
    branch = np.asarray(data["branch"], dtype=float)
    gencost = np.asarray(data["gencost"], dtype=float)

    n_bus = int(bus.shape[0])
    n_gen = int(gen.shape[0])
    n_branch = int(branch.shape[0])

    bus_ids = bus[:, 0].astype(int)
    bus_type = bus[:, 1].astype(int)
    bus_id_to_idx = {int(bus_ids[i]): i for i in range(n_bus)}
    ref_indices = np.where(bus_type == 3)[0].astype(int)
    if len(ref_indices) == 0:
        raise RuntimeError("network has no reference/slack bus (BUS_TYPE=3)")

    print(
        f"n_bus={n_bus}, n_gen={n_gen}, n_branch={n_branch}, "
        f"ref_bus={[int(bus_ids[i]) for i in ref_indices]}"
    )

    Pd = bus[:, 2] / baseMVA
    Qd = bus[:, 3] / baseMVA
    Gs = bus[:, 4] / baseMVA
    Bs = bus[:, 5] / baseMVA
    Vm_input = bus[:, 7]
    Va_input = np.deg2rad(bus[:, 8])
    Vmax = bus[:, 11]
    Vmin = bus[:, 12]

    gen_bus = np.asarray([bus_id_to_idx[int(b)] for b in gen[:, 0]], dtype=int)
    Pg0 = gen[:, 1] / baseMVA
    Qg0 = gen[:, 2] / baseMVA
    Qmax = gen[:, 3] / baseMVA
    Qmin = gen[:, 4] / baseMVA
    Pmax = gen[:, 8] / baseMVA
    Pmin = gen[:, 9] / baseMVA

    if np.any(gencost[:, 0] != 2) or np.any(gencost[:, 3] != 3):
        raise RuntimeError("this implementation expects quadratic polynomial gencost rows (MODEL=2, NCOST=3)")
    c2 = gencost[:, 4]
    c1 = gencost[:, 5]
    c0 = gencost[:, 6]

    f = np.asarray([bus_id_to_idx[int(x)] for x in branch[:, 0]], dtype=int)
    t = np.asarray([bus_id_to_idx[int(x)] for x in branch[:, 1]], dtype=int)
    r = branch[:, 2]
    xbr = branch[:, 3]
    bchg = branch[:, 4]
    rate_pu = branch[:, 5] / baseMVA
    tap = np.where(np.abs(branch[:, 8]) < 1e-12, 1.0, branch[:, 8])
    shift = np.deg2rad(branch[:, 9])
    angmin = np.deg2rad(branch[:, 11])
    angmax = np.deg2rad(branch[:, 12])

    denom = r * r + xbr * xbr
    zero_impedance = denom < 1e-24
    g = np.zeros(n_branch)
    bser = np.zeros(n_branch)
    g[~zero_impedance] = r[~zero_impedance] / denom[~zero_impedance]
    bser[~zero_impedance] = -xbr[~zero_impedance] / denom[~zero_impedance]

    A_gen = sparse_selector(n_bus, n_gen, gen_bus, range(n_gen))
    A_from = sparse_selector(n_bus, n_branch, f, range(n_branch))
    A_to = sparse_selector(n_bus, n_branch, t, range(n_branch))

    E = ca.MX.sym("E", n_bus)
    F = ca.MX.sym("F", n_bus)
    Pg = ca.MX.sym("Pg", n_gen)
    Qg = ca.MX.sym("Qg", n_gen)
    Pft = ca.MX.sym("Pft", n_branch)
    Qft = ca.MX.sym("Qft", n_branch)
    Ptf = ca.MX.sym("Ptf", n_branch)
    Qtf = ca.MX.sym("Qtf", n_branch)

    Pg_MW_expr = Pg * baseMVA
    obj = ca.sum1(ca.DM(c2) * (Pg_MW_expr**2) + ca.DM(c1) * Pg_MW_expr + ca.DM(c0))

    Ef = E[f.tolist()]
    Ff = F[f.tolist()]
    Et = E[t.tolist()]
    Ft = F[t.tolist()]

    vf2 = Ef**2 + Ff**2
    vt2 = Et**2 + Ft**2
    dot = Ef * Et + Ff * Ft
    cross = Ff * Et - Ef * Ft

    cshift = ca.DM(np.cos(shift))
    sshift = ca.DM(np.sin(shift))
    inv_tap = ca.DM(1.0 / tap)
    inv_tap2 = ca.DM(1.0 / (tap * tap))
    g_dm = ca.DM(g)
    bser_dm = ca.DM(bser)
    bchg_dm = ca.DM(bchg)

    a = (dot * cshift + cross * sshift) * inv_tap
    c = (cross * cshift - dot * sshift) * inv_tap

    Pft_model = g_dm * vf2 * inv_tap2 - (g_dm * a + bser_dm * c)
    Qft_model = -(bser_dm + bchg_dm / 2.0) * vf2 * inv_tap2 - (g_dm * c - bser_dm * a)
    Ptf_model = g_dm * vt2 - g_dm * a + bser_dm * c
    Qtf_model = -(bser_dm + bchg_dm / 2.0) * vt2 + g_dm * c + bser_dm * a

    V2 = E**2 + F**2
    Pg_bus = ca.mtimes(A_gen, Pg)
    Qg_bus = ca.mtimes(A_gen, Qg)
    P_out = ca.mtimes(A_from, Pft) + ca.mtimes(A_to, Ptf)
    Q_out = ca.mtimes(A_from, Qft) + ca.mtimes(A_to, Qtf)

    g_expr: list[ca.MX] = []
    lbg: list[float] = []
    ubg: list[float] = []

    def add_vector(expr: ca.MX, lower, upper) -> None:
        n = int(expr.numel())
        g_expr.append(ca.reshape(expr, n, 1))
        if np.isscalar(lower):
            lbg.extend([float(lower)] * n)
        else:
            lbg.extend(np.asarray(lower, dtype=float).reshape(-1).tolist())
        if np.isscalar(upper):
            ubg.extend([float(upper)] * n)
        else:
            ubg.extend(np.asarray(upper, dtype=float).reshape(-1).tolist())

    add_vector(Pg_bus - ca.DM(Pd) - ca.DM(Gs) * V2 - P_out, 0.0, 0.0)
    add_vector(Qg_bus - ca.DM(Qd) + ca.DM(Bs) * V2 - Q_out, 0.0, 0.0)

    add_vector(Pft - Pft_model, 0.0, 0.0)
    add_vector(Qft - Qft_model, 0.0, 0.0)
    add_vector(Ptf - Ptf_model, 0.0, 0.0)
    add_vector(Qtf - Qtf_model, 0.0, 0.0)

    add_vector(V2, Vmin * Vmin, Vmax * Vmax)

    limited = np.where(rate_pu > 0.0)[0].astype(int)
    if len(limited):
        idx = limited.tolist()
        rate_sq = rate_pu[limited] ** 2
        add_vector(Pft[idx] ** 2 + Qft[idx] ** 2, 0.0, rate_sq)
        add_vector(Ptf[idx] ** 2 + Qtf[idx] ** 2, 0.0, rate_sq)

    for ell in range(n_branch):
        lo = float(angmin[ell])
        hi = float(angmax[ell])
        if hi < lo:
            raise RuntimeError(f"branch {ell}: ANGMAX < ANGMIN")

        if hi - lo >= 2.0 * math.pi - ANGLE_EPS:
            continue

        d = dot[ell]
        s = cross[ell]
        width = hi - lo
        if width <= math.pi + ANGLE_EPS:
            lower_half_plane = s * math.cos(lo) - d * math.sin(lo)
            upper_half_plane = s * math.cos(hi) - d * math.sin(hi)
            add_vector(lower_half_plane, 0.0, math.inf)
            add_vector(upper_half_plane, -math.inf, 0.0)
        else:
            angle = ca.atan2(s, d)
            lo_clip = max(lo, -math.pi)
            hi_clip = min(hi, math.pi)
            if lo_clip <= -math.pi + ANGLE_EPS and hi_clip >= math.pi - ANGLE_EPS:
                continue
            add_vector(angle, lo_clip, hi_clip)

    z = ca.vertcat(E, F, Pg, Qg, Pft, Qft, Ptf, Qtf)
    gvec = ca.vertcat(*g_expr)

    inf = float("inf")
    lb_E = -Vmax.copy()
    ub_E = Vmax.copy()
    lb_F = -Vmax.copy()
    ub_F = Vmax.copy()

    for i in ref_indices:
        lb_F[i] = 0.0
        ub_F[i] = 0.0
        lb_E[i] = Vmin[i]
        ub_E[i] = Vmax[i]

    flow_lb = -np.full(n_branch, inf)
    flow_ub = np.full(n_branch, inf)
    flow_lb[limited] = -rate_pu[limited]
    flow_ub[limited] = rate_pu[limited]

    lbx = np.concatenate(
        [lb_E, lb_F, Pmin, Qmin, flow_lb, flow_lb, flow_lb, flow_lb]
    ).tolist()
    ubx = np.concatenate(
        [ub_E, ub_F, Pmax, Qmax, flow_ub, flow_ub, flow_ub, flow_ub]
    ).tolist()

    Vm0 = np.where(Vm_input > 1e-6, Vm_input, 1.0)
    Va0 = np.where(np.isfinite(Va_input), Va_input, 0.0)
    E0 = Vm0 * np.cos(Va0)
    F0 = Vm0 * np.sin(Va0)
    for i in ref_indices:
        F0[i] = 0.0
        E0[i] = max(float(Vmin[i]), min(float(Vmax[i]), abs(float(E0[i]))))

    Pg_init = np.clip(Pg0, Pmin, Pmax)
    Qg_init = np.clip(Qg0, Qmin, Qmax)
    Pft0, Qft0, Ptf0, Qtf0 = numeric_branch_flows(
        E0, F0, f, t, g, bser, bchg, tap, shift
    )

    if len(limited):
        Pft0[limited] = np.clip(Pft0[limited], -rate_pu[limited], rate_pu[limited])
        Qft0[limited] = np.clip(Qft0[limited], -rate_pu[limited], rate_pu[limited])
        Ptf0[limited] = np.clip(Ptf0[limited], -rate_pu[limited], rate_pu[limited])
        Qtf0[limited] = np.clip(Qtf0[limited], -rate_pu[limited], rate_pu[limited])

    x0 = np.concatenate([E0, F0, Pg_init, Qg_init, Pft0, Qft0, Ptf0, Qtf0]).tolist()

    nlp = {"x": z, "f": obj, "g": gvec}
    opts = {
        "ipopt.print_level": 5,
        "ipopt.max_iter": 2000,
        "ipopt.tol": 1e-7,
        "ipopt.acceptable_tol": 1e-5,
        "ipopt.mu_strategy": "adaptive",
        "print_time": False,
    }
    solver = ca.nlpsol("solver", "ipopt", nlp, opts)

    print(f"Solving lifted Cartesian AC-OPF (n_var={int(z.numel())}, n_con={int(gvec.numel())}) ...")
    sol = solver(x0=x0, lbx=lbx, ubx=ubx, lbg=lbg, ubg=ubg)
    stats = solver.stats()
    if not bool(stats.get("success", False)):
        raise RuntimeError(f"IPOPT did not converge successfully: {stats.get('return_status', 'unknown')}")

    zopt = np.asarray(sol["x"]).reshape(-1)
    off = 0
    E_sol = zopt[off : off + n_bus]; off += n_bus
    F_sol = zopt[off : off + n_bus]; off += n_bus
    Pg_sol = zopt[off : off + n_gen]; off += n_gen
    Qg_sol = zopt[off : off + n_gen]; off += n_gen
    Pft_sol = zopt[off : off + n_branch]; off += n_branch
    Qft_sol = zopt[off : off + n_branch]; off += n_branch
    Ptf_sol = zopt[off : off + n_branch]; off += n_branch
    Qtf_sol = zopt[off : off + n_branch]

    Vm_sol = np.sqrt(E_sol * E_sol + F_sol * F_sol)
    Va_sol = np.arctan2(F_sol, E_sol)
    Va_deg = np.rad2deg(Va_sol)
    Pg_MW = Pg_sol * baseMVA
    Qg_MVAr = Qg_sol * baseMVA

    total_load_P = float(np.sum(Pd) * baseMVA)
    total_load_Q = float(np.sum(Qd) * baseMVA)
    total_gen_P = float(np.sum(Pg_MW))
    total_gen_Q = float(np.sum(Qg_MVAr))
    total_losses = total_gen_P - total_load_P
    total_cost = float(sol["f"])

    Pft_phy, Qft_phy, Ptf_phy, Qtf_phy = numeric_branch_flows(
        E_sol, F_sol, f, t, g, bser, bchg, tap, shift
    )

    branch_records = []
    max_over = 0.0
    for ell in range(n_branch):
        S_ft = math.hypot(float(Pft_phy[ell]), float(Qft_phy[ell])) * baseMVA
        S_tf = math.hypot(float(Ptf_phy[ell]), float(Qtf_phy[ell])) * baseMVA
        limit = float(rate_pu[ell] * baseMVA)
        loading = max(S_ft, S_tf) / limit * 100.0 if limit > 0.0 else 0.0
        if limit > 0.0:
            max_over = max(max_over, max(0.0, max(S_ft, S_tf) - limit))
        branch_records.append(
            {
                "from_bus": int(bus_ids[f[ell]]),
                "to_bus": int(bus_ids[t[ell]]),
                "loading_pct": loading,
                "flow_from_MVA": S_ft,
                "flow_to_MVA": S_tf,
                "limit_MVA": limit,
            }
        )

    Pg_bus_val = np.zeros(n_bus)
    Qg_bus_val = np.zeros(n_bus)
    np.add.at(Pg_bus_val, gen_bus, Pg_sol)
    np.add.at(Qg_bus_val, gen_bus, Qg_sol)

    P_out_val = np.zeros(n_bus)
    Q_out_val = np.zeros(n_bus)
    np.add.at(P_out_val, f, Pft_phy)
    np.add.at(P_out_val, t, Ptf_phy)
    np.add.at(Q_out_val, f, Qft_phy)
    np.add.at(Q_out_val, t, Qtf_phy)

    P_mis = Pg_bus_val - Pd - Gs * (Vm_sol**2) - P_out_val
    Q_mis = Qg_bus_val - Qd + Bs * (Vm_sol**2) - Q_out_val
    max_p_mis = float(np.max(np.abs(P_mis)) * baseMVA)
    max_q_mis = float(np.max(np.abs(Q_mis)) * baseMVA)
    max_v_vio = float(np.max(np.maximum(0.0, np.maximum(Vmin - Vm_sol, Vm_sol - Vmax))))

    max_flow_lift_resid = float(
        baseMVA
        * max(
            np.max(np.abs(Pft_sol - Pft_phy)),
            np.max(np.abs(Qft_sol - Qft_phy)),
            np.max(np.abs(Ptf_sol - Ptf_phy)),
            np.max(np.abs(Qtf_sol - Qtf_phy)),
        )
    )

    report = {
        "summary": {
            "total_cost_per_hour": round(total_cost, 2),
            "total_load_MW": round(total_load_P, 2),
            "total_load_MVAr": round(total_load_Q, 2),
            "total_generation_MW": round(total_gen_P, 2),
            "total_generation_MVAr": round(total_gen_Q, 2),
            "total_losses_MW": round(total_losses, 2),
            "solver_status": "optimal",
        },
        "generators": [
            {
                "id": k + 1,
                "bus": int(bus_ids[int(gen_bus[k])]),
                "pg_MW": round(float(Pg_MW[k]), 6),
                "qg_MVAr": round(float(Qg_MVAr[k]), 6),
                "pmin_MW": float(Pmin[k] * baseMVA),
                "pmax_MW": float(Pmax[k] * baseMVA),
                "qmin_MVAr": float(Qmin[k] * baseMVA),
                "qmax_MVAr": float(Qmax[k] * baseMVA),
            }
            for k in range(n_gen)
        ],
        "buses": [
            {
                "id": int(bus_ids[i]),
                "vm_pu": round(float(Vm_sol[i]), 6),
                "va_deg": round(float(Va_deg[i]), 6),
                "vmin_pu": float(Vmin[i]),
                "vmax_pu": float(Vmax[i]),
            }
            for i in range(n_bus)
        ],
        "most_loaded_branches": [
            {
                "from_bus": rec["from_bus"],
                "to_bus": rec["to_bus"],
                "loading_pct": round(float(rec["loading_pct"]), 2),
                "flow_from_MVA": round(float(rec["flow_from_MVA"]), 3),
                "flow_to_MVA": round(float(rec["flow_to_MVA"]), 3),
                "limit_MVA": round(float(rec["limit_MVA"]), 3),
            }
            for rec in sorted(branch_records, key=lambda item: item["loading_pct"], reverse=True)[:10]
        ],
        "feasibility_check": {
            "max_p_mismatch_MW": round(max_p_mis, 6),
            "max_q_mismatch_MVAr": round(max_q_mis, 6),
            "max_voltage_violation_pu": round(max_v_vio, 6),
            "max_branch_overload_MVA": round(max_over, 6),
        },
    }

    with open(REPORT_PATH, "w", encoding="utf-8") as fobj:
        json.dump(report, fobj, indent=2)

    print(f"Wrote {REPORT_PATH}")
    print(
        "Feasibility: "
        f"max|P_mis|={max_p_mis:.6f} MW, "
        f"max|Q_mis|={max_q_mis:.6f} MVAr, "
        f"maxVvio={max_v_vio:.6g} pu, "
        f"maxOver={max_over:.6f} MVA, "
        f"maxLiftFlowResidual={max_flow_lift_resid:.6f} MW/MVAr"
    )
    print(
        f"IPOPT: status={stats.get('return_status')}, "
        f"iterations={stats.get('iter_count', 'n/a')}"
    )


if __name__ == "__main__":
    main()
PY
