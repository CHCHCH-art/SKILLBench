from __future__ import annotations

import argparse
import concurrent.futures
import contextlib
import csv
import json
import time
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from statistics import fmean

import runner


SCRIPT_DIR = Path(__file__).resolve().parent
ARCHIVE_ROOT = SCRIPT_DIR.parent
SNAPSHOT_ROOT = ARCHIVE_ROOT / "Snaps" / "Task_snap"
DEFAULT_USED_ROOT = SNAPSHOT_ROOT / "used_task"
DEFAULT_TASKS_ROOT = SNAPSHOT_ROOT / "baseline_task"
DEFAULT_RUNS = 3
DEFAULT_TASK_WORKERS = 1
DEFAULT_MAX_PARALLEL_CPUS = 16
DEFAULT_MAX_PARALLEL_MEMORY_MIB = 24 * 1024


@dataclass
class TaskPair:
    task: str
    baseline_dir: Path
    used_dir: Path


@dataclass
class Attempt:
    task: str
    source: str
    task_run_number: int
    source_run_number: int
    result: runner.RunResult
    log_path: Path


@dataclass(frozen=True)
class TaskResources:
    cpus: int | None
    memory_mb: int | None


@dataclass(frozen=True)
class ScheduledTask:
    task_index: int
    pair: TaskPair
    resources: TaskResources
    heavy: bool


def discover_task_pairs(
    used_root: Path,
    tasks_root: Path,
    requested_tasks: list[str] | None = None,
) -> list[TaskPair]:
    used_root = used_root.resolve()
    tasks_root = tasks_root.resolve()

    if not used_root.is_dir():
        raise runner.RunnerError(f"Selected-tasks root does not exist: {used_root}")
    if not tasks_root.is_dir():
        raise runner.RunnerError(f"Tasks root does not exist: {tasks_root}")

    used_task_dirs = [path.parent.resolve() for path in used_root.rglob("task.toml")]
    if not used_task_dirs:
        raise runner.RunnerError(f"No task.toml files found under: {used_root}")

    available_names = [path.name for path in used_task_dirs]
    duplicate_names = sorted(
        name for name in set(available_names) if available_names.count(name) > 1
    )
    if duplicate_names:
        raise runner.RunnerError(
            "Duplicate task names found under selected-tasks root: "
            + ", ".join(duplicate_names)
        )

    if requested_tasks is None:
        selected_names = sorted(available_names)
    else:
        duplicate_requests = sorted(
            name
            for name in set(requested_tasks)
            if requested_tasks.count(name) > 1
        )
        if duplicate_requests:
            raise runner.RunnerError(
                "Duplicate task names passed to --tasks: "
                + ", ".join(duplicate_requests)
            )

        available_name_set = set(available_names)
        unknown = [
            name for name in requested_tasks if name not in available_name_set
        ]
        if unknown:
            raise runner.RunnerError(
                "Requested tasks are not present under the selected-tasks root: "
                + ", ".join(unknown)
            )
        selected_names = requested_tasks

    missing = sorted(name for name in selected_names if not (tasks_root / name).is_dir())
    if missing:
        raise runner.RunnerError(
            "Selected tasks are missing from the canonical tasks root: "
            + ", ".join(missing)
        )

    used_by_name = {path.name: path for path in used_task_dirs}
    task_pairs = [
        TaskPair(
            task=name,
            baseline_dir=(tasks_root / name).resolve(),
            used_dir=used_by_name[name],
        )
        for name in selected_names
    ]
    for pair in task_pairs:
        runner.validate_task_dir(pair.baseline_dir)
        runner.validate_task_dir(pair.used_dir)
    return task_pairs


def run_source_batch(
    task_dir: Path,
    source: str,
    runs: int,
    output_dir: Path,
) -> list[Attempt]:
    task_log_dir = output_dir / "logs" / task_dir.name / source
    task_log_dir.mkdir(parents=True, exist_ok=True)

    with contextlib.ExitStack() as stack:
        log_paths = [
            task_log_dir / f"run-{run_number}.log"
            for run_number in range(1, runs + 1)
        ]
        log_files = [
            stack.enter_context(
                path.open("w", encoding="utf-8", errors="replace")
            )
            for path in log_paths
        ]
        runner.set_thread_output(log_files[0])

        def before_run(run_index: int) -> None:
            runner.set_thread_output(log_files[run_index])
            task_run_number = (
                run_index + 1 if source == "baseline" else runs + run_index + 1
            )
            runner.safe_print(f"Task: {task_dir.name}")
            runner.safe_print(f"Source type: {source}")
            runner.safe_print(f"Task run: {task_run_number}")
            runner.safe_print(f"Source run: {run_index + 1}")
            runner.safe_print(f"Task directory: {task_dir}")

        def after_run(run_index: int, result: runner.RunResult) -> None:
            runner.print_final_result(result)

        try:
            results = runner.run_task_repeated(
                task_dir,
                repeat=runs,
                before_run=before_run,
                after_run=after_run,
            )
        finally:
            runner.clear_thread_output()

    return [
        Attempt(
            task=task_dir.name,
            source=source,
            task_run_number=(
                source_run_number
                if source == "baseline"
                else runs + source_run_number
            ),
            source_run_number=source_run_number,
            result=result,
            log_path=log_paths[source_run_number - 1],
        )
        for source_run_number, result in enumerate(results, start=1)
    ]


def add_known(values: list[int | None]) -> int | None:
    if any(value is None for value in values):
        return None
    return sum(value for value in values if value is not None)


def task_pair_resources(pair: TaskPair) -> TaskResources:
    runtimes = [
        runner.normalize_runtime_config(runner.load_toml(task_dir / "task.toml"))
        for task_dir in (pair.baseline_dir, pair.used_dir)
    ]
    return TaskResources(
        cpus=add_known([runtime.cpus for runtime in runtimes]),
        memory_mb=add_known([runtime.memory_mb for runtime in runtimes]),
    )


def build_execution_plan(
    task_pairs: list[TaskPair],
    max_parallel_cpus: int,
    max_parallel_memory_mib: int,
) -> tuple[list[ScheduledTask], list[ScheduledTask]]:
    light_tasks: list[ScheduledTask] = []
    heavy_tasks: list[ScheduledTask] = []
    for task_index, pair in enumerate(task_pairs, start=1):
        resources = task_pair_resources(pair)
        if resources.cpus is None or resources.memory_mb is None:
            raise runner.RunnerError(
                f"Task {pair.task!r} must declare cpus and memory_mb in both "
                "baseline and used task.toml files before parallel scheduling."
            )
        if resources.cpus < 1 or resources.memory_mb < 1:
            raise runner.RunnerError(
                f"Task {pair.task!r} has invalid combined resources: "
                f"cpus={resources.cpus}, memory={resources.memory_mb} MiB."
            )
        if (
            resources.cpus > max_parallel_cpus
            or resources.memory_mb > max_parallel_memory_mib
        ):
            raise runner.RunnerError(
                f"Task {pair.task!r} cannot fit the configured resource "
                f"budget: needs cpus={resources.cpus}, "
                f"memory={resources.memory_mb} MiB; budget is "
                f"cpus={max_parallel_cpus}, "
                f"memory={max_parallel_memory_mib} MiB."
            )

        # A light task uses at most half of each budget. Therefore any two
        # light tasks are guaranteed to fit without a dynamic resource ledger.
        heavy = (
            resources.cpus * 2 > max_parallel_cpus
            or resources.memory_mb * 2 > max_parallel_memory_mib
        )
        scheduled = ScheduledTask(task_index, pair, resources, heavy)
        (heavy_tasks if heavy else light_tasks).append(scheduled)
    return light_tasks, heavy_tasks


def run_task_pair(
    pair: TaskPair,
    task_index: int,
    task_count: int,
    runs: int,
    output_dir: Path,
) -> list[Attempt]:
    runner.safe_print()
    runner.safe_print(f"[Task {task_index}/{task_count}] {pair.task}")
    source_jobs = [
        ("baseline", pair.baseline_dir),
        ("used", pair.used_dir),
    ]
    for source, task_dir in source_jobs:
        runner.safe_print(f"  Source: {source} ({task_dir})")
        runner.safe_print(f"    one container queued for {runs} sequential runs")

    task_attempts: list[Attempt] = []
    with concurrent.futures.ThreadPoolExecutor(max_workers=2) as executor:
        future_to_job = {
            executor.submit(
                run_source_batch,
                task_dir,
                source,
                runs,
                output_dir,
            ): source
            for source, task_dir in source_jobs
        }
        for future in concurrent.futures.as_completed(future_to_job):
            source = future_to_job[future]
            source_attempts = future.result()
            task_attempts.extend(source_attempts)
            for attempt in source_attempts:
                result = attempt.result
                solve_time = (
                    f"{result.solve.elapsed_sec:.3f}s"
                    if result.solve is not None
                    else "n/a"
                )
                solve_memory = (
                    f"{memory_mib(result.solve_memory_peak_bytes):.1f} MiB"
                    if result.solve_memory_peak_bytes is not None
                    else "n/a"
                )
                runner.safe_print(
                    f"    completed: task={attempt.task} "
                    f"task_run={attempt.task_run_number} "
                    f"source={source} "
                    f"source_run={attempt.source_run_number} "
                    f"status={result.status} passed={result.passed} "
                    f"solve={solve_time} memory={solve_memory} "
                    f"log={attempt.log_path}"
                )
    return sorted(task_attempts, key=lambda attempt: attempt.task_run_number)


def run_light_tasks(
    tasks: list[ScheduledTask],
    task_workers: int,
    task_count: int,
    runs: int,
    output_dir: Path,
) -> dict[int, list[Attempt]]:
    if not tasks:
        return {}

    executor = concurrent.futures.ThreadPoolExecutor(
        max_workers=min(task_workers, len(tasks))
    )
    future_to_index: dict[concurrent.futures.Future[list[Attempt]], int] = {}
    attempts_by_index: dict[int, list[Attempt]] = {}
    try:
        for task in tasks:
            future = executor.submit(
                run_task_pair,
                task.pair,
                task.task_index,
                task_count,
                runs,
                output_dir,
            )
            future_to_index[future] = task.task_index
        for future in concurrent.futures.as_completed(future_to_index):
            task_index = future_to_index[future]
            attempts_by_index[task_index] = future.result()
    except BaseException:
        for future in future_to_index:
            future.cancel()
        executor.shutdown(wait=True, cancel_futures=True)
        raise
    else:
        executor.shutdown(wait=True)
    return attempts_by_index


def execute_plan(
    light_tasks: list[ScheduledTask],
    heavy_tasks: list[ScheduledTask],
    task_workers: int,
    task_count: int,
    runs: int,
    output_dir: Path,
) -> dict[int, list[Attempt]]:
    attempts_by_index = run_light_tasks(
        light_tasks,
        task_workers,
        task_count,
        runs,
        output_dir,
    )
    # Heavy tasks start only after the light-task executor has fully shut down.
    for task in heavy_tasks:
        attempts_by_index[task.task_index] = run_task_pair(
            task.pair,
            task.task_index,
            task_count,
            runs,
            output_dir,
        )
    return attempts_by_index


def reward_as_text(value: object) -> str:
    if value is None:
        return ""
    if isinstance(value, dict):
        return json.dumps(value, ensure_ascii=False, sort_keys=True)
    return str(value)


def seconds(value: runner.CommandResult | None) -> float | None:
    return value.elapsed_sec if value is not None else None


def exit_code(value: runner.CommandResult | None) -> int | None:
    return value.return_code if value is not None else None


def memory_mib(value: int | float | None) -> float | None:
    return value / (1024 * 1024) if value is not None else None


def write_runs_csv(output_dir: Path, attempts: list[Attempt]) -> Path:
    path = output_dir / "runs.csv"
    fieldnames = [
        "task",
        "source",
        "task_run",
        "source_run",
        "status",
        "passed",
        "reward",
        "solve_seconds",
        "solve_memory_peak_bytes",
        "solve_memory_peak_mib",
        "memory_metric",
        "memory_sampler_source",
        "memory_sample_interval_seconds",
        "solve_exit_code",
        "test_seconds",
        "test_exit_code",
        "error",
        "log_path",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for attempt in attempts:
            result = attempt.result
            writer.writerow(
                {
                    "task": attempt.task,
                    "source": attempt.source,
                    "task_run": attempt.task_run_number,
                    "source_run": attempt.source_run_number,
                    "status": result.status,
                    "passed": result.passed,
                    "reward": reward_as_text(result.reward),
                    "solve_seconds": seconds(result.solve),
                    "solve_memory_peak_bytes": result.solve_memory_peak_bytes,
                    "solve_memory_peak_mib": memory_mib(
                        result.solve_memory_peak_bytes
                    ),
                    "memory_metric": result.memory_metric or "",
                    "memory_sampler_source": result.memory_sampler_source or "",
                    "memory_sample_interval_seconds": (
                        result.memory_sample_interval_seconds
                        if result.memory_sample_interval_seconds is not None
                        else ""
                    ),
                    "solve_exit_code": exit_code(result.solve),
                    "test_seconds": seconds(result.test),
                    "test_exit_code": exit_code(result.test),
                    "error": result.error or "",
                    "log_path": str(attempt.log_path.resolve()),
                }
            )
    return path


def measured_values(
    attempts: list[Attempt],
) -> tuple[list[float], list[int]]:
    solve_times = [
        attempt.result.solve.elapsed_sec
        for attempt in attempts
        if attempt.result.solve is not None
    ]
    memory_peaks = [
        attempt.result.solve_memory_peak_bytes
        for attempt in attempts
        if attempt.result.solve_memory_peak_bytes is not None
    ]
    return solve_times, memory_peaks


def write_summary_csv(
    output_dir: Path,
    task_pairs: list[TaskPair],
    attempts: list[Attempt],
    requested_runs_per_source: int,
) -> Path:
    path = output_dir / "summary.csv"
    fieldnames = [
        "task",
        "source",
        "requested_runs_per_source",
        "completed_runs",
        "passed_runs",
        "solve_time_samples",
        "average_solve_seconds",
        "min_solve_seconds",
        "max_solve_seconds",
        "memory_samples",
        "average_solve_memory_bytes",
        "average_solve_memory_mib",
        "min_solve_memory_mib",
        "max_solve_memory_mib",
    ]
    with path.open("w", encoding="utf-8-sig", newline="") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        for pair in task_pairs:
            for source in ("baseline", "used"):
                source_attempts = [
                    attempt
                    for attempt in attempts
                    if attempt.task == pair.task and attempt.source == source
                ]
                solve_times, memory_peaks = measured_values(source_attempts)
                average_memory_bytes = (
                    fmean(memory_peaks) if memory_peaks else None
                )
                writer.writerow(
                    {
                        "task": pair.task,
                        "source": source,
                        "requested_runs_per_source": requested_runs_per_source,
                        "completed_runs": len(source_attempts),
                        "passed_runs": sum(
                            1
                            for attempt in source_attempts
                            if attempt.result.passed
                        ),
                        "solve_time_samples": len(solve_times),
                        "average_solve_seconds": (
                            fmean(solve_times) if solve_times else None
                        ),
                        "min_solve_seconds": (
                            min(solve_times) if solve_times else None
                        ),
                        "max_solve_seconds": (
                            max(solve_times) if solve_times else None
                        ),
                        "memory_samples": len(memory_peaks),
                        "average_solve_memory_bytes": average_memory_bytes,
                        "average_solve_memory_mib": (
                            memory_mib(average_memory_bytes)
                            if average_memory_bytes is not None
                            else None
                        ),
                        "min_solve_memory_mib": (
                            memory_mib(min(memory_peaks))
                            if memory_peaks
                            else None
                        ),
                        "max_solve_memory_mib": (
                            memory_mib(max(memory_peaks))
                            if memory_peaks
                            else None
                        ),
                    }
                )
    return path


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "For each selected task, create one Standard Route container and "
            "one High Cost Route container in parallel. Each container performs "
            "three sequential solve/test runs so its installed dependencies "
            "and caches can be reused. Multiple tasks can optionally run in "
            "parallel. Cached gold images are reused and never removed."
        )
    )
    parser.add_argument(
        "--used-root",
        type=Path,
        default=DEFAULT_USED_ROOT,
        help=(
            "Root containing used task bundles and selecting task names. "
            f"Default: {DEFAULT_USED_ROOT}"
        ),
    )
    parser.add_argument(
        "--tasks-root",
        type=Path,
        default=DEFAULT_TASKS_ROOT,
        help=f"Canonical task bundles root. Default: {DEFAULT_TASKS_ROOT}",
    )
    parser.add_argument(
        "--tasks",
        nargs="+",
        metavar="TASK",
        default=None,
        help=(
            "Run only the named tasks, in the given order. "
            "Example: --tasks A B C. Default: run all selected tasks."
        ),
    )
    parser.add_argument(
        "--runs",
        type=int,
        default=DEFAULT_RUNS,
        help=f"Consecutive runs per source for each task. Default: {DEFAULT_RUNS}",
    )
    parser.add_argument(
        "--task-workers",
        type=int,
        choices=(1, 2),
        default=DEFAULT_TASK_WORKERS,
        help=(
            "Maximum light tasks to run concurrently (1 or 2). Heavy tasks "
            "always run alone after all light tasks. Each task starts two "
            "containers (baseline and used). Default: "
            f"{DEFAULT_TASK_WORKERS}."
        ),
    )
    parser.add_argument(
        "--max-parallel-cpus",
        type=int,
        default=DEFAULT_MAX_PARALLEL_CPUS,
        help=(
            "CPU budget shared by concurrent tasks. A task using more than "
            "half runs alone. Default: "
            f"{DEFAULT_MAX_PARALLEL_CPUS}."
        ),
    )
    parser.add_argument(
        "--max-parallel-memory-mib",
        type=int,
        default=DEFAULT_MAX_PARALLEL_MEMORY_MIB,
        help=(
            "Memory budget in MiB shared by concurrent tasks. A task using "
            "more than half runs alone. Default: "
            f"{DEFAULT_MAX_PARALLEL_MEMORY_MIB}."
        ),
    )
    parser.add_argument(
        "--output-dir",
        type=Path,
        default=None,
        help=(
            "Output directory for logs and CSV files. "
            "Default: <script-dir>/benchmark-run-logs/<timestamp>"
        ),
    )
    return parser


def main() -> int:
    runner.configure_stdio()
    args = build_parser().parse_args()
    if args.runs < 1:
        runner.safe_print("--runs must be >= 1")
        return 2
    if args.max_parallel_cpus < 1:
        runner.safe_print("--max-parallel-cpus must be >= 1")
        return 2
    if args.max_parallel_memory_mib < 1:
        runner.safe_print("--max-parallel-memory-mib must be >= 1")
        return 2
    try:
        task_pairs = discover_task_pairs(
            args.used_root,
            args.tasks_root,
            requested_tasks=args.tasks,
        )
        light_tasks, heavy_tasks = build_execution_plan(
            task_pairs,
            args.max_parallel_cpus,
            args.max_parallel_memory_mib,
        )
    except Exception as exc:
        runner.safe_print(f"Error: {exc}")
        return 2

    timestamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    output_dir = (
        args.output_dir or (SCRIPT_DIR / "benchmark-run-logs" / timestamp)
    ).resolve()
    output_dir.mkdir(parents=True, exist_ok=True)

    batch_manifest_path = output_dir / "batch_manifest.json"
    batch_manifest = {
        "schema_version": 1,
        "status": "running",
        "started_at": datetime.now().isoformat(timespec="seconds"),
        "tasks": [pair.task for pair in task_pairs],
        "runs_per_source": args.runs,
        "tasks_root": str(args.tasks_root.resolve()),
        "used_root": str(args.used_root.resolve()),
        "task_workers": args.task_workers,
        "max_parallel_cpus": args.max_parallel_cpus,
        "max_parallel_memory_mib": args.max_parallel_memory_mib,
    }
    batch_manifest_path.write_text(
        json.dumps(batch_manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )

    total_attempts = len(task_pairs) * args.runs * 2
    effective_task_workers = min(args.task_workers, len(light_tasks))
    runner.safe_print(f"Tasks: {len(task_pairs)}")
    runner.safe_print(f"Runs per source: {args.runs}")
    runner.safe_print(f"Runs per task: {args.runs * 2}")
    runner.safe_print(f"Total runs: {total_attempts}")
    runner.safe_print(f"Light tasks: {len(light_tasks)}")
    runner.safe_print(f"Heavy tasks (exclusive, last): {len(heavy_tasks)}")
    runner.safe_print(f"Parallel light tasks: {effective_task_workers}")
    runner.safe_print("Parallel containers within each task: 2")
    runner.safe_print(
        f"Resource budget: cpus={args.max_parallel_cpus}, "
        f"memory={args.max_parallel_memory_mib} MiB"
    )
    runner.safe_print(
        "Execution: light tasks first with at most two concurrent tasks; "
        "heavy tasks then run one at a time; baseline and used remain one "
        "indivisible task unit"
    )
    if heavy_tasks:
        runner.safe_print(
            "Heavy task order: "
            + ", ".join(
                f"{task.pair.task} "
                f"({task.resources.cpus} CPU/{task.resources.memory_mb} MiB)"
                for task in heavy_tasks
            )
        )
    runner.safe_print(f"Output: {output_dir}")

    attempts: list[Attempt] = []
    started = time.monotonic()
    attempts_by_index = execute_plan(
        light_tasks,
        heavy_tasks,
        effective_task_workers,
        len(task_pairs),
        args.runs,
        output_dir,
    )

    for task_index in range(1, len(task_pairs) + 1):
        attempts.extend(attempts_by_index[task_index])

    runs_csv = write_runs_csv(output_dir, attempts)
    summary_csv = write_summary_csv(
        output_dir, task_pairs, attempts, args.runs
    )
    elapsed = time.monotonic() - started
    passed = sum(1 for attempt in attempts if attempt.result.passed)

    runner.safe_print()
    runner.safe_print("========== Benchmark Summary ==========")
    runner.safe_print(f"Completed runs: {len(attempts)}/{total_attempts}")
    runner.safe_print(f"Passed runs: {passed}/{len(attempts)}")
    runner.safe_print(f"Wall time: {elapsed:.1f}s")
    runner.safe_print(f"Runs CSV: {runs_csv}")
    runner.safe_print(f"Summary CSV: {summary_csv}")
    exit_code = 0 if passed == len(attempts) else 1
    batch_manifest["status"] = "completed"
    batch_manifest["completed_at"] = datetime.now().isoformat(timespec="seconds")
    batch_manifest["exit_code"] = exit_code
    batch_manifest["runs_csv"] = str(runs_csv)
    batch_manifest["summary_csv"] = str(summary_csv)
    batch_manifest_path.write_text(
        json.dumps(batch_manifest, ensure_ascii=False, indent=2),
        encoding="utf-8",
    )
    return exit_code


if __name__ == "__main__":
    raise SystemExit(main())
