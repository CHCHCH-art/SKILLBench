#!/bin/bash
set -euo pipefail

python3 <<'PYTHON_SCRIPT'
import os
from pathlib import Path

import numpy as np
from scipy.sparse.linalg import eigs, ArpackNoConvergence

from qutip import (
    Qobj,
    qeye,
    destroy,
    tensor,
    to_super,
    liouvillian,
    spre,
    spost,
    super_tensor,
    operator_to_vector,
    vector_to_operator,
    fock_dm,
    wigner,
)
from qutip.piqs import Dicke, jspin, num_dicke_states, ground


env_output = os.getenv("OUTPUT_DIR")
output_dir = Path(env_output) if env_output else Path.cwd()
output_dir.mkdir(parents=True, exist_ok=True)
print(f"Saving CSV files to {output_dir}", flush=True)


N = 4
nds = num_dicke_states(N)

jx, jy, jz = jspin(N)
jp = jspin(N, "+")
jm = jp.dag()

w0 = 1.0
wc = 1.0
g = 2.0 / np.sqrt(N)
kappa = 1.0
nphot = 16

gE = 0.1
gD = 0.01
gP = 0.1
gCP = 0.1
gCE = 0.1

a = destroy(nphot)
h_tls = w0 * jz

h_phot = wc * a.dag() * a
liouv_phot = liouvillian(
    h_phot,
    [np.sqrt(kappa) * a],
)

id_tls = to_super(qeye(nds))
id_phot = to_super(qeye(nphot))

h_int = g * tensor(a + a.dag(), jx)
liouv_int = -1j * spre(h_int) + 1j * spost(h_int)


def build_tls_liouvillian(case_no):
    system = Dicke(N=N)
    system.hamiltonian = h_tls

    system.emission = 0.0
    system.dephasing = gD
    system.pumping = 0.0
    system.collective_pumping = 0.0
    system.collective_emission = 0.0
    system.collective_dephasing = 0.0

    if case_no == 1:
        system.pumping = gP
    elif case_no == 2:
        system.emission = gE
    elif case_no == 3:
        system.emission = gE
        system.collective_pumping = gCP
    elif case_no == 4:
        system.emission = gE
        system.collective_emission = gCE
    else:
        raise ValueError(f"Unknown case: {case_no}")

    return system.liouvillian()


def build_total_liouvillian(case_no):
    liouv_tls = build_tls_liouvillian(case_no)
    return (
        super_tensor(liouv_phot, id_tls)
        + super_tensor(id_phot, liouv_tls)
        + liouv_int
    )


rho_start = tensor(
    fock_dm(nphot, 0),
    ground(N),
)
vec_template = operator_to_vector(rho_start)
v0 = np.asarray(vec_template.full()).ravel()
v0 = v0 / np.linalg.norm(v0)


def vector_to_density(raw_vector):
    """
    Convert an ARPACK right eigenvector in QuTiP's column-stacked
    vectorization convention back to an operator.
    """
    opket = Qobj(
        np.asarray(raw_vector, dtype=np.complex128).reshape((-1, 1)),
        dims=vec_template.dims,
        shape=vec_template.shape,
    )
    rho = vector_to_operator(opket)

    rho = 0.5 * (rho + rho.dag())

    tr = rho.tr()
    if abs(tr) < 1e-14:
        raise RuntimeError("ARPACK zero-mode has numerically vanishing trace")

    rho = rho / tr

    rho = 0.5 * (rho + rho.dag())
    rho = rho / rho.tr()

    return rho


def spectral_steady_state(L, case_no):
    """
    Find the stationary right eigenmode of L with Arnoldi iteration.

    No sigma is supplied to eigs().  This is intentional: shift-invert mode
    would introduce a sparse factorization and make the algorithm much closer
    to the direct-LU baseline.  which='LR' asks ARPACK for eigenvalues with
    largest real part; for a dissipative Lindblad generator the stationary
    eigenvalue is zero while decaying modes have negative real parts.
    """
    A = L.data.tocsr()

    print(
        f"Case {case_no}: Arnoldi spectral solve "
        f"(dimension={A.shape[0]}, nnz={A.nnz})",
        flush=True,
    )

    try:
        evals, evecs = eigs(
            A,
            k=4,
            which="LR",
            tol=1e-11,
            maxiter=100000,
            ncv=40,
            v0=v0,
        )
    except ArpackNoConvergence as exc:
        if exc.eigenvalues is None or len(exc.eigenvalues) == 0:
            raise
        evals = exc.eigenvalues
        evecs = exc.eigenvectors
        print(
            f"Case {case_no}: ARPACK reached maxiter but returned "
            f"{len(evals)} converged Ritz pair(s)",
            flush=True,
        )

    zero_idx = int(np.argmin(np.abs(evals)))
    lam = evals[zero_idx]
    raw = evecs[:, zero_idx]

    rho = vector_to_density(raw)

    vec = operator_to_vector(rho)
    residual_vec = A.dot(np.asarray(vec.full()).ravel())
    residual = float(
        np.linalg.norm(residual_vec)
        / max(np.linalg.norm(np.asarray(vec.full()).ravel()), 1e-300)
    )

    print(
        f"Case {case_no}: selected lambda="
        f"{lam.real:.6e}{lam.imag:+.6e}j, "
        f"relative residual={residual:.3e}",
        flush=True,
    )

    if abs(lam) > 1e-7 or residual > 1e-7:
        raise RuntimeError(
            f"Case {case_no}: spectral zero-mode did not converge accurately "
            f"(lambda={lam}, residual={residual})"
        )

    return rho


xvec = np.linspace(-6.0, 6.0, 1000)

for case_no in (1, 2, 3, 4):
    L = build_total_liouvillian(case_no)

    rho_ss = spectral_steady_state(L, case_no)
    rho_cavity = rho_ss.ptrace(0)

    W = wigner(rho_cavity, xvec, xvec)

    out_path = output_dir / f"{case_no}.csv"
    np.savetxt(out_path, W, delimiter=",")
    print(f"Saved {out_path}", flush=True)

    del W, rho_cavity, rho_ss, L


print("All four cases completed", flush=True)

PYTHON_SCRIPT
