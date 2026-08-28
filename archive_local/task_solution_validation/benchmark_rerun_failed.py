from __future__ import annotations

import argparse
import csv
import json
import re
import shutil
import subprocess
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path

import benchmark_repeated_runs as benchmark


FINAL_STATUS_RE = re.compile(r"^Status:\s*(\S+)\s*$", re.MULTILINE)
PASSED_RE = re.compile(r"^Passed:\s*(\S+)\s*$", re.MULTILINE)
TASK_DIR_RE = re.compile(r"^Task directory:\s*(.+?)\s*$", re.MULTILINE)
RUN_FILE_RE = re.compile(r"^run-(\d+)\.log$")
FAIL_STATUSES = {"failed", "error", "timeout", "skipped"}
SOURCE_NAMES = ("baseline", "used")


@dataclass(frozen=True)
class RunState:
    source: str
    run_number: int
    status: str
    passed: bool | None
    log_path: Path | None


@dataclass(frozen=True)
class TaskState:
    task: str
    generation: str
    runs: tuple[RunState, ...]

    @property
    def has_failure(self) -> bool:
        return any(run.status in FAIL_STATUSES or run.passed is False for run in self.runs)

    @property
    def has_incomplete(self) -> bool:
        return any(run.status == "incomplete" for run in self.runs)

    @property
    def outcome(self) -> str:
        if self.has_failure:
            return "FAIL"
        if self.has_incomplete:
            return "INCOMPLETE"
        return "PASS"

    def pattern(self, source: str) -> str:
        symbols = {
            "passed": "P",
            "failed": "F",
            "error": "E",
            "timeout": "T",
            "skipped": "S",
            "incomplete": "I",
        }
        return "".join(
            symbols.get(run.status, "?")
            for run in self.runs
            if run.source == source
        )


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def parse_run(path: Path, source: str, run_number: int) -> RunState:
    if not path.is_file():
        return RunState(source, run_number, "incomplete", None, None)
    text = read_text(path)
    statuses = FINAL_STATUS_RE.findall(text)
    passed_values = PASSED_RE.findall(text)
    if not statuses:
        return RunState(source, run_number, "incomplete", None, path)
    status = statuses[-1].lower()
    passed = None
    if passed_values:
        passed = passed_values[-1].lower() == "true"
    return RunState(source, run_number, status, passed, path)


def infer_runs(batch_dir: Path) -> int:
    run_numbers: list[int] = []
    for path in (batch_dir / "logs").glob("*/*/run-*.log"):
        match = RUN_FILE_RE.match(path.name)
        if match:
            run_numbers.append(int(match.group(1)))
    if not run_numbers:
        raise ValueError(f"No run-N.log files found under {batch_dir / 'logs'}")
    return max(run_numbers)


def scan_logs(logs_dir: Path, generation: str, expected_runs: int) -> dict[str, TaskState]:
    states: dict[str, TaskState] = {}
    if not logs_dir.is_dir():
        return states
    for task_dir in sorted(path for path in logs_dir.iterdir() if path.is_dir()):
        runs = tuple(
            parse_run(
                task_dir / source / f"run-{run_number}.log",
                source,
                run_number,
            )
            for source in SOURCE_NAMES
            for run_number in range(1, expected_runs + 1)
        )
        states[task_dir.name] = TaskState(task_dir.name, generation, runs)
    return states


def incomplete_task(task: str, expected_runs: int) -> TaskState:
    return TaskState(
        task,
        "original",
        tuple(
            RunState(source, run_number, "incomplete", None, None)
            for source in SOURCE_NAMES
            for run_number in range(1, expected_runs + 1)
        ),
    )


def effective_states(
    batch_dir: Path,
    expected_runs: int,
    expected_tasks: list[str] | None = None,
) -> dict[str, TaskState]:
    effective: dict[str, TaskState] = {
        task: incomplete_task(task, expected_runs)
        for task in (expected_tasks or [])
    }
    # The declared batch is the sole source of truth. Older versions wrote
    # reruns/<timestamp>/logs and overlaid those generations here, which made
    # deleting or replacing batch logs ineffective. Legacy reruns remain on
    # disk as history but no longer affect selection or reported status.
    effective.update(scan_logs(batch_dir / "logs", "batch", expected_runs))
    return effective


def load_batch_manifest(batch_dir: Path) -> dict[str, object] | None:
    path = batch_dir / "batch_manifest.json"
    if not path.is_file():
        return None
    data = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(data, dict):
        raise ValueError(f"Invalid batch manifest: {path}")
    return data


def infer_source_root(batch_dir: Path, source: str) -> Path | None:
    roots: set[Path] = set()
    for path in (batch_dir / "logs").glob(f"*/{source}/run-*.log"):
        matches = TASK_DIR_RE.findall(read_text(path))
        if matches:
            roots.add(Path(matches[-1].strip()).resolve().parent)
    if len(roots) > 1:
        formatted = ", ".join(str(path) for path in sorted(roots, key=str))
        raise ValueError(f"Multiple {source} roots found in original logs: {formatted}")
    return next(iter(roots), None)


def print_states(states: dict[str, TaskState]) -> None:
    print("outcome\ttask\tbaseline\tused\tgeneration")
    for task in sorted(states):
        state = states[task]
        print(
            f"{state.outcome}\t{task}\t{state.pattern('baseline')}\t"
            f"{state.pattern('used')}\t{state.generation}"
        )
    counts = {
        outcome: sum(state.outcome == outcome for state in states.values())
        for outcome in ("PASS", "FAIL", "INCOMPLETE")
    }
    print(
        "Summary: "
        f"PASS={counts['PASS']} FAIL={counts['FAIL']} "
        f"INCOMPLETE={counts['INCOMPLETE']} TOTAL={len(states)}"
    )


def select_tasks(
    states: dict[str, TaskState],
    requested: list[str] | None,
    include_incomplete: bool,
) -> list[str]:
    if requested is not None:
        unknown = sorted(set(requested) - set(states))
        if unknown:
            raise ValueError("Unknown tasks: " + ", ".join(unknown))
        # An explicit task list is an overwrite request, even when the current
        # batch result is PASS or incomplete.
        return list(dict.fromkeys(requested))
    return sorted(
        task
        for task, state in states.items()
        if state.has_failure or (include_incomplete and state.has_incomplete)
    )


def read_csv(path: Path) -> tuple[list[str], list[dict[str, str]]]:
    if not path.is_file():
        return [], []
    with path.open("r", encoding="utf-8-sig", newline="") as csv_file:
        reader = csv.DictReader(csv_file)
        return list(reader.fieldnames or []), list(reader)


def write_csv(path: Path, fieldnames: list[str], rows: list[dict[str, str]]) -> None:
    with path.open("w", encoding="utf-8-sig", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def merge_task_csv(
    batch_path: Path,
    staged_path: Path,
    output_path: Path,
    selected: list[str],
) -> None:
    old_fields, old_rows = read_csv(batch_path)
    new_fields, new_rows = read_csv(staged_path)
    if not new_fields:
        raise ValueError(f"Rerun did not produce {staged_path.name}")
    if old_fields and old_fields != new_fields:
        raise ValueError(
            f"Cannot merge {staged_path.name}: batch and rerun columns differ"
        )
    fields = old_fields or new_fields
    selected_set = set(selected)
    combined = [row for row in old_rows if row.get("task") not in selected_set]
    combined.extend(row for row in new_rows if row.get("task") in selected_set)
    source_order = {"baseline": 0, "used": 1}

    def sort_key(row: dict[str, str]) -> tuple[object, ...]:
        run_text = row.get("task_run") or row.get("source_run") or "0"
        try:
            run_number = int(run_text)
        except ValueError:
            run_number = 0
        return (
            row.get("task", ""),
            source_order.get(row.get("source", ""), 2),
            run_number,
        )

    combined.sort(key=sort_key)
    write_csv(output_path, fields, combined)


def validate_staged_logs(
    staging_dir: Path,
    selected: list[str],
    expected_runs: int,
) -> None:
    missing = [
        staging_dir / "logs" / task / source / f"run-{run_number}.log"
        for task in selected
        for source in SOURCE_NAMES
        for run_number in range(1, expected_runs + 1)
        if not (
            staging_dir / "logs" / task / source / f"run-{run_number}.log"
        ).is_file()
    ]
    if missing:
        raise ValueError(
            "Rerun output is incomplete; batch was not changed. Missing: "
            + ", ".join(str(path) for path in missing[:5])
        )


def promote_in_place(
    batch_dir: Path,
    staging_dir: Path,
    selected: list[str],
    expected_runs: int,
) -> None:
    validate_staged_logs(staging_dir, selected, expected_runs)
    prepared_dir = staging_dir / "prepared"
    prepared_dir.mkdir()
    for name in ("runs.csv", "summary.csv"):
        merge_task_csv(
            batch_dir / name,
            staging_dir / name,
            prepared_dir / name,
            selected,
        )

    backup_dir = staging_dir / "backup"
    backup_logs = backup_dir / "logs"
    backup_logs.mkdir(parents=True)
    touched_tasks: list[str] = []
    touched_csv_names: list[str] = []
    try:
        for task in selected:
            destination = batch_dir / "logs" / task
            backup = backup_logs / task
            staged = staging_dir / "logs" / task
            touched_tasks.append(task)
            if destination.exists():
                destination.replace(backup)
            staged.replace(destination)

        for name in ("runs.csv", "summary.csv"):
            destination = batch_dir / name
            backup = backup_dir / name
            touched_csv_names.append(name)
            if destination.exists():
                destination.replace(backup)
            (prepared_dir / name).replace(destination)
    except BaseException:
        for name in reversed(touched_csv_names):
            destination = batch_dir / name
            if destination.exists():
                destination.unlink()
            backup = backup_dir / name
            if backup.exists():
                backup.replace(destination)
        for task in reversed(touched_tasks):
            destination = batch_dir / "logs" / task
            if destination.exists():
                shutil.rmtree(destination)
            backup = backup_logs / task
            if backup.exists():
                backup.replace(destination)
        raise


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "List task states in one benchmark batch and optionally rerun "
            "tasks in place as complete baseline+used units. Explicit "
            "--tasks always overwrites those batch tasks, including PASS or "
            "missing tasks. Without --tasks, only failed tasks are selected "
            "(plus incomplete tasks with --include-incomplete)."
        )
    )
    parser.add_argument(
        "batch_dir", type=Path, help="Existing benchmark batch directory."
    )
    parser.add_argument(
        "--rerun",
        action="store_true",
        help=(
            "Execute reruns and overwrite the selected task logs in the "
            "declared batch; default is list only."
        ),
    )
    parser.add_argument("--tasks", nargs="+", default=None, metavar="TASK")
    parser.add_argument(
        "--include-incomplete",
        action="store_true",
        help="Also select tasks with missing or unfinished run logs.",
    )
    parser.add_argument("--runs", type=int, default=None, help="Override inferred runs per source.")
    parser.add_argument("--tasks-root", type=Path, default=None)
    parser.add_argument("--used-root", type=Path, default=None)
    parser.add_argument(
        "--task-workers",
        "--task-worker",
        dest="task_workers",
        type=int,
        choices=(1, 2),
        default=2,
    )
    parser.add_argument(
        "--max-parallel-cpus",
        type=int,
        default=benchmark.DEFAULT_MAX_PARALLEL_CPUS,
    )
    parser.add_argument(
        "--max-parallel-memory-mib",
        type=int,
        default=benchmark.DEFAULT_MAX_PARALLEL_MEMORY_MIB,
    )
    return parser


def main() -> int:
    args = build_parser().parse_args()
    batch_dir = args.batch_dir.resolve()
    if not (batch_dir / "logs").is_dir():
        print(f"Error: batch logs directory does not exist: {batch_dir / 'logs'}")
        return 2
    try:
        manifest = load_batch_manifest(batch_dir)
        manifest_runs = manifest.get("runs_per_source") if manifest else None
        expected_runs = args.runs or manifest_runs or infer_runs(batch_dir)
        expected_runs = int(expected_runs)
        if expected_runs < 1:
            raise ValueError("--runs must be >= 1")
        manifest_tasks = manifest.get("tasks") if manifest else None
        expected_tasks = (
            [str(task) for task in manifest_tasks]
            if isinstance(manifest_tasks, list)
            else None
        )
        states = effective_states(batch_dir, expected_runs, expected_tasks)
        if args.tasks:
            for task in args.tasks:
                states.setdefault(task, incomplete_task(task, expected_runs))
        if not states:
            raise ValueError("No task log directories found")
        print(f"Batch: {batch_dir}")
        print(f"Runs per source: {expected_runs}")
        print_states(states)
        selected = select_tasks(states, args.tasks, args.include_incomplete)
    except Exception as exc:
        print(f"Error: {exc}")
        return 2

    print("Selected for rerun: " + (", ".join(selected) if selected else "none"))
    if not args.rerun or not selected:
        return 0

    if (
        args.tasks is None
        and any(state.has_incomplete for state in states.values())
        and not args.include_incomplete
    ):
        print(
            "Error: this batch contains incomplete logs. Ensure the original "
            "benchmark process has stopped, then rerun with --include-incomplete."
        )
        return 2

    try:
        manifest_tasks_root = manifest.get("tasks_root") if manifest else None
        manifest_used_root = manifest.get("used_root") if manifest else None
        tasks_root = (
            args.tasks_root
            or (Path(str(manifest_tasks_root)) if manifest_tasks_root else None)
            or infer_source_root(batch_dir, "baseline")
        )
        used_root = (
            args.used_root
            or (Path(str(manifest_used_root)) if manifest_used_root else None)
            or infer_source_root(batch_dir, "used")
        )
        if tasks_root is None or used_root is None:
            raise ValueError(
                "Could not infer baseline/used roots; pass --tasks-root and --used-root."
            )
        tasks_root = tasks_root.resolve()
        used_root = used_root.resolve()
    except Exception as exc:
        print(f"Error: {exc}")
        return 2

    staging_dir = Path(
        tempfile.mkdtemp(prefix=".rerun-staging-", dir=batch_dir)
    ).resolve()
    command = [
        sys.executable,
        str(Path(benchmark.__file__).resolve()),
        "--tasks-root",
        str(tasks_root),
        "--used-root",
        str(used_root),
        "--tasks",
        *selected,
        "--runs",
        str(expected_runs),
        "--task-workers",
        str(args.task_workers),
        "--max-parallel-cpus",
        str(args.max_parallel_cpus),
        "--max-parallel-memory-mib",
        str(args.max_parallel_memory_mib),
        "--output-dir",
        str(staging_dir),
    ]
    print("Rerun mode: in-place overwrite")
    print("Selected batch task logs will be replaced after the rerun completes.")
    try:
        completed = subprocess.run(command, check=False)
        if completed.returncode not in (0, 1):
            print(
                "Rerun process did not complete normally; batch was not changed."
            )
            return completed.returncode
        promote_in_place(batch_dir, staging_dir, selected, expected_runs)
        print(
            "Overwritten in batch: "
            + ", ".join(str(batch_dir / "logs" / task) for task in selected)
        )
    finally:
        shutil.rmtree(staging_dir, ignore_errors=True)
    print("Effective status after rerun:")
    print_states(effective_states(batch_dir, expected_runs, expected_tasks))
    return completed.returncode


if __name__ == "__main__":
    raise SystemExit(main())
