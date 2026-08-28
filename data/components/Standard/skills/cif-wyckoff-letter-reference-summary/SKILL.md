---
name: cif-wyckoff-letter-reference-summary
description: "Summarize the explicit sites of a CIF by counting the Wyckoff letters returned per input site, grouping equal letters, and retaining the first explicit site as each letter group's representative coordinate; this is not full crystallographic orbit reconstruction."
---

## Dependency precheck

Run `scripts/ensure_dependencies.sh --check` before the procedure. If it reports missing or wrong dependencies, run `scripts/ensure_dependencies.sh --install`, then rerun `--check`.

## Parameter binding rule

Paths, filenames, labels, field names, limits, thresholds, ranges, output schemas, and other values explicitly supplied by the current Task must be read from its `Instruction.md` at execution time. Do not turn Task-provided content or input-file contents into constants of this SKILL. Constants identified below as **reference defaults** are fixed choices of this procedure when the Task does not supply them; use them when following this procedure.

## Scope

This is a reference summary over the Wyckoff-letter array returned for the explicit input sites. It is not a general crystallographic orbit reconstruction, multiplicity-from-space-group derivation, or symmetrized representative-site algorithm.

## Reference procedure

1. Load the current CIF with `pymatgen.core.Structure.from_file` and build `SpacegroupAnalyzer(structure)` using library defaults.
2. Call `get_symmetry_dataset()`. If it returns `None`, return empty multiplicity and coordinate mappings, matching the reference behavior.
3. Read `dataset.wyckoffs`, which gives one letter for each explicit structure site. Require its length to equal the number of structure sites.
4. Count letters with `Counter` and convert the counts to a dictionary sorted by letter. These counts are the reference output called multiplicities; do not reinterpret them as independently derived full-orbit multiplicities.
5. Group the original `Structure` sites by corresponding letter. Iterate sites in their input order and retain `sites[0].frac_coords` as the representative coordinate for each letter.
6. Pass those coordinates to the rational-formatting step; do not symmetrize, average, expand equivalent sites, or replace the first explicit site with a generated representative.

## Checks

Require a one-to-one alignment between explicit sites and `dataset.wyckoffs`; require the sum of letter counts to equal the number of explicit sites; and require each emitted representative to be exactly the first grouped site in original structure order. If the dataset is absent, emit the reference empty mappings; if lengths disagree or coordinates are nonfinite, abort rather than performing a different symmetry analysis.
