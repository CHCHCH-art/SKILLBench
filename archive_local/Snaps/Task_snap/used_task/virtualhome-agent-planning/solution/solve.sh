#!/bin/bash

set -euo pipefail

APP_ROOT="/app"
WORK_ROOT="/root/pddl-alt-pipeline"

rm -rf "${WORK_ROOT}"
mkdir -p "${WORK_ROOT}"
python3 <<'PYTHON_SCRIPT'
from __future__ import annotations

import hashlib
import json
import os
import re
import subprocess
import sys
from pathlib import Path
from typing import Dict, Iterable, List, Optional, Sequence, Tuple

from unified_planning.engines import CompilationKind
from unified_planning.io import PDDLReader, PDDLWriter
from unified_planning.model import InstantaneousAction
from unified_planning.plans import ActionInstance, Plan, SequentialPlan
from unified_planning.shortcuts import Compiler, OneshotPlanner, PlanValidator

APP_ROOT = Path("/app")
ROOT_FALLBACK = Path("/root")
PROBLEM_JSON = APP_ROOT / "problem.json"
WORK_ROOT = Path("/root/pddl-alt-pipeline")


class PipelineError(RuntimeError):
    pass


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def safe_component(value: object) -> str:
    cleaned = re.sub(r"[^A-Za-z0-9_.-]+", "_", str(value)).strip("._")
    return cleaned or "task"


def resolve_input(raw_path: str) -> Path:
    path = Path(raw_path)
    if path.is_absolute():
        candidate = path.resolve()
        if candidate.is_file():
            return candidate
        raise FileNotFoundError(f"Input file does not exist: {candidate}")

    checked: List[Path] = []
    for base in (APP_ROOT, ROOT_FALLBACK):
        candidate = (base / path).resolve()
        checked.append(candidate)
        if candidate.is_file():
            return candidate
    raise FileNotFoundError(
        f"Input file {raw_path!r} not found. Checked: "
        + ", ".join(str(item) for item in checked)
    )


def resolve_output(raw_path: str) -> Path:
    path = Path(raw_path)
    if not path.is_absolute():
        path = APP_ROOT / path
    output = path.resolve()
    output.parent.mkdir(parents=True, exist_ok=True)
    return output


def validate_plan(problem, plan: Optional[Plan]) -> Tuple[bool, str]:
    if plan is None:
        return False, "planner returned no plan"
    try:
        with PlanValidator(problem_kind=problem.kind, plan_kind=plan.kind) as validator:
            result = validator.validate(problem, plan)
    except Exception as exc:  # Preserve diagnostics from unsupported validators.
        return False, f"validator exception: {type(exc).__name__}: {exc}"

    status_name = getattr(result.status, "name", str(result.status))
    if status_name == "VALID":
        return True, status_name
    reason = getattr(result, "reason", None)
    return False, f"{status_name}: {reason}" if reason else status_name


def run_pyperplan(problem, *, search: Optional[str], heuristic: Optional[str]) -> Plan:
    params: Dict[str, str] = {}
    if search is not None:
        params["search"] = search
    if heuristic is not None:
        params["heuristic"] = heuristic

    if params:
        planner_context = OneshotPlanner(name="pyperplan", params=params)
    else:
        planner_context = OneshotPlanner(name="pyperplan")

    with planner_context as planner:
        result = planner.solve(problem)

    plan = result.plan
    if plan is None:
        status = getattr(result, "status", "UNKNOWN")
        raise PipelineError(
            f"Pyperplan failed with search={search!r}, heuristic={heuristic!r}; "
            f"status={status}"
        )
    return plan


def run_external_pyperplan(
    *,
    domain_path: Path,
    problem_path: Path,
    task_work: Path,
    label: str,
    search: str,
    heuristic: str,
) -> Tuple[Path, Dict[str, object]]:
    """Run Pyperplan through its PDDL CLI boundary and retain its plan artifact."""
    fixed_output = Path(str(problem_path) + ".soln")
    fixed_output.unlink(missing_ok=True)

    command = [
        str(Path(sys.executable).resolve()),
        "-m",
        "pyperplan",
        "-l",
        "warning",
        "-s",
        search,
        "-H",
        heuristic,
        str(domain_path),
        str(problem_path),
    ]
    completed = subprocess.run(
        command,
        cwd=str(task_work),
        stdin=subprocess.DEVNULL,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        check=False,
    )
    metadata: Dict[str, object] = {
        "command": command,
        "returncode": completed.returncode,
        "stdout_tail": completed.stdout[-2000:],
        "stderr_tail": completed.stderr[-2000:],
    }
    if completed.returncode != 0:
        raise PipelineError(
            f"External Pyperplan exited with {completed.returncode}: "
            f"{completed.stderr[-500:]}"
        )
    if not fixed_output.is_file():
        raise PipelineError(
            "External Pyperplan returned without producing a .soln file"
        )

    retained_plan = task_work / f"{safe_component(label)}.plan"
    retained_plan.unlink(missing_ok=True)
    os.replace(fixed_output, retained_plan)
    check_plan_text(retained_plan)
    return retained_plan, metadata


def lift_serialized_ground_plan(
    serialized_plan: Plan,
    serialization_writer: PDDLWriter,
    grounding_result,
) -> SequentialPlan:
    if not isinstance(serialized_plan, SequentialPlan):
        raise PipelineError(
            f"Expected SequentialPlan from pyperplan, got {type(serialized_plan).__name__}"
        )

    lifted_actions: List[ActionInstance] = []
    for serialized_instance in serialized_plan.actions:
        if serialized_instance.actual_parameters:
            raise PipelineError(
                "The round-tripped grounded problem unexpectedly contains "
                "parameterized action instances"
            )

        grounded_action = serialization_writer.get_item_named(
            serialized_instance.action.name
        )
        if grounded_action is None:
            raise PipelineError(
                f"Could not map serialized action {serialized_instance.action.name!r} "
                "back to the grounded UP model"
            )
        if not isinstance(grounded_action, InstantaneousAction):
            raise PipelineError(
                f"Grounded action {grounded_action.name!r} is not instantaneous"
            )

        original_instance = grounding_result.map_back_action_instance(
            ActionInstance(grounded_action)
        )
        if original_instance is None:
            raise PipelineError(
                f"Could not lift grounded action {grounded_action.name!r} "
                "to the original problem"
            )
        lifted_actions.append(original_instance)

    return SequentialPlan(lifted_actions)


def check_plan_text(path: Path) -> None:
    with path.open("r", encoding="utf-8") as stream:
        lines = [line.strip() for line in stream if line.strip()]

    if not lines:
        raise PipelineError(f"Generated plan is empty: {path}")

    malformed = [
        (index, line)
        for index, line in enumerate(lines, start=1)
        if line.count("(") != 1
        or line.count(")") != 1
        or not line.startswith("(")
        or not line.endswith(")")
    ]
    if malformed:
        index, line = malformed[0]
        raise PipelineError(f"Malformed plan line {index}: {line!r}")


def write_json(path: Path, payload: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as stream:
        json.dump(payload, stream, indent=2, sort_keys=True)
        stream.write("\n")


def solve_task(task: Dict[str, str]) -> None:
    task_id = str(task["id"])
    task_work = WORK_ROOT / safe_component(task_id)
    task_work.mkdir(parents=True, exist_ok=True)

    domain_path = resolve_input(task["domain"])
    problem_path = resolve_input(task["problem"])
    output_path = resolve_output(task["plan_output"])

    print(f"[{task_id}] domain:  {domain_path}")
    print(f"[{task_id}] problem: {problem_path}")
    print(f"[{task_id}] output:  {output_path}")

    reader = PDDLReader()
    original_problem = reader.parse_problem(str(domain_path), str(problem_path))

    baseline_plan = run_pyperplan(
        original_problem,
        search=None,
        heuristic=None,
    )
    baseline_valid, baseline_status = validate_plan(original_problem, baseline_plan)
    if not baseline_valid:
        raise PipelineError(f"Baseline plan is invalid: {baseline_status}")
    baseline_length = len(baseline_plan.actions)

    candidate_records: List[Dict[str, object]] = []
    alternative_candidates: List[Tuple[str, SequentialPlan]] = []
    model_sizes: Dict[str, int] = {
        "original_actions": len(original_problem.actions),
    }
    alternative_pipeline_status = "completed"

    try:
        with Compiler(
            name="up_grounder",
            compilation_kind=CompilationKind.GROUNDING,
        ) as compiler:
            grounding_result = compiler.compile(
                original_problem,
                CompilationKind.GROUNDING,
            )

        grounded_problem = grounding_result.problem
        if grounded_problem is None:
            raise PipelineError("UP grounder returned no compiled problem")
        model_sizes["grounded_actions"] = len(grounded_problem.actions)

        grounded_domain_path = task_work / "grounded-domain.pddl"
        grounded_problem_path = task_work / "grounded-problem.pddl"
        grounded_writer = PDDLWriter(grounded_problem)
        grounded_writer.write_domain(str(grounded_domain_path))
        grounded_writer.write_problem(str(grounded_problem_path))

        serialized_problem = PDDLReader().parse_problem(
            str(grounded_domain_path),
            str(grounded_problem_path),
        )
        model_sizes["roundtrip_actions"] = len(serialized_problem.actions)

        portfolio: Sequence[Tuple[str, str, str]] = (
            ("greedy-best-first+hmax", "gbf", "hmax"),
            ("weighted-astar+hff", "wastar", "hff"),
            ("astar+lmcut", "astar", "lmcut"),
        )

        for label, search, heuristic in portfolio:
            record: Dict[str, object] = {
                "label": label,
                "search": search,
                "heuristic": heuristic,
                "execution_boundary": "external pyperplan CLI process",
            }
            try:
                plan_path, process_metadata = run_external_pyperplan(
                    domain_path=grounded_domain_path,
                    problem_path=grounded_problem_path,
                    task_work=task_work,
                    label=label,
                    search=search,
                    heuristic=heuristic,
                )
                record.update(process_metadata)

                grounded_plan = PDDLReader().parse_plan(
                    serialized_problem,
                    str(plan_path),
                )
                grounded_valid, grounded_status = validate_plan(
                    serialized_problem, grounded_plan
                )
                record["grounded_validation"] = grounded_status
                record["grounded_actions"] = len(grounded_plan.actions)
                if not grounded_valid:
                    raise PipelineError(
                        f"Serialized grounded plan is invalid: {grounded_status}"
                    )

                lifted_plan = lift_serialized_ground_plan(
                    grounded_plan,
                    grounded_writer,
                    grounding_result,
                )
                lifted_valid, lifted_status = validate_plan(
                    original_problem, lifted_plan
                )
                record["lifted_validation"] = lifted_status
                record["lifted_actions"] = len(lifted_plan.actions)
                if not lifted_valid:
                    raise PipelineError(
                        f"Lifted plan is invalid in the original model: {lifted_status}"
                    )

                alternative_candidates.append((label, lifted_plan))
                record["usable"] = True
            except Exception as exc:
                record["usable"] = False
                record["error"] = f"{type(exc).__name__}: {exc}"
                print(
                    f"[{task_id}] portfolio member {label!r} rejected: {exc}",
                    file=sys.stderr,
                )
            candidate_records.append(record)
    except Exception as exc:
        alternative_pipeline_status = f"fallback: {type(exc).__name__}: {exc}"
        print(
            f"[{task_id}] alternative pipeline failed; using baseline guard: {exc}",
            file=sys.stderr,
        )

    non_improving = [
        (label, plan)
        for label, plan in alternative_candidates
        if len(plan.actions) >= baseline_length
    ]
    if non_improving:
        selected_label, selected_plan = max(
            non_improving,
            key=lambda item: (len(item[1].actions), item[0]),
        )
    else:
        selected_label, selected_plan = "baseline-quality-guard", baseline_plan

    selected_valid, selected_status = validate_plan(original_problem, selected_plan)
    if not selected_valid:
        raise PipelineError(f"Selected plan is invalid: {selected_status}")

    temporary_output = output_path.with_name(output_path.name + ".tmp")
    output_writer = PDDLWriter(original_problem)
    output_writer.write_plan(selected_plan, str(temporary_output))
    check_plan_text(temporary_output)

    disk_plan = PDDLReader().parse_plan(
        original_problem,
        str(temporary_output),
        output_writer.get_item_named,
    )
    disk_valid, disk_status = validate_plan(original_problem, disk_plan)
    if not disk_valid:
        raise PipelineError(f"On-disk plan failed validation: {disk_status}")

    os.replace(temporary_output, output_path)

    manifest = {
        "task_id": task_id,
        "inputs": {
            "domain": str(domain_path),
            "domain_sha256": sha256_file(domain_path),
            "problem": str(problem_path),
            "problem_sha256": sha256_file(problem_path),
        },
        "model_sizes": model_sizes,
        "alternative_pipeline_status": alternative_pipeline_status,
        "baseline": {
            "planner": "pyperplan",
            "parameters": "plugin defaults",
            "actions": baseline_length,
            "validation": baseline_status,
        },
        "portfolio": candidate_records,
        "selection": {
            "label": selected_label,
            "actions": len(selected_plan.actions),
            "validation": selected_status,
            "disk_validation": disk_status,
            "quality_guard": "selected action count is not below baseline",
        },
        "output": {
            "path": str(output_path),
            "sha256": sha256_file(output_path),
        },
    }
    write_json(task_work / "manifest.json", manifest)

    print(
        f"[{task_id}] selected={selected_label}; "
        f"baseline_actions={baseline_length}; "
        f"output_actions={len(selected_plan.actions)}"
    )


def main() -> int:
    if not PROBLEM_JSON.is_file():
        raise FileNotFoundError(f"Missing task list: {PROBLEM_JSON}")

    with PROBLEM_JSON.open("r", encoding="utf-8") as stream:
        tasks = json.load(stream)

    if not isinstance(tasks, list):
        raise PipelineError(f"Expected a list in {PROBLEM_JSON}")

    required = {"id", "domain", "problem", "plan_output"}
    for index, task in enumerate(tasks):
        if not isinstance(task, dict):
            raise PipelineError(f"Task entry {index} is not an object")
        missing = required.difference(task)
        if missing:
            raise PipelineError(
                f"Task entry {index} is missing fields: {sorted(missing)}"
            )
        solve_task(task)

    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"solve.sh failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        raise
PYTHON_SCRIPT
