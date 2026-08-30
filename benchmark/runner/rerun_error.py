from __future__ import annotations

import argparse
import csv
import os
import sys
from pathlib import Path

import run_baseline as baseline


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Rerun selected tasks in an existing benchmark batch, replace their "
            "old results, and rebuild that batch's summary.csv."
        )
    )
    parser.add_argument(
        "--batch",
        required=True,
        metavar="BATCH",
        help=(
            "Existing batch name under runtime/runs, or its absolute directory path."
        ),
    )
    parser.add_argument(
        "--tasks-root",
        type=Path,
        default=baseline.DEFAULT_TASKS_ROOT,
        metavar="PATH",
        help=f"Task input directory (default: {baseline.DEFAULT_TASKS_ROOT}).",
    )
    parser.add_argument(
        "--mapping-file",
        type=Path,
        metavar="PATH",
        help="JSONL/YAML Skill mapping used by this batch (required for Skill runs).",
    )
    parser.add_argument(
        "--repeat",
        type=int,
        metavar="N",
        help=(
            "Repeat number inside the batch. Required when the batch "
            "contains more than one Repeat_N directory."
        ),
    )
    parser.add_argument(
        "--task-workers",
        type=int,
        choices=(1, 2),
        default=baseline.DEFAULT_TASK_WORKERS,
        metavar="N",
        help=(
            "Maximum light tasks to rerun concurrently (1 or 2). Heavy tasks "
            f"run alone (default: {baseline.DEFAULT_TASK_WORKERS})."
        ),
    )
    parser.add_argument(
        "--max-parallel-cpus",
        type=int,
        default=baseline.DEFAULT_MAX_PARALLEL_CPUS,
        metavar="N",
        help=f"Shared CPU budget (default: {baseline.DEFAULT_MAX_PARALLEL_CPUS}).",
    )
    parser.add_argument(
        "--max-parallel-memory-mib",
        type=int,
        default=baseline.DEFAULT_MAX_PARALLEL_MEMORY_MIB,
        metavar="MIB",
        help=(
            "Shared memory budget in MiB (default: "
            f"{baseline.DEFAULT_MAX_PARALLEL_MEMORY_MIB})."
        ),
    )
    selection = parser.add_mutually_exclusive_group(required=True)
    selection.add_argument(
        "--task",
        action="append",
        metavar="TASK_ID",
        help=(
            "Task in the batch to rerun, regardless of its current result. "
            "May be repeated or comma-separated."
        ),
    )
    selection.add_argument(
        "--all-errors",
        action="store_true",
        help="Rerun every task currently marked ERROR in the batch summary.",
    )
    selection.add_argument(
        "--list",
        action="store_true",
        help="List ERROR tasks in the batch without running anything.",
    )
    args = parser.parse_args()
    if args.repeat is not None and args.repeat < 1:
        parser.error("--repeat must be at least 1")
    if args.max_parallel_cpus < 1:
        parser.error("--max-parallel-cpus must be at least 1")
    if args.max_parallel_memory_mib < 1:
        parser.error("--max-parallel-memory-mib must be at least 1")
    return args


def resolve_batch(value: str) -> Path:
    supplied = Path(value)
    batch_dir = supplied if supplied.is_absolute() else baseline.RUNS_ROOT / supplied
    batch_dir = batch_dir.resolve()
    baseline.assert_within(batch_dir, baseline.RUNS_ROOT)
    if not batch_dir.is_dir():
        raise FileNotFoundError(f"Batch directory not found: {batch_dir}")
    return batch_dir


def read_batch_rows(batch_dir: Path) -> list[dict[str, str]]:
    summary_path = batch_dir / "summary.csv"
    if not summary_path.is_file():
        raise FileNotFoundError(f"Batch summary not found: {summary_path}")
    with summary_path.open("r", encoding="utf-8-sig", newline="") as source:
        rows = list(csv.DictReader(source))
    if not rows:
        raise ValueError(f"Batch summary has no task rows: {summary_path}")
    if any(not row.get("task_id", "").strip() for row in rows):
        raise ValueError(f"Batch summary contains an empty task_id: {summary_path}")
    return rows


def available_repeats(batch_dir: Path) -> list[int]:
    numbers = [
        number
        for child in batch_dir.iterdir()
        if child.is_dir() and (number := baseline.repeat_number(child)) is not None
    ]
    return sorted(numbers)


def resolve_execution_dir(
    batch_dir: Path,
    requested_repeat: int | None,
) -> tuple[Path, int]:
    repeats = available_repeats(batch_dir)
    if not repeats:
        raise ValueError(f"Batch has no Repeat_N directories: {batch_dir}")

    if requested_repeat is None:
        if len(repeats) != 1:
            raise ValueError(
                "Batch contains multiple repeats; select one with --repeat. "
                f"Available: {', '.join(map(str, repeats))}"
            )
        requested_repeat = repeats[0]
    if requested_repeat not in repeats:
        raise ValueError(
            f"Repeat_{requested_repeat} not found. Available: "
            + ", ".join(map(str, repeats))
        )
    return baseline.repeat_dir(batch_dir, requested_repeat), requested_repeat


def batch_condition(rows: list[dict[str, str]]) -> str:
    conditions = {
        row.get("condition", "").strip()
        for row in rows
        if row.get("condition", "").strip()
    }
    if len(conditions) != 1:
        raise ValueError(
            "Expected exactly one condition in batch summary, found: "
            + (", ".join(sorted(conditions)) or "none")
        )
    condition = next(iter(conditions))
    if condition not in baseline.CONDITION_DIR_NAMES:
        raise ValueError(f"Unsupported condition in batch summary: {condition}")
    return condition


def error_tasks(rows: list[dict[str, str]]) -> list[str]:
    return [
        row["task_id"].strip()
        for row in rows
        if row.get("result", "").strip().upper() == "ERROR"
    ]


def requested_tasks(values: list[str] | None) -> list[str]:
    selected: list[str] = []
    seen: set[str] = set()
    for value in values or []:
        for item in value.split(","):
            task_id = item.strip()
            if task_id and task_id not in seen:
                selected.append(task_id)
                seen.add(task_id)
    return selected


def validate_selection(
    selected: list[str],
    rows: list[dict[str, str]],
) -> None:
    batch_tasks = {row["task_id"].strip() for row in rows}
    unknown = [task_id for task_id in selected if task_id not in batch_tasks]
    if unknown:
        raise ValueError(f"Task(s) not found in batch: {', '.join(unknown)}")
    if not selected:
        raise ValueError("No tasks selected")


def delete_old_result(batch_dir: Path, task_id: str) -> None:
    task_dir = batch_dir / task_id
    baseline.assert_within(task_dir, batch_dir)
    if not task_dir.is_dir():
        raise FileNotFoundError(f"Existing task result directory not found: {task_dir}")
    baseline.clean_path(task_dir, batch_dir)


def main() -> int:
    baseline.configure_standard_streams()
    args = parse_args()
    try:
        batch_dir = resolve_batch(args.batch)
        execution_dir, repeat = resolve_execution_dir(batch_dir, args.repeat)
        rows = read_batch_rows(execution_dir)
        condition = batch_condition(rows)
        errors = error_tasks(rows)
    except Exception as exc:
        print(f"[rerun-error][input-error] {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2

    if args.list:
        repeat_label = f" Repeat_{repeat}" if repeat is not None else ""
        print(
            f"[rerun-error] batch={batch_dir.name}{repeat_label} "
            f"condition={condition}"
        )
        if errors:
            for task_id in errors:
                print(task_id)
        else:
            print("No ERROR tasks found.")
        return 0

    selected = errors if args.all_errors else requested_tasks(args.task)
    try:
        tasks_root = args.tasks_root.expanduser().resolve()
        validate_selection(selected, rows)
        if condition == "no_skill":
            mapping_file = None
            skill_paths_by_task = {task_id: [] for task_id in selected}
        else:
            if args.mapping_file is None:
                raise ValueError("--mapping-file is required when rerunning a Skill batch")
            mapping_file = args.mapping_file.expanduser().resolve()
            skill_paths_by_task = baseline.resolve_skill_mapping(mapping_file, selected)
        harbor, docker, api = baseline.preflight(selected, tasks_root)
        light_tasks, heavy_tasks = baseline.build_execution_plan(
            selected,
            tasks_root,
            args.max_parallel_cpus,
            args.max_parallel_memory_mib,
        )
    except Exception as exc:
        print(f"[rerun-error][preflight-error] {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2

    if condition == "no_skill":
        os.environ["BENCHMARK_CLEAN_IMAGE_SKILLS"] = "1"

    all_tasks = [row["task_id"].strip() for row in rows]
    failed: list[str] = []
    setup_failed: list[str] = []
    interrupted = False
    result_code = 1
    try:
        print(
            f"[rerun-error] batch={batch_dir.name} condition={condition} "
            f"repeat={repeat} tasks={len(selected)}"
        )
        effective_workers = args.task_workers
        print(
            f"[rerun-error] scheduler=resource-aware "
            f"task_workers={effective_workers} light_tasks={len(light_tasks)} "
            f"heavy_tasks={len(heavy_tasks)}"
        )

        def prepare_rerun(task_id: str, current_dir: Path) -> None:
            print(f"[rerun-error] replacing task={task_id}")
            delete_old_result(current_dir, task_id)

        try:
            execution_results = baseline.execute_plan(
                light_tasks,
                heavy_tasks,
                effective_workers,
                task_count=len(selected),
                repeat_numbers=[repeat],
                condition=condition,
                harbor=harbor,
                docker=docker,
                api=api,
                batch_dir=batch_dir,
                tasks_root=tasks_root,
                mapping_file=mapping_file,
                skill_paths_by_task=skill_paths_by_task,
                operation="rerun",
                before_run=prepare_rerun,
            )
            for execution_result in execution_results:
                failed.extend(execution_result.failures)
                setup_failed.extend(execution_result.setup_failures)
        except KeyboardInterrupt:
            print("\n[rerun-error] interrupted by user.", file=sys.stderr)
            interrupted = True

        counts = baseline.write_batch_summary(execution_dir, all_tasks, condition)
        counts = baseline.write_repeated_summary(
            batch_dir,
            all_tasks,
            condition,
            available_repeats(batch_dir),
        )
        print(
            f"[rerun-error] summary={batch_dir / 'summary.csv'} "
            f"passed={counts['passed']} failed={counts['failed']} "
            f"errors={counts['errors']} not_run={counts['not_run']}"
        )
        if setup_failed:
            print(
                f"[rerun-error] setup failed: {', '.join(setup_failed)}",
                file=sys.stderr,
            )
            result_code = 2
        elif interrupted:
            result_code = 130
        elif failed:
            print(
                f"[rerun-error] completed with ERROR tasks: {', '.join(failed)}",
                file=sys.stderr,
            )
            result_code = 1
        else:
            print(f"[rerun-error] completed tasks={len(selected)}")
            result_code = 0
    except Exception as exc:
        print(f"[rerun-error][error] {type(exc).__name__}: {exc}", file=sys.stderr)
        try:
            baseline.write_batch_summary(execution_dir, all_tasks, condition)
            baseline.write_repeated_summary(
                batch_dir,
                all_tasks,
                condition,
                available_repeats(batch_dir),
            )
        except Exception as summary_exc:
            print(
                f"[rerun-error][summary-error] "
                f"{type(summary_exc).__name__}: {summary_exc}",
                file=sys.stderr,
            )
        result_code = 1
    return result_code


if __name__ == "__main__":
    raise SystemExit(main())
