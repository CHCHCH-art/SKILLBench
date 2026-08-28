#!/bin/bash
set -euo pipefail

cd /app

cat > portfolio_optimized.c <<'EOF'

#include <Python.h>
#include <math.h>
#include <stdlib.h>


static inline int object_to_double(PyObject *obj, double *out)
{
    if (PyFloat_CheckExact(obj)) {
        *out = PyFloat_AS_DOUBLE(obj);
        return 0;
    }

    *out = PyFloat_AsDouble(obj);
    return PyErr_Occurred() ? -1 : 0;
}


static int copy_vector(
    PyObject *obj,
    double **out_data,
    Py_ssize_t *out_n
)
{
    PyObject *seq = PySequence_Fast(
        obj,
        "expected a one-dimensional numeric sequence"
    );

    if (seq == NULL)
        return -1;

    Py_ssize_t n = PySequence_Fast_GET_SIZE(seq);

    double *data = (double *)malloc((size_t)n * sizeof(double));
    if (data == NULL) {
        Py_DECREF(seq);
        PyErr_NoMemory();
        return -1;
    }

    PyObject **items = PySequence_Fast_ITEMS(seq);

    for (Py_ssize_t i = 0; i < n; ++i) {
        if (object_to_double(items[i], &data[i]) < 0) {
            free(data);
            Py_DECREF(seq);
            return -1;
        }
    }

    Py_DECREF(seq);

    *out_data = data;
    *out_n = n;
    return 0;
}


static PyObject *
portfolio_risk_c(PyObject *self, PyObject *args)
{
    (void)self;

    PyObject *weights_obj;
    PyObject *cov_obj;

    if (!PyArg_ParseTuple(
            args,
            "OO",
            &weights_obj,
            &cov_obj))
        return NULL;

    double *weights = NULL;
    Py_ssize_t n = 0;

    if (copy_vector(weights_obj, &weights, &n) < 0)
        return NULL;

    PyObject *cov = PySequence_Fast(
        cov_obj,
        "covariance matrix must be a sequence"
    );

    if (cov == NULL) {
        free(weights);
        return NULL;
    }

    if (PySequence_Fast_GET_SIZE(cov) != n) {
        Py_DECREF(cov);
        free(weights);

        PyErr_SetString(
            PyExc_ValueError,
            "covariance matrix dimensions do not match weights"
        );
        return NULL;
    }

    double *temp = (double *)calloc(
        (size_t)n,
        sizeof(double)
    );

    if (temp == NULL) {
        Py_DECREF(cov);
        free(weights);
        return PyErr_NoMemory();
    }

    PyObject **rows = PySequence_Fast_ITEMS(cov);

    for (Py_ssize_t i = 0; i < n; ++i) {

        PyObject *row = PySequence_Fast(
            rows[i],
            "each covariance row must be a sequence"
        );

        if (row == NULL) {
            free(temp);
            Py_DECREF(cov);
            free(weights);
            return NULL;
        }

        if (PySequence_Fast_GET_SIZE(row) != n) {
            Py_DECREF(row);
            free(temp);
            Py_DECREF(cov);
            free(weights);

            PyErr_SetString(
                PyExc_ValueError,
                "covariance matrix must be square"
            );
            return NULL;
        }

        PyObject **items = PySequence_Fast_ITEMS(row);

        const double wi = weights[i];

        double sii;

        if (object_to_double(items[i], &sii) < 0) {
            Py_DECREF(row);
            free(temp);
            Py_DECREF(cov);
            free(weights);
            return NULL;
        }

        temp[i] += sii * wi;

        for (Py_ssize_t j = i + 1; j < n; ++j) {

            double sij;

            if (object_to_double(items[j], &sij) < 0) {
                Py_DECREF(row);
                free(temp);
                Py_DECREF(cov);
                free(weights);
                return NULL;
            }

            temp[i] += sij * weights[j];
            temp[j] += sij * wi;
        }

        Py_DECREF(row);
    }

    double risk_squared = 0.0;

    for (Py_ssize_t i = 0; i < n; ++i)
        risk_squared += weights[i] * temp[i];

    free(temp);
    Py_DECREF(cov);
    free(weights);

    return PyFloat_FromDouble(sqrt(risk_squared));
}


static PyObject *
portfolio_return_c(PyObject *self, PyObject *args)
{
    (void)self;

    PyObject *weights_obj;
    PyObject *returns_obj;

    if (!PyArg_ParseTuple(
            args,
            "OO",
            &weights_obj,
            &returns_obj))
        return NULL;

    PyObject *weights = PySequence_Fast(
        weights_obj,
        "weights must be a sequence"
    );

    if (weights == NULL)
        return NULL;

    PyObject *returns = PySequence_Fast(
        returns_obj,
        "expected returns must be a sequence"
    );

    if (returns == NULL) {
        Py_DECREF(weights);
        return NULL;
    }

    Py_ssize_t n = PySequence_Fast_GET_SIZE(weights);

    if (PySequence_Fast_GET_SIZE(returns) != n) {
        Py_DECREF(returns);
        Py_DECREF(weights);

        PyErr_SetString(
            PyExc_ValueError,
            "weights and expected returns must have equal length"
        );
        return NULL;
    }

    PyObject **w_items = PySequence_Fast_ITEMS(weights);
    PyObject **r_items = PySequence_Fast_ITEMS(returns);

    double result = 0.0;

    for (Py_ssize_t i = 0; i < n; ++i) {

        double w;
        double r;

        if (object_to_double(w_items[i], &w) < 0 ||
            object_to_double(r_items[i], &r) < 0) {

            Py_DECREF(returns);
            Py_DECREF(weights);
            return NULL;
        }

        result += w * r;
    }

    Py_DECREF(returns);
    Py_DECREF(weights);

    return PyFloat_FromDouble(result);
}


static PyMethodDef module_methods[] = {
    {
        "portfolio_risk_c",
        portfolio_risk_c,
        METH_VARARGS,
        "Calculate portfolio risk using direct symmetric traversal"
    },
    {
        "portfolio_return_c",
        portfolio_return_c,
        METH_VARARGS,
        "Calculate portfolio expected return"
    },
    {NULL, NULL, 0, NULL}
};


static struct PyModuleDef moduledef = {
    PyModuleDef_HEAD_INIT,
    "portfolio_optimized_c",
    "Low-memory optimized portfolio calculations",
    -1,
    module_methods
};


PyMODINIT_FUNC
PyInit_portfolio_optimized_c(void)
{
    return PyModule_Create(&moduledef);
}
EOF


cat > portfolio_optimized.py <<'EOF'
#!/usr/bin/env python3

"""
Python wrapper for the low-memory C implementation.

Unlike the dense reference implementation, the covariance matrix is deliberately
left in its original Python representation. The C extension consumes it
directly, avoiding an O(n^2) NumPy conversion/copy.
"""

try:
    from . import portfolio_optimized_c
except ImportError:
    import portfolio_optimized_c


def portfolio_risk_c(weights, cov_matrix):
    return portfolio_optimized_c.portfolio_risk_c(
        weights,
        cov_matrix,
    )


def portfolio_return_c(weights, expected_returns):
    return portfolio_optimized_c.portfolio_return_c(
        weights,
        expected_returns,
    )


__all__ = [
    "portfolio_risk_c",
    "portfolio_return_c",
]
EOF


python3 setup.py build_ext --inplace

python3 benchmark.py