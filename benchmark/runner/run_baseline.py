from __future__ import annotations

import argparse
from collections import deque
import concurrent.futures
import csv
from dataclasses import dataclass
import json
import os
import re
import shutil
import subprocess
import sys
import threading
import tomllib
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

from tool import analyze_skill_usage, read_json

from paths import (
    AGENT_SRC_ROOT,
    CURRENT_TASKS_ROOT,
    DEFAULT_API_CONFIG,
    DEFAULT_SKILLS_ROOT,
    DEFAULT_TASKS_ROOT,
    RUNNER_ROOT,
    RUNS_ROOT,
    TASK_IMAGES_FILE,
    WORK_ROOT,
)


DEFAULT_AGENT = "my_agents.dmx_codex:DMXCodex"
DEFAULT_MODEL = "gpt-5.6-luna-cdx"
DEFAULT_CODEX_VERSION = "0.145.0"
DEFAULT_AGENT_SETUP_TIMEOUT_MULTIPLIER = "2.0"
JOB_NAME = "Job_result"
MEMORY_POLL_SECONDS = 0.1
DOCKER_COMMAND_TIMEOUT_SECONDS = 10.0
DEFAULT_TASK_WORKERS = 2
DEFAULT_MAX_PARALLEL_CPUS = 18
DEFAULT_MAX_PARALLEL_MEMORY_MIB = 32 * 1024
CONDITION_DIR_NAMES = {
    "mapping": "Skill",
    # Retained so rerun_error.py can still read batches created by older CLIs.
    "standard": "Standard",
    "high_cost": "High_cost",
    "selected": "Selected",
    "no_skill": "No_skill",
}
RUN_DIR_PREFIXES = {
    "mapping": "Skill",
    # Retained for compatibility with existing batch metadata.
    "standard": "Standard",
    "high_cost": "High Cost",
    "selected": "Selected",
    "no_skill": "No_skill",
}
RUN_BATCH_PATTERN = re.compile(r"^(?:.+_)?Run(\d+)$", re.IGNORECASE)
RUN_CLAIM_PATTERN = re.compile(r"^\.Run(\d+)\.claim$", re.IGNORECASE)
REPEAT_DIR_PATTERN = re.compile(r"^Repeat_(\d+)$", re.IGNORECASE)
BATCH_LOG_LOCK = threading.Lock()


@dataclass(frozen=True)
class TaskResources:
    cpus: int
    memory_mib: int


@dataclass(frozen=True)
class ScheduledTask:
    task_index: int
    task_id: str
    resources: TaskResources
    heavy: bool


@dataclass
class TaskExecutionResult:
    failures: list[str]
    setup_failures: list[str]


def utc_now() -> str:
    return datetime.now(timezone.utc).isoformat()


def write_json(path: Path, payload: dict[str, Any]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temp_path = path.with_suffix(path.suffix + ".tmp")
    temp_path.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    temp_path.replace(path)


def configure_standard_streams() -> None:
    """Keep Unicode Harbor output from crashing on Windows redirected consoles."""
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if not callable(reconfigure):
            continue
        try:
            reconfigure(encoding="utf-8", errors="backslashreplace")
        except (AttributeError, OSError, ValueError):
            # Embedded/test streams may expose reconfigure without supporting it.
            continue


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Run Harbor with No Skills or task-specific Skills selected by a "
            "JSONL/YAML mapping file."
        )
    )
    condition = parser.add_mutually_exclusive_group(required=True)
    condition.add_argument(
        "--no_skill",
        "--no-skill",
        dest="no_skill",
        action="store_true",
        help="Run without providing any task Skill to the Agent.",
    )
    condition.add_argument(
        "--mapping-file",
        dest="mapping_file",
        type=Path,
        metavar="PATH",
        help="Run with the task-to-Skill assignments in this JSONL/YAML mapping.",
    )
    parser.add_argument(
        "--tasks-root",
        type=Path,
        default=DEFAULT_TASKS_ROOT,
        metavar="PATH",
        help=f"Task input directory (default: {DEFAULT_TASKS_ROOT}).",
    )
    preload_group = parser.add_mutually_exclusive_group()
    preload_group.add_argument(
        "--preload-skills",
        dest="preload_skills",
        action="store_true",
        default=True,
        help=(
            "Embed each provided root SKILL.md in the initial Codex instruction "
            "while still exposing it as a mounted Skill (default)."
        ),
    )
    preload_group.add_argument(
        "--no-preload-skills",
        dest="preload_skills",
        action="store_false",
        help="Do not embed provided Skill content in the initial Codex instruction.",
    )
    parser.add_argument(
        "--repeat",
        type=int,
        default=3,
        metavar="N",
        help=(
            "Number of repetitions in one batch. Repetitions of the same task "
            "stay in one sequential worker unit (default: 3)."
        ),
    )
    parser.add_argument(
        "--task-workers",
        type=int,
        choices=(1, 2),
        default=DEFAULT_TASK_WORKERS,
        metavar="N",
        help=(
            "Maximum light tasks to run concurrently (1 or 2). Heavy tasks run "
            f"alone after light tasks (default: {DEFAULT_TASK_WORKERS})."
        ),
    )
    parser.add_argument(
        "--max-parallel-cpus",
        type=int,
        default=DEFAULT_MAX_PARALLEL_CPUS,
        metavar="N",
        help=(
            "CPU budget shared by concurrent tasks. A task using more than half "
            f"runs alone (default: {DEFAULT_MAX_PARALLEL_CPUS})."
        ),
    )
    parser.add_argument(
        "--max-parallel-memory-mib",
        type=int,
        default=DEFAULT_MAX_PARALLEL_MEMORY_MIB,
        metavar="MIB",
        help=(
            "Memory budget shared by concurrent tasks. A task using more than "
            "half runs alone (default: "
            f"{DEFAULT_MAX_PARALLEL_MEMORY_MIB} MiB)."
        ),
    )
    parser.add_argument(
        "--task",
        action="append",
        metavar="TASK_ID",
        help=(
            "Run only one task. May be repeated or supplied as a comma-separated "
            "list. If omitted, all tasks are run."
        ),
    )
    args = parser.parse_args()
    if args.repeat < 1:
        parser.error("--repeat must be at least 1")
    if args.max_parallel_cpus < 1:
        parser.error("--max-parallel-cpus must be at least 1")
    if args.max_parallel_memory_mib < 1:
        parser.error("--max-parallel-memory-mib must be at least 1")
    return args


def resolve_tasks(values: list[str] | None, tasks_root: Path) -> list[str]:
    if not tasks_root.is_dir():
        raise FileNotFoundError(f"Task input directory not found: {tasks_root}")
    available = sorted(path.name for path in tasks_root.iterdir() if path.is_dir())
    if not values:
        return available

    requested: list[str] = []
    seen: set[str] = set()
    for value in values:
        for item in value.split(","):
            task_id = item.strip()
            if task_id and task_id not in seen:
                requested.append(task_id)
                seen.add(task_id)

    missing = [task_id for task_id in requested if task_id not in available]
    if missing:
        raise ValueError(f"Unknown task(s): {', '.join(missing)}")
    return requested


def load_api_config(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise FileNotFoundError(f"API config not found: {path}")

    config: dict[str, Any] = {}
    for raw_line in path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        if line.startswith("{"):
            parsed = json.loads(line)
            if not isinstance(parsed, dict):
                raise ValueError(f"Expected a JSON object in {path}")
            config = parsed
            break
        if "=" in line:
            key, value = line.split("=", 1)
            config[key.strip()] = value.strip()

    normalized = {
        str(key).strip().lower().replace("-", "_"): str(value).strip()
        for key, value in config.items()
        if value is not None
    }
    api_key = os.environ.get("OPENAI_API_KEY") or normalized.get("api_key", "")
    base_url = os.environ.get("OPENAI_BASE_URL") or normalized.get("base_url", "")
    if not api_key or not base_url:
        raise ValueError(
            f"OPENAI_API_KEY/OPENAI_BASE_URL are missing from the environment and {path}"
        )
    return {"api_key": api_key, "base_url": base_url}


def command_path(name: str) -> str:
    resolved = shutil.which(name)
    if not resolved:
        raise FileNotFoundError(
            f"{name!r} was not found in PATH. Activate the qwen Conda environment first."
        )
    return resolved


def read_skill_mapping(path: Path) -> list[dict[str, Any]]:
    if not path.is_file():
        raise FileNotFoundError(f"Skill mapping file does not exist: {path}")

    suffix = path.suffix.lower()
    if suffix == ".jsonl":
        records: list[dict[str, Any]] = []
        for line_number, raw_line in enumerate(
            path.read_text(encoding="utf-8-sig").splitlines(), start=1
        ):
            line = raw_line.strip()
            if not line:
                continue
            try:
                record = json.loads(line)
            except json.JSONDecodeError as exc:
                raise ValueError(
                    f"Invalid JSON in {path} line {line_number}: {exc.msg}"
                ) from exc
            if not isinstance(record, dict):
                raise ValueError(
                    f"Mapping record in {path} line {line_number} must be an object"
                )
            records.append(record)
        return records

    if suffix in {".yaml", ".yml"}:
        try:
            import yaml
        except ImportError as exc:
            raise RuntimeError(
                "YAML mapping files require PyYAML; install it or use JSONL"
            ) from exc
        payload = yaml.safe_load(path.read_text(encoding="utf-8-sig"))
        if not isinstance(payload, list) or any(
            not isinstance(record, dict) for record in payload
        ):
            raise ValueError(f"YAML mapping must be a list of objects: {path}")
        return payload

    raise ValueError(
        f"Unsupported mapping format {path.suffix!r}; expected .jsonl, .yaml, or .yml"
    )


def resolve_skill_mapping(
    mapping_file: Path,
    tasks: list[str],
    skills_root: Path = DEFAULT_SKILLS_ROOT,
) -> dict[str, list[Path]]:
    records = read_skill_mapping(mapping_file)
    errors: list[str] = []
    configured: dict[str, list[str]] = {}

    for index, record in enumerate(records, start=1):
        task_id = record.get("task_id")
        skill_names = record.get("skills")
        if not isinstance(task_id, str) or not task_id.strip():
            errors.append(f"record {index}: task_id must be a non-empty string")
            continue
        task_id = task_id.strip()
        if task_id in configured:
            errors.append(f"task {task_id!r}: duplicate mapping entry")
            continue
        if not isinstance(skill_names, list) or not skill_names:
            errors.append(f"task {task_id!r}: skills must be a non-empty list")
            continue
        invalid = [
            name
            for name in skill_names
            if not isinstance(name, str) or not name.strip()
        ]
        if invalid:
            errors.append(
                f"task {task_id!r}: every Skill name must be a non-empty string"
            )
            continue
        configured[task_id] = [name.strip() for name in skill_names]

    available: dict[str, Path] = {}
    casefold_names: dict[str, str] = {}
    if not skills_root.is_dir():
        errors.append(f"central Skill directory does not exist: {skills_root}")
    else:
        for child in skills_root.iterdir():
            if not child.is_dir():
                continue
            folded = child.name.casefold()
            previous = casefold_names.get(folded)
            if previous is not None:
                errors.append(
                    f"central Skill names are not case-insensitively unique: "
                    f"{previous!r}, {child.name!r}"
                )
            else:
                casefold_names[folded] = child.name
                available[child.name] = child

    selected: dict[str, list[Path]] = {}
    for task_id in tasks:
        skill_names = configured.get(task_id)
        if skill_names is None:
            errors.append(f"task {task_id!r}: no mapping entry")
            continue
        seen: set[str] = set()
        paths: list[Path] = []
        for name in skill_names:
            if name in seen:
                errors.append(f"task {task_id!r}: duplicate Skill {name!r}")
                continue
            seen.add(name)
            if (
                Path(name).name != name
                or name in {".", ".."}
                or "/" in name
                or "\\" in name
            ):
                errors.append(f"task {task_id!r}: invalid Skill directory name {name!r}")
                continue
            skill_dir = available.get(name)
            if skill_dir is None:
                case_match = casefold_names.get(name.casefold())
                if case_match is not None:
                    errors.append(
                        f"task {task_id!r}: Skill name case mismatch {name!r}; "
                        f"expected {case_match!r}"
                    )
                else:
                    errors.append(f"task {task_id!r}: Skill not found {name!r}")
                continue
            if not (skill_dir / "SKILL.md").is_file():
                errors.append(
                    f"task {task_id!r}: Skill has no root SKILL.md: {skill_dir}"
                )
                continue
            paths.append(skill_dir)
        selected[task_id] = paths

    if errors:
        raise ValueError("Skill mapping validation failed:\n- " + "\n- ".join(errors))
    return selected


def load_task_image_map(path: Path) -> dict[str, str]:
    if not path.is_file():
        raise FileNotFoundError(
            f"Task image mapping does not exist: {path}. "
            "Run benchmark/Env/images/prepare_task_images.py first."
        )
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"Task image mapping must be a JSON object: {path}")
    images: dict[str, str] = {}
    for task_id, image in payload.items():
        if not isinstance(task_id, str) or not isinstance(image, str) or not image.strip():
            raise ValueError(f"Invalid task image mapping entry in {path}: {task_id!r} -> {image!r}")
        images[task_id] = image.strip()
    return images


def resolve_mapped_images(docker: str, tasks: list[str]) -> dict[str, str]:
    mapping_path = Path(
        os.environ.get("BENCHMARK_TASK_IMAGES_FILE", str(TASK_IMAGES_FILE))
    ).resolve()
    configured = load_task_image_map(mapping_path)
    selected: dict[str, str] = {}
    missing_mappings: list[str] = []
    missing_images: list[str] = []

    for task_id in tasks:
        image = configured.get(task_id)
        if image is None:
            missing_mappings.append(task_id)
            continue
        result = subprocess.run(
            [docker, "image", "inspect", image],
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
            check=False,
        )
        if result.returncode != 0:
            missing_images.append(f"{task_id} -> {image}")
            continue
        selected[task_id] = image

    if missing_mappings:
        raise RuntimeError(
            "Task image mapping is missing task(s); runner will not download or build them. "
            f"mapping={mapping_path} tasks="
            + ", ".join(missing_mappings)
            + ". Run benchmark/Env/images/prepare_task_images.py first."
        )
    if missing_images:
        raise RuntimeError(
            "Mapped Docker image(s) are not available locally: "
            + "; ".join(missing_images)
            + ". Runner will not download or build them. "
            "Run benchmark/Env/images/prepare_task_images.py first."
        )
    return selected


def preflight(
    tasks: list[str],
    tasks_root: Path,
) -> tuple[str, str, dict[str, Any]]:
    if not RUNNER_ROOT.is_dir():
        raise FileNotFoundError(f"Runner project not found: {RUNNER_ROOT}")

    harbor = command_path("harbor")
    docker = command_path("docker")
    api_config_path = Path(
        os.environ.get("BENCHMARK_API_CONFIG", str(DEFAULT_API_CONFIG))
    ).resolve()
    api = load_api_config(api_config_path)

    docker_check = subprocess.run(
        [docker, "info"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if docker_check.returncode != 0:
        reason = (docker_check.stderr or "").strip()
        raise RuntimeError(f"Docker daemon is unavailable. {reason}")

    mapped_images = resolve_mapped_images(docker, tasks)

    for task_id in tasks:
        task_dir = tasks_root / task_id
        for relative in (
            "instruction.md",
            "task.toml",
            "environment/Dockerfile",
            "tests/test.sh",
        ):
            if not (task_dir / relative).is_file():
                raise FileNotFoundError(f"Task {task_id!r} is missing {relative}")

    return harbor, docker, {
        **api,
        "api_config_path": str(api_config_path),
        "mapped_images": mapped_images,
    }


def assert_within(path: Path, root: Path) -> None:
    resolved_path = path.resolve()
    resolved_root = root.resolve()
    if resolved_path != resolved_root and resolved_root not in resolved_path.parents:
        raise RuntimeError(f"Refusing to modify path outside {resolved_root}: {resolved_path}")


def extended_length_path(path: Path) -> Path:
    """Return a Windows extended-length path without changing other platforms."""
    absolute = Path(os.path.abspath(path))
    if os.name != "nt":
        return absolute

    value = str(absolute)
    if value.startswith("\\\\?\\"):
        return absolute
    if value.startswith("\\\\"):
        return Path("\\\\?\\UNC\\" + value[2:])
    return Path("\\\\?\\" + value)


def clean_path(path: Path, root: Path) -> None:
    assert_within(path, root)
    filesystem_path = extended_length_path(path)
    if filesystem_path.is_dir():
        shutil.rmtree(filesystem_path)
    elif filesystem_path.exists():
        filesystem_path.unlink()


def remove_empty_parents(path: Path, root: Path) -> None:
    """Remove empty ancestors up to, but never including, root."""
    assert_within(path, root)
    resolved_root = root.resolve()
    current = path
    while current.resolve() != resolved_root:
        try:
            current.rmdir()
        except FileNotFoundError:
            pass
        except OSError:
            break
        current = current.parent


def copy_task(task_id: str, dataset_root: Path, tasks_root: Path) -> Path:
    source = tasks_root / task_id
    assert_within(dataset_root, CURRENT_TASKS_ROOT)
    target = dataset_root / task_id
    dataset_root.mkdir(parents=True, exist_ok=True)
    clean_path(target, dataset_root)
    # A staged task can easily cross Windows' legacy MAX_PATH boundary because
    # the batch, repeat, task, and condition names are all part of its path.
    # shutil.copytree otherwise reports the misleading WinError 3 for files at
    # or beyond that boundary.  Use the same extended-length representation as
    # clean_path while keeping the regular Path as the caller-facing result.
    shutil.copytree(extended_length_path(source), extended_length_path(target))
    return target


def configure_prebuilt_image(task_dir: Path, image: str) -> None:
    task_toml = task_dir / "task.toml"
    text = task_toml.read_text(encoding="utf-8")
    lines = text.splitlines()
    environment_start = next(
        (index for index, line in enumerate(lines) if line.strip() == "[environment]"),
        None,
    )
    if environment_start is None:
        raise ValueError(f"Task has no [environment] section: {task_toml}")

    environment_end = len(lines)
    for index in range(environment_start + 1, len(lines)):
        if re.match(r"^\s*\[[^\]]+\]\s*$", lines[index]):
            environment_end = index
            break

    setting = f"docker_image = {json.dumps(image)}"
    existing = next(
        (
            index
            for index in range(environment_start + 1, environment_end)
            if re.match(r"^\s*docker_image\s*=", lines[index])
        ),
        None,
    )
    if existing is None:
        lines.insert(environment_start + 1, setting)
    else:
        lines[existing] = setting
    task_toml.write_text("\n".join(lines) + "\n", encoding="utf-8")


def validate_selected_skills(
    condition: str,
    selected: list[Path],
) -> None:
    if condition == "no_skill" and selected:
        raise RuntimeError("No Skill runs must not select any Skill directories")
    if condition != "no_skill" and not selected:
        raise RuntimeError("Mapped Skill runs require at least one Skill directory")
    for skill_dir in selected:
        if not (skill_dir / "SKILL.md").is_file():
            raise FileNotFoundError(f"Selected Skill has no root SKILL.md: {skill_dir}")


def mapping_run_prefix(mapping_file: Path | None) -> str:
    if mapping_file is None:
        return "single"
    prefix = re.sub(r"[^A-Za-z0-9._-]+", "_", mapping_file.stem).strip("._-")
    if not prefix:
        raise ValueError(f"Cannot infer a run prefix from mapping file: {mapping_file}")
    return prefix


def allocate_batch_dir(condition: str, mapping_file: Path | None) -> Path:
    condition_prefix = RUN_DIR_PREFIXES.get(condition)
    if condition_prefix is None:
        raise ValueError(f"Unsupported condition: {condition}")
    prefix = f"{mapping_run_prefix(mapping_file)}_{condition_prefix}"

    RUNS_ROOT.mkdir(parents=True, exist_ok=True)
    for _ in range(1_000_000):
        existing_numbers: list[int] = []
        for child in RUNS_ROOT.iterdir():
            match = RUN_BATCH_PATTERN.fullmatch(child.name)
            if match is None:
                match = RUN_CLAIM_PATTERN.fullmatch(child.name)
            if match is not None:
                existing_numbers.append(int(match.group(1)))

        number = max(existing_numbers, default=0) + 1
        claim = RUNS_ROOT / f".Run{number:03d}.claim"
        try:
            claim.mkdir()
        except FileExistsError:
            continue

        try:
            candidate = RUNS_ROOT / f"{prefix}_Run{number:03d}"
            candidate.mkdir()
            return candidate
        finally:
            claim.rmdir()
    raise RuntimeError(f"Unable to allocate a run directory under {RUNS_ROOT}")


def task_run_dir(batch_dir: Path, task_id: str, condition: str) -> Path:
    condition_name = CONDITION_DIR_NAMES.get(condition)
    if condition_name is None:
        raise ValueError(f"Unsupported condition: {condition}")
    run_dir = batch_dir / task_id / condition_name
    run_dir.mkdir(parents=True, exist_ok=False)
    return run_dir


def repeat_dir(batch_dir: Path, repeat: int) -> Path:
    if repeat < 1:
        raise ValueError("repeat must be at least 1")
    path = batch_dir / f"Repeat_{repeat}"
    assert_within(path, batch_dir)
    return path


def repeat_number(path: Path) -> int | None:
    match = REPEAT_DIR_PATTERN.fullmatch(path.name)
    return int(match.group(1)) if match is not None else None


def task_major_schedule(
    tasks: list[str],
    repeats: list[int],
) -> list[tuple[str, int]]:
    """Keep repetitions of one task adjacent to improve API cache locality."""
    return [(task_id, repeat) for task_id in tasks for repeat in repeats]


def task_resources(task_id: str, tasks_root: Path) -> TaskResources:
    task_file = tasks_root / task_id / "task.toml"
    try:
        with task_file.open("rb") as source:
            payload = tomllib.load(source)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise ValueError(f"Unable to read task resources from {task_file}: {exc}") from exc

    environment = payload.get("environment")
    if not isinstance(environment, dict):
        raise ValueError(f"Task {task_id!r} has no [environment] table in {task_file}")

    def positive_int(field: str) -> int:
        value = environment.get(field)
        if isinstance(value, bool) or not isinstance(value, int) or value < 1:
            raise ValueError(
                f"Task {task_id!r} must declare a positive integer "
                f"environment.{field} in {task_file}"
            )
        return value

    return TaskResources(
        cpus=positive_int("cpus"),
        memory_mib=positive_int("memory_mb"),
    )


def build_execution_plan(
    tasks: list[str],
    tasks_root: Path,
    max_parallel_cpus: int,
    max_parallel_memory_mib: int,
) -> tuple[list[ScheduledTask], list[ScheduledTask]]:
    """Split tasks into safely pairable light work and exclusive heavy work."""
    if max_parallel_cpus < 1 or max_parallel_memory_mib < 1:
        raise ValueError("Parallel CPU and memory budgets must be positive")

    light_tasks: list[ScheduledTask] = []
    heavy_tasks: list[ScheduledTask] = []
    for task_index, task_id in enumerate(tasks, start=1):
        resources = task_resources(task_id, tasks_root)
        if (
            resources.cpus > max_parallel_cpus
            or resources.memory_mib > max_parallel_memory_mib
        ):
            raise ValueError(
                f"Task {task_id!r} cannot fit the parallel resource budget: "
                f"needs {resources.cpus} CPU/{resources.memory_mib} MiB; budget is "
                f"{max_parallel_cpus} CPU/{max_parallel_memory_mib} MiB"
            )

        # With at most two workers, two light tasks are guaranteed to fit both
        # budgets. Anything above half a budget is deferred to the exclusive phase.
        heavy = (
            resources.cpus * 2 > max_parallel_cpus
            or resources.memory_mib * 2 > max_parallel_memory_mib
        )
        scheduled = ScheduledTask(task_index, task_id, resources, heavy)
        (heavy_tasks if heavy else light_tasks).append(scheduled)
    return light_tasks, heavy_tasks


def execution_identity(execution_dir: Path) -> tuple[str, int]:
    repeat = repeat_number(execution_dir)
    if repeat is None:
        raise ValueError(f"Execution directory must be Repeat_N: {execution_dir}")
    return execution_dir.parent.name, repeat


def append_batch_event(
    execution_dir: Path,
    event: str,
    *,
    operation: str,
    task_id: str,
    condition: str,
    status: str | None = None,
) -> None:
    batch_name, repeat = execution_identity(execution_dir)
    fields = [
        utc_now(),
        event,
        f"operation={operation}",
        f"batch={batch_name}",
        f"repeat={repeat}",
        f"task={task_id}",
        f"condition={condition}",
    ]
    if status is not None:
        fields.append(f"status={status}")
    with BATCH_LOG_LOCK:
        with (execution_dir.parent / "batch.log").open("a", encoding="utf-8") as log_file:
            log_file.write(" ".join(fields) + "\n")


def batch_work_root(batch_dir: Path) -> Path:
    relative = batch_dir.resolve().relative_to(RUNS_ROOT.resolve())
    return CURRENT_TASKS_ROOT.joinpath(*relative.parts)


class DockerMemoryMonitor:
    def __init__(
        self,
        docker: str,
        task_id: str,
        project_working_dir: Path | None = None,
        poll_seconds: float = MEMORY_POLL_SECONDS,
    ) -> None:
        self.docker = docker
        self.container_name_hint = task_id.lower()[:20]
        self.project_working_dir = project_working_dir
        self.poll_seconds = poll_seconds
        self.stop_event = threading.Event()
        self.baseline_ids: set[str] = set()
        self.peak_memory_mib: float | None = None
        self.peak_memory_raw: str | None = None
        self.metric: str | None = None
        self.sampler_source: str | None = None
        self.error: str | None = None
        self.sample_count = 0
        self._state_lock = threading.Lock()
        self._event_process: subprocess.Popen[str] | None = None
        self._event_thread: threading.Thread | None = None
        self._sampler_processes: dict[str, subprocess.Popen[str]] = {}
        self._sampler_threads: dict[str, threading.Thread] = {}
        self._starting_ids: set[str] = set()
        self._latest_memory_bytes: dict[str, int] = {}
        self._observed_containers: dict[str, str] = {}

    @staticmethod
    def _creation_flags() -> int:
        if os.name == "nt":
            return int(getattr(subprocess, "CREATE_NO_WINDOW", 0))
        return 0

    def _docker_command(self, arguments: list[str]) -> subprocess.CompletedProcess[str]:
        try:
            return subprocess.run(
                [self.docker, *arguments],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=False,
                timeout=DOCKER_COMMAND_TIMEOUT_SECONDS,
                creationflags=self._creation_flags(),
            )
        except subprocess.TimeoutExpired as exc:
            raise RuntimeError(
                f"docker {' '.join(arguments[:2])} timed out after "
                f"{DOCKER_COMMAND_TIMEOUT_SECONDS:g}s"
            ) from exc

    def _docker_ids(self, all_containers: bool) -> list[str]:
        option = "-aq" if all_containers else "-q"
        result = self._docker_command(["ps", option])
        if result.returncode != 0:
            raise RuntimeError((result.stderr or result.stdout).strip())
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]

    def _running_task_containers(self) -> list[tuple[str, str]]:
        result = self._docker_command(
            ["ps", "--no-trunc", "--format", "{{.ID}}\t{{.Names}}"]
        )
        if result.returncode != 0:
            raise RuntimeError((result.stderr or result.stdout).strip())
        containers: list[tuple[str, str]] = []
        for line in result.stdout.splitlines():
            parts = line.split("\t", 1)
            if len(parts) != 2 or parts[0] in self.baseline_ids:
                continue
            if self.container_name_hint in parts[1].lower():
                containers.append((parts[0], parts[1]))
        return containers

    @staticmethod
    def _normalized_windows_path(value: str) -> str:
        return os.path.normcase(os.path.normpath(value.replace("/", os.sep)))

    def _matches_project(self, container_id: str) -> bool:
        if self.project_working_dir is None:
            return True
        result = self._docker_command(
            [
                "inspect",
                "--format",
                '{{ index .Config.Labels "com.docker.compose.project.working_dir" }}',
                container_id,
            ]
        )
        if result.returncode != 0:
            raise RuntimeError((result.stderr or result.stdout).strip())
        actual = result.stdout.strip()
        if not actual or actual == "<no value>":
            return False
        expected = str(self.project_working_dir.resolve())
        return self._normalized_windows_path(actual) == self._normalized_windows_path(
            expected
        )

    def _record_sample(self, container_id: str, memory_bytes: int) -> None:
        if memory_bytes < 0:
            return
        with self._state_lock:
            self._latest_memory_bytes[container_id] = memory_bytes
            total_mib = sum(self._latest_memory_bytes.values()) / 1024 / 1024
            self.sample_count += 1
            self.metric = "container_cgroup_memory"
            self.sampler_source = "persistent_docker_exec"
            if self.peak_memory_mib is None or total_mib > self.peak_memory_mib:
                self.peak_memory_mib = total_mib
                self.peak_memory_raw = f"{total_mib:.3f} MiB"

    def _sampler_command(self, container_id: str) -> list[str]:
        interval = f"{self.poll_seconds:.3f}"
        script = (
            "if [ -r /sys/fs/cgroup/memory.current ]; then "
            "memory_file=/sys/fs/cgroup/memory.current; "
            "elif [ -r /sys/fs/cgroup/memory/memory.usage_in_bytes ]; then "
            "memory_file=/sys/fs/cgroup/memory/memory.usage_in_bytes; "
            "else echo monitor-error:no-memory-cgroup-file; exit 42; fi; "
            "while :; do IFS= read -r memory_bytes < \"$memory_file\" || exit; "
            "printf '%s\\n' \"$memory_bytes\"; "
            f"sleep {interval}; done"
        )
        return [self.docker, "exec", container_id, "sh", "-c", script]

    def _sampler_loop(self, container_id: str, container_name: str) -> None:
        sampled = False
        last_error: str | None = None
        try:
            for _ in range(5):
                if self.stop_event.is_set():
                    break
                process = subprocess.Popen(
                    self._sampler_command(container_id),
                    stdout=subprocess.PIPE,
                    stderr=subprocess.STDOUT,
                    text=True,
                    encoding="utf-8",
                    errors="replace",
                    bufsize=1,
                    creationflags=self._creation_flags(),
                )
                with self._state_lock:
                    self._sampler_processes[container_id] = process
                    self._observed_containers[container_id] = container_name
                assert process.stdout is not None
                for line in process.stdout:
                    value = line.strip()
                    try:
                        memory_bytes = int(value)
                    except ValueError:
                        if value:
                            last_error = value
                        continue
                    sampled = True
                    self._record_sample(container_id, memory_bytes)
                process.wait()
                if sampled or self.stop_event.wait(self.poll_seconds):
                    break
        except Exception as exc:
            last_error = f"{type(exc).__name__}: {exc}"
        finally:
            with self._state_lock:
                self._sampler_processes.pop(container_id, None)
                self._latest_memory_bytes.pop(container_id, None)
                self._starting_ids.discard(container_id)
                if last_error and not sampled and not self.stop_event.is_set():
                    self.error = f"container sampler {container_name}: {last_error}"

    def _consider_container(self, container_id: str, container_name: str) -> None:
        if container_id in self.baseline_ids:
            return
        if self.container_name_hint not in container_name.lower():
            return
        with self._state_lock:
            if container_id in self._starting_ids:
                return
            self._starting_ids.add(container_id)
        try:
            if not self._matches_project(container_id):
                with self._state_lock:
                    self._starting_ids.discard(container_id)
                return
        except Exception as exc:
            with self._state_lock:
                self._starting_ids.discard(container_id)
                self.error = f"container match {container_name}: {exc}"
            return
        thread = threading.Thread(
            target=self._sampler_loop,
            args=(container_id, container_name),
            daemon=True,
        )
        with self._state_lock:
            self._sampler_threads[container_id] = thread
        thread.start()

    def _event_loop(self) -> None:
        process = self._event_process
        if process is None or process.stdout is None:
            return
        try:
            for line in process.stdout:
                if self.stop_event.is_set():
                    break
                parts = line.rstrip().split("\t", 1)
                if len(parts) == 2:
                    self._consider_container(parts[0], parts[1])
        except Exception as exc:
            if not self.stop_event.is_set():
                self.error = f"docker events: {type(exc).__name__}: {exc}"

    def _event_command(self) -> list[str]:
        return [
            self.docker,
            "events",
            "--filter",
            "type=container",
            "--filter",
            "event=start",
            "--format",
            '{{.Actor.ID}}\t{{ index .Actor.Attributes "name" }}',
        ]

    def start(self) -> None:
        try:
            self.baseline_ids = set(self._docker_ids(all_containers=True))
            self._event_process = subprocess.Popen(
                self._event_command(),
                stdout=subprocess.PIPE,
                stderr=subprocess.STDOUT,
                text=True,
                encoding="utf-8",
                errors="replace",
                bufsize=1,
                creationflags=self._creation_flags(),
            )
            self._event_thread = threading.Thread(target=self._event_loop, daemon=True)
            self._event_thread.start()
            for container_id, container_name in self._running_task_containers():
                self._consider_container(container_id, container_name)
        except Exception as exc:
            self.error = f"monitor startup: {type(exc).__name__}: {exc}"

    @staticmethod
    def _terminate_process(process: subprocess.Popen[str] | None) -> None:
        if process is None or process.poll() is not None:
            return
        process.terminate()
        try:
            process.wait(timeout=3)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=3)

    def stop(self) -> None:
        self.stop_event.set()
        with self._state_lock:
            sampler_processes = list(self._sampler_processes.values())
            sampler_threads = list(self._sampler_threads.values())
        for process in sampler_processes:
            try:
                self._terminate_process(process)
            except Exception as exc:
                self.error = f"sampler shutdown: {type(exc).__name__}: {exc}"
        try:
            self._terminate_process(self._event_process)
        except Exception as exc:
            self.error = f"event shutdown: {type(exc).__name__}: {exc}"
        for thread in sampler_threads:
            thread.join(timeout=3)
        if self._event_thread is not None:
            self._event_thread.join(timeout=3)

    def report(self) -> dict[str, Any]:
        with self._state_lock:
            observed = sorted(self._observed_containers.values())
        return {
            "peak_memory_mib": self.peak_memory_mib,
            "peak_memory_raw": self.peak_memory_raw,
            "metric": self.metric or "unavailable",
            "sampler_source": self.sampler_source or "unavailable",
            "sample_interval_seconds": self.poll_seconds,
            "sample_count": self.sample_count,
            "observed_containers": observed,
            "error": self.error,
            "container_name_hint": self.container_name_hint,
            "project_working_dir": (
                str(self.project_working_dir)
                if self.project_working_dir is not None
                else None
            ),
        }


def stream_process(
    command: list[str],
    cwd: Path,
    env: dict[str, str],
    log_path: Path,
) -> tuple[int, list[str]]:
    configure_standard_streams()
    output_tail: deque[str] = deque(maxlen=40)
    process = subprocess.Popen(
        command,
        cwd=cwd,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    try:
        assert process.stdout is not None
        with log_path.open("a", encoding="utf-8") as log_file:
            for line in process.stdout:
                print(line, end="")
                log_file.write(line)
                log_file.flush()
                stripped = line.rstrip()
                if stripped:
                    output_tail.append(stripped)
        return process.wait(), list(output_tail)
    except KeyboardInterrupt:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
        raise


def seconds_between(start: Any, end: Any) -> float | None:
    def parse(value: Any) -> datetime | None:
        if not isinstance(value, str) or not value:
            return None
        normalized = value[:-1] + "+00:00" if value.endswith("Z") else value
        try:
            parsed = datetime.fromisoformat(normalized)
        except ValueError:
            return None
        if parsed.tzinfo is None:
            parsed = parsed.replace(tzinfo=timezone.utc)
        return parsed

    start_at = parse(start)
    end_at = parse(end)
    if start_at is None or end_at is None:
        return None
    return round(max((end_at - start_at).total_seconds(), 0.0), 3)


def phase_costs(trial: dict[str, Any]) -> dict[str, float | None]:
    costs: dict[str, float | None] = {}
    for phase in ("environment_setup", "agent_setup", "agent_execution", "verifier"):
        timing = trial.get(phase)
        timing = timing if isinstance(timing, dict) else {}
        costs[f"{phase}_sec"] = seconds_between(
            timing.get("started_at"),
            timing.get("finished_at"),
        )
    costs["total_sec"] = seconds_between(
        trial.get("started_at"),
        trial.get("finished_at"),
    )
    return costs


def trial_passed(trial: dict[str, Any], trial_dir: Path) -> bool:
    if trial.get("exception_info") is not None:
        return False

    verifier_result = trial.get("verifier_result")
    verifier_result = verifier_result if isinstance(verifier_result, dict) else {}
    rewards = verifier_result.get("rewards")
    rewards = rewards if isinstance(rewards, dict) else {}
    numeric_rewards = [
        value
        for value in rewards.values()
        if isinstance(value, (int, float)) and not isinstance(value, bool)
    ]
    if numeric_rewards:
        return all(value > 0 for value in numeric_rewards)

    ctrf = read_json(trial_dir / "verifier" / "ctrf.json") or {}
    results = ctrf.get("results")
    results = results if isinstance(results, dict) else {}
    summary = results.get("summary")
    summary = summary if isinstance(summary, dict) else {}
    failed = summary.get("failed")
    tests = summary.get("tests")
    return (
        isinstance(failed, (int, float))
        and isinstance(tests, (int, float))
        and failed == 0
        and tests > 0
    )


def trial_failure_reason(trial: dict[str, Any], trial_dir: Path) -> str | None:
    exception = trial.get("exception_info")
    if exception is not None:
        return json.dumps(
            compact_error(exception),
            ensure_ascii=False,
            separators=(",", ":"),
        )

    ctrf = read_json(trial_dir / "verifier" / "ctrf.json") or {}
    results = ctrf.get("results")
    results = results if isinstance(results, dict) else {}
    tests = results.get("tests")
    tests = tests if isinstance(tests, list) else []
    failures: list[str] = []
    for test in tests:
        if not isinstance(test, dict) or test.get("status") != "failed":
            continue
        name = str(test.get("name") or "unnamed test")
        trace = str(test.get("trace") or "")
        assertion_lines = [
            line.strip()[1:].strip()
            for line in trace.splitlines()
            if line.strip().startswith("E ")
        ]
        detail = assertion_lines[0] if assertion_lines else str(
            test.get("message") or "failed"
        )
        failures.append(f"{name}: {detail}")
    if failures:
        return "; ".join(failures)

    verifier_result = trial.get("verifier_result")
    verifier_result = verifier_result if isinstance(verifier_result, dict) else {}
    rewards = verifier_result.get("rewards")
    rewards = rewards if isinstance(rewards, dict) else {}
    failed_rewards = {
        str(key): value
        for key, value in rewards.items()
        if isinstance(value, (int, float))
        and not isinstance(value, bool)
        and value <= 0
    }
    if failed_rewards:
        values = ", ".join(f"{key}={value}" for key, value in failed_rewards.items())
        return f"Verifier reward did not pass: {values}"
    return None


def compact_error(value: Any) -> Any:
    if value is None or isinstance(value, (bool, int, float)):
        return value
    if isinstance(value, str):
        return value[-4000:]
    if isinstance(value, list):
        return [compact_error(item) for item in value[-10:]]
    if isinstance(value, dict):
        preferred = (
            "exception_type",
            "type",
            "message",
            "exception_message",
            "traceback",
        )
        selected = {key: value[key] for key in preferred if key in value}
        if not selected:
            selected = dict(list(value.items())[-10:])
        return {str(key): compact_error(item) for key, item in selected.items()}
    return str(value)[-4000:]


def harbor_summary(run_dir: Path) -> dict[str, Any] | None:
    job_dir = run_dir / JOB_NAME
    job_result = read_json(job_dir / "result.json")
    if job_result is None:
        return None

    stats = job_result.get("stats")
    stats = stats if isinstance(stats, dict) else {}
    trial_paths = sorted(
        path / "result.json"
        for path in job_dir.iterdir()
        if path.is_dir() and (path / "result.json").is_file()
    )
    trials: list[dict[str, Any]] = []
    for result_path in trial_paths:
        trial = read_json(result_path) or {}
        agent_result = trial.get("agent_result")
        agent_result = agent_result if isinstance(agent_result, dict) else {}
        input_tokens = agent_result.get("n_input_tokens")
        if not isinstance(input_tokens, int) or isinstance(input_tokens, bool):
            input_tokens = None
        output_tokens = agent_result.get("n_output_tokens")
        if not isinstance(output_tokens, int) or isinstance(output_tokens, bool):
            output_tokens = None
        checkpoint = read_json(result_path.parent / "agent" / "token_usage.json") or {}
        checkpoint_payload = checkpoint.get("payload")
        checkpoint_payload = (
            checkpoint_payload if isinstance(checkpoint_payload, dict) else {}
        )
        checkpoint_info = checkpoint_payload.get("info")
        checkpoint_info = checkpoint_info if isinstance(checkpoint_info, dict) else {}
        checkpoint_usage = checkpoint_info.get("total_token_usage")
        checkpoint_usage = (
            checkpoint_usage if isinstance(checkpoint_usage, dict) else {}
        )
        if input_tokens is None:
            checkpoint_input = checkpoint_usage.get("input_tokens")
            if isinstance(checkpoint_input, int) and not isinstance(checkpoint_input, bool):
                input_tokens = checkpoint_input
        if output_tokens is None:
            checkpoint_output = checkpoint_usage.get("output_tokens")
            if isinstance(checkpoint_output, int) and not isinstance(checkpoint_output, bool):
                output_tokens = checkpoint_output
        trials.append(
            {
                "passed": trial_passed(trial, result_path.parent),
                "error": compact_error(trial.get("exception_info")),
                "failure_reason": trial_failure_reason(trial, result_path.parent),
                "phase_cost": phase_costs(trial),
                "llm_cost_usd": agent_result.get("cost_usd"),
                "agent_input_tokens": input_tokens,
                "agent_output_tokens": output_tokens,
            }
        )

    llm_cost = stats.get("cost_usd")
    if not isinstance(llm_cost, (int, float)) or isinstance(llm_cost, bool):
        llm_cost = 0.0
        for trial in trials:
            trial_cost = trial["llm_cost_usd"]
            if isinstance(trial_cost, (int, float)) and not isinstance(trial_cost, bool):
                llm_cost += trial_cost

    input_token_counts = [
        trial["agent_input_tokens"]
        for trial in trials
        if trial["agent_input_tokens"] is not None
    ]
    output_token_counts = [
        trial["agent_output_tokens"]
        for trial in trials
        if trial["agent_output_tokens"] is not None
    ]

    return {
        "passed": bool(trials) and all(item["passed"] for item in trials),
        "errors": [item["error"] for item in trials if item["error"] is not None],
        "failure_reason": "; ".join(
            item["failure_reason"] for item in trials if item["failure_reason"]
        )
        or None,
        "phase_cost": trials[0]["phase_cost"] if len(trials) == 1 else [
            item["phase_cost"] for item in trials
        ],
        "llm_cost_usd": llm_cost,
        "agent_input_tokens": sum(input_token_counts) if input_token_counts else None,
        "agent_output_tokens": sum(output_token_counts) if output_token_counts else None,
        "n_trials": job_result.get("n_total_trials"),
        "n_errored_trials": stats.get("n_errored_trials"),
    }


def run_task(
    task_id: str,
    condition: str,
    harbor: str,
    docker: str,
    api: dict[str, Any],
    batch_dir: Path,
    tasks_root: Path,
    mapping_file: Path | None,
    skill_paths_by_task: dict[str, list[Path]],
    operation: str = "run",
) -> int:
    if operation not in {"run", "rerun"}:
        raise ValueError(f"Unsupported operation: {operation}")
    batch_name, repeat = execution_identity(batch_dir)
    repeat_label = str(repeat)
    run_dir = task_run_dir(batch_dir, task_id, condition)
    task_work_root = batch_work_root(batch_dir) / task_id
    dataset_root = task_work_root / condition
    summary_path = run_dir / "run_summary.json"
    log_path = run_dir / "baseline.log"
    mapped_images = api.get("mapped_images")
    if not isinstance(mapped_images, dict) or task_id not in mapped_images:
        raise RuntimeError(f"No preflight mapped image selected for {task_id}")
    cached_image = str(mapped_images[task_id])
    summary: dict[str, Any] = {
        "schema_version": 9,
        "task_id": task_id,
        "condition": condition,
        "batch": batch_name,
        "repeat": repeat,
        "operation": operation,
        "tasks_root": str(tasks_root),
        "mapping_file": str(mapping_file) if mapping_file is not None else None,
        "skills_root": str(DEFAULT_SKILLS_ROOT),
        "status": "preparing",
        "passed": None,
        "error": None,
        "failure_reason": None,
        "peak_memory": None,
        "phase_cost": None,
        "llm_cost_usd": None,
        "agent_input_tokens": None,
        "agent_output_tokens": None,
        "image_cache": {
            "image": cached_image,
            "reused": True,
        },
        "skill_audit": None,
        "skill_preload_enabled": os.environ.get("BENCHMARK_PRELOAD_SKILLS") == "1",
        "harbor_results_dir": JOB_NAME,
    }

    monitor: DockerMemoryMonitor | None = None
    harbor_exit_code: int | None = None
    output_tail: list[str] = []
    append_batch_event(
        batch_dir,
        "START",
        operation=operation,
        task_id=task_id,
        condition=condition,
    )
    try:
        target_task = copy_task(task_id, dataset_root, tasks_root)
        configure_prebuilt_image(target_task, cached_image)
        harbor_skill_paths = skill_paths_by_task.get(task_id, [])
        validate_selected_skills(condition, harbor_skill_paths)
        provided_skills = [path.name for path in harbor_skill_paths]
        summary["status"] = "running"

        env = os.environ.copy()
        env["OPENAI_API_KEY"] = api["api_key"]
        env["OPENAI_BASE_URL"] = api["base_url"]
        env["PYTHONUTF8"] = "1"
        env["PYTHONIOENCODING"] = "utf-8"
        current_pythonpath = env.get("PYTHONPATH", "")
        env["PYTHONPATH"] = str(AGENT_SRC_ROOT) + (
            os.pathsep + current_pythonpath if current_pythonpath else ""
        )
        command = [
            harbor,
            "run",
            "--path",
            str(dataset_root),
            "--agent",
            os.environ.get("BENCHMARK_HARBOR_AGENT", DEFAULT_AGENT),
            "--model",
            os.environ.get("BENCHMARK_HARBOR_MODEL", DEFAULT_MODEL),
            "--ak",
            f"version={os.environ.get('BENCHMARK_CODEX_VERSION', DEFAULT_CODEX_VERSION)}",
            "--agent-setup-timeout-multiplier",
            os.environ.get(
                "BENCHMARK_AGENT_SETUP_TIMEOUT_MULTIPLIER",
                DEFAULT_AGENT_SETUP_TIMEOUT_MULTIPLIER,
            ),
            "--jobs-dir",
            str(run_dir),
            "--job-name",
            JOB_NAME,
            "--n-concurrent",
            "1",
            "--no-force-build",
            "--no-delete",
            "--yes",
            "--ae",
            f"OPENAI_API_KEY={api['api_key']}",
            "--ae",
            f"OPENAI_BASE_URL={api['base_url']}",
            "--ae",
            "DMX_CODEX_CLEAN_IMAGE_SKILLS=1",
        ]
        if summary["skill_preload_enabled"]:
            command.extend(["--ae", "DMX_CODEX_PRELOAD_SKILLS=1"])
        for skill_path in harbor_skill_paths:
            command.extend(["--skill", str(skill_path)])

        print(
            f"\n[baseline] operation={operation} batch={batch_name} "
            f"repeat={repeat_label} task={task_id} condition={condition} "
            f"image={cached_image} provided_skills={provided_skills} run={run_dir}"
        )
        log_path.write_text(
            f"{utc_now()} START operation={operation} batch={batch_name} "
            f"repeat={repeat_label} task={task_id} condition={condition} "
            f"image={cached_image} "
            f"provided_skills={json.dumps(provided_skills, ensure_ascii=False)}\n",
            encoding="utf-8",
        )
        monitor = DockerMemoryMonitor(
            docker,
            task_id,
            project_working_dir=target_task / "environment",
        )
        monitor.start()
        harbor_exit_code, output_tail = stream_process(
            command=command,
            cwd=RUNNER_ROOT,
            env=env,
            log_path=log_path,
        )
        monitor.stop()
        summary["peak_memory"] = monitor.report()
        harbor_result = harbor_summary(run_dir)
        if harbor_result is not None:
            summary["passed"] = harbor_result["passed"]
            summary["failure_reason"] = harbor_result["failure_reason"]
            summary["phase_cost"] = harbor_result["phase_cost"]
            summary["llm_cost_usd"] = harbor_result["llm_cost_usd"]
            summary["agent_input_tokens"] = harbor_result["agent_input_tokens"]
            summary["agent_output_tokens"] = harbor_result["agent_output_tokens"]
        summary["skill_audit"] = analyze_skill_usage(
            run_dir / JOB_NAME,
            provided_skills,
            preloaded_skills=provided_skills if summary["skill_preload_enabled"] else [],
        )

        if harbor_exit_code != 0:
            summary["status"] = "harbor_error"
            summary["error"] = (
                harbor_result["errors"]
                if harbor_result and harbor_result["errors"]
                else {"harbor_exit_code": harbor_exit_code, "output_tail": output_tail}
            )
            print(
                f"[baseline][harbor-failed] task={task_id} "
                f"exit_code={harbor_exit_code}",
                file=sys.stderr,
            )
            return harbor_exit_code
        if harbor_result is None:
            summary["status"] = "result_missing"
            summary["error"] = {"message": "Harbor result missing", "output_tail": output_tail}
            print(
                f"[baseline][result-missing] task={task_id} "
                f"path={run_dir / JOB_NAME / 'result.json'}",
                file=sys.stderr,
            )
            return 1
        if int(harbor_result["n_errored_trials"] or 0) > 0:
            summary["status"] = "trial_error"
            summary["error"] = harbor_result["errors"] or {
                "message": "Harbor reported an errored trial",
                "output_tail": output_tail,
            }
            print(
                f"[baseline][trial-error] task={task_id} "
                f"errors={summary['error']}",
                file=sys.stderr,
            )
            return 1

        if not summary["skill_audit"]["passed"]:
            summary["status"] = "error"
            summary["error"] = {
                "message": "Skill audit failed",
                "skill_audit": summary["skill_audit"],
            }
            print(
                f"[baseline][skill-audit-failed] task={task_id} "
                f"audit={summary['skill_audit']}",
                file=sys.stderr,
            )
            return 1

        summary["status"] = "completed"
        return 0
    except KeyboardInterrupt:
        summary["status"] = "interrupted"
        summary["error"] = "Interrupted by user"
        raise
    except Exception as exc:
        summary["status"] = "error"
        summary["error"] = f"{type(exc).__name__}: {exc}"
        print(f"[baseline][error] {task_id}: {summary['error']}", file=sys.stderr)
        return 1
    finally:
        if monitor is not None and not monitor.stop_event.is_set():
            monitor.stop()
        if monitor is not None:
            summary["peak_memory"] = monitor.report()
        if summary["skill_audit"] is None:
            summary["skill_audit"] = analyze_skill_usage(
                run_dir / JOB_NAME,
                provided_skills if "provided_skills" in locals() else [],
                preloaded_skills=(
                    provided_skills
                    if summary["skill_preload_enabled"] and "provided_skills" in locals()
                    else []
                ),
            )
        summary["harbor_exit_code"] = harbor_exit_code
        write_json(summary_path, summary)

        if summary["status"] == "completed":
            outcome = "PASS" if summary["passed"] else "FAIL"
            detail = ""
        else:
            outcome = "ERROR"
            detail = " " + json.dumps(
                summary["error"],
                ensure_ascii=False,
                separators=(",", ":"),
            )
        with log_path.open("a", encoding="utf-8") as log_file:
            log_file.write(
                f"{utc_now()} {outcome} operation={operation} batch={batch_name} "
                f"repeat={repeat_label} task={task_id} condition={condition}{detail}\n"
            )
        append_batch_event(
            batch_dir,
            outcome,
            operation=operation,
            task_id=task_id,
            condition=condition,
            status=str(summary["status"]),
        )

        if task_work_root.exists():
            clean_path(task_work_root, CURRENT_TASKS_ROOT)
        remove_empty_parents(task_work_root.parent, CURRENT_TASKS_ROOT)


def summary_failure_reason(summary: dict[str, Any]) -> str:
    reason = summary.get("failure_reason")
    if isinstance(reason, str) and reason.strip():
        return reason.strip()
    error = summary.get("error")
    if error is not None:
        if isinstance(error, str):
            return error
        return json.dumps(error, ensure_ascii=False, separators=(",", ":"))
    if summary.get("status") == "completed" and summary.get("passed") is False:
        return "Verifier did not pass"
    return ""


SUMMARY_FIELDNAMES = [
    "task_id",
    "condition",
    "operation",
    "result",
    "status",
    "passed",
    "failure_reason",
    "harbor_exit_code",
    "llm_cost_usd",
    "agent_input_tokens",
    "agent_output_tokens",
    "total_sec",
    "peak_memory_mib",
    "image",
    "image_reused",
    "provided_skills",
    "available_skills",
    "loaded_skills",
    "explicitly_loaded_skills",
    "preloaded_skills",
    "skill_preload_enabled",
    "skill_audit_passed",
]


def build_batch_summary_rows(
    batch_dir: Path,
    tasks: list[str],
    condition: str,
) -> tuple[list[dict[str, Any]], dict[str, int]]:
    condition_name = CONDITION_DIR_NAMES[condition]
    counts = {"passed": 0, "failed": 0, "errors": 0, "not_run": 0}
    rows: list[dict[str, Any]] = []
    for task_id in tasks:
        summary_path = batch_dir / task_id / condition_name / "run_summary.json"
        summary = read_json(summary_path)
        if summary is None:
            result = "NOT_RUN"
            status = "not_run"
            passed: Any = ""
            counts["not_run"] += 1
            summary = {}
        else:
            status = str(summary.get("status") or "")
            passed = summary.get("passed")
            if status == "completed" and passed is True:
                result = "PASS"
                counts["passed"] += 1
            elif status == "completed" and passed is False:
                result = "FAIL"
                counts["failed"] += 1
            else:
                result = "ERROR"
                counts["errors"] += 1

        phase_cost = summary.get("phase_cost")
        phase_cost = phase_cost if isinstance(phase_cost, dict) else {}
        peak_memory = summary.get("peak_memory")
        peak_memory = peak_memory if isinstance(peak_memory, dict) else {}
        image_cache = summary.get("image_cache")
        image_cache = image_cache if isinstance(image_cache, dict) else {}
        skill_audit = summary.get("skill_audit")
        skill_audit = skill_audit if isinstance(skill_audit, dict) else {}
        rows.append(
            {
                "task_id": task_id,
                "condition": condition,
                "operation": summary.get("operation", ""),
                "result": result,
                "status": status,
                "passed": passed,
                "failure_reason": summary_failure_reason(summary),
                "harbor_exit_code": summary.get("harbor_exit_code", ""),
                "llm_cost_usd": summary.get("llm_cost_usd", ""),
                "agent_input_tokens": summary.get("agent_input_tokens", ""),
                "agent_output_tokens": summary.get("agent_output_tokens", ""),
                "total_sec": phase_cost.get("total_sec", ""),
                "peak_memory_mib": peak_memory.get("peak_memory_mib", ""),
                "image": image_cache.get("image", ""),
                "image_reused": image_cache.get("reused", ""),
                "provided_skills": json.dumps(
                    skill_audit.get("provided_skills", []),
                    ensure_ascii=False,
                    separators=(",", ":"),
                ) if skill_audit else "",
                "available_skills": json.dumps(
                    skill_audit.get("available_skills", []),
                    ensure_ascii=False,
                    separators=(",", ":"),
                ) if skill_audit else "",
                "loaded_skills": json.dumps(
                    skill_audit.get("loaded_skills", []),
                    ensure_ascii=False,
                    separators=(",", ":"),
                ) if skill_audit else "",
                "explicitly_loaded_skills": json.dumps(
                    skill_audit.get("explicitly_loaded_skills", []),
                    ensure_ascii=False,
                    separators=(",", ":"),
                ) if skill_audit else "",
                "preloaded_skills": json.dumps(
                    skill_audit.get("preloaded_skills", []),
                    ensure_ascii=False,
                    separators=(",", ":"),
                ) if skill_audit else "",
                "skill_preload_enabled": summary.get("skill_preload_enabled", False),
                "skill_audit_passed": skill_audit.get("passed", ""),
            }
        )
    return rows, counts


def write_batch_summary(
    batch_dir: Path,
    tasks: list[str],
    condition: str,
) -> dict[str, int]:
    rows, counts = build_batch_summary_rows(batch_dir, tasks, condition)

    summary_csv = batch_dir / "summary.csv"
    with summary_csv.open("w", newline="", encoding="utf-8-sig") as output:
        writer = csv.DictWriter(output, fieldnames=SUMMARY_FIELDNAMES)
        writer.writeheader()
        writer.writerows(rows)
    return counts


def write_repeated_summary(
    batch_dir: Path,
    tasks: list[str],
    condition: str,
    repeats: list[int],
) -> dict[str, int]:
    fieldnames = ["repeat", *SUMMARY_FIELDNAMES]
    counts = {"passed": 0, "failed": 0, "errors": 0, "not_run": 0}
    rows: list[dict[str, Any]] = []
    for number in repeats:
        current_dir = repeat_dir(batch_dir, number)
        current_rows, current_counts = build_batch_summary_rows(
            current_dir,
            tasks,
            condition,
        )
        for row in current_rows:
            rows.append({"repeat": number, **row})
        for key in counts:
            counts[key] += current_counts[key]

    summary_csv = batch_dir / "summary.csv"
    with summary_csv.open("w", newline="", encoding="utf-8-sig") as output:
        writer = csv.DictWriter(output, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)
    return counts


def run_scheduled_task(
    task: ScheduledTask,
    *,
    task_count: int,
    repeat_numbers: list[int],
    condition: str,
    harbor: str,
    docker: str,
    api: dict[str, Any],
    batch_dir: Path,
    tasks_root: Path,
    mapping_file: Path | None,
    skill_paths_by_task: dict[str, list[Path]],
    operation: str = "run",
    before_run: Callable[[str, Path], None] | None = None,
) -> TaskExecutionResult:
    """Run every repetition for one task sequentially as one scheduling unit."""
    failures: list[str] = []
    setup_failures: list[str] = []

    print(
        f"[baseline][task {task.task_index}/{task_count}] task={task.task_id} "
        f"resources={task.resources.cpus}CPU/{task.resources.memory_mib}MiB "
        f"mode={'exclusive' if task.heavy else 'parallel'}"
    )
    for number in repeat_numbers:
        current_dir = repeat_dir(batch_dir, number)
        run_label = f"Repeat_{number}/{task.task_id}"
        print(
            f"[baseline] task={task.task_id} repeat={number}/{len(repeat_numbers)} "
            f"path={current_dir}"
        )
        if before_run is not None:
            try:
                before_run(task.task_id, current_dir)
            except Exception as exc:
                print(
                    f"[baseline][task-prepare-error] task={task.task_id} "
                    f"{type(exc).__name__}: {exc}",
                    file=sys.stderr,
                )
                failures.append(run_label)
                continue
        exit_code = run_task(
            task.task_id,
            condition,
            harbor,
            docker,
            api,
            current_dir,
            tasks_root,
            mapping_file,
            skill_paths_by_task,
            operation=operation,
        )
        if exit_code != 0:
            failures.append(run_label)

    return TaskExecutionResult(failures, setup_failures)


def run_light_tasks(
    tasks: list[ScheduledTask],
    task_workers: int,
    **run_kwargs: Any,
) -> list[TaskExecutionResult]:
    if not tasks:
        return []
    if task_workers == 1:
        results: list[TaskExecutionResult] = []
        for task in tasks:
            result = run_scheduled_task(task, **run_kwargs)
            results.append(result)
            if result.setup_failures:
                break
        return results

    executor = concurrent.futures.ThreadPoolExecutor(
        max_workers=min(task_workers, len(tasks)),
        thread_name_prefix="benchmark-task",
    )
    future_to_task = {
        executor.submit(run_scheduled_task, task, **run_kwargs): task
        for task in tasks
    }
    results_by_index: dict[int, TaskExecutionResult] = {}
    try:
        for future in concurrent.futures.as_completed(future_to_task):
            task = future_to_task[future]
            results_by_index[task.task_index] = future.result()
    except BaseException:
        for future in future_to_task:
            future.cancel()
        executor.shutdown(wait=True, cancel_futures=True)
        raise
    else:
        executor.shutdown(wait=True)
    return [results_by_index[task.task_index] for task in tasks]


def execute_plan(
    light_tasks: list[ScheduledTask],
    heavy_tasks: list[ScheduledTask],
    task_workers: int,
    **run_kwargs: Any,
) -> list[TaskExecutionResult]:
    results = run_light_tasks(light_tasks, task_workers, **run_kwargs)
    if any(result.setup_failures for result in results):
        return results
    # The light executor is fully stopped before an exclusive task starts.
    for task in heavy_tasks:
        result = run_scheduled_task(task, **run_kwargs)
        results.append(result)
        if result.setup_failures:
            break
    return results


def main() -> int:
    configure_standard_streams()
    args = parse_args()
    if args.no_skill:
        condition = "no_skill"
        mapping_file = None
        os.environ["BENCHMARK_CLEAN_IMAGE_SKILLS"] = "1"
    elif args.mapping_file is not None:
        condition = "mapping"
        mapping_file = args.mapping_file.expanduser().resolve()
    else:
        raise AssertionError("argparse did not select a run condition")
    if args.preload_skills:
        os.environ["BENCHMARK_PRELOAD_SKILLS"] = "1"
    else:
        os.environ.pop("BENCHMARK_PRELOAD_SKILLS", None)
    try:
        tasks_root = args.tasks_root.expanduser().resolve()
        tasks = resolve_tasks(args.task, tasks_root)
        skill_paths_by_task = (
            {task_id: [] for task_id in tasks}
            if mapping_file is None
            else resolve_skill_mapping(mapping_file, tasks)
        )
        harbor, docker, api = preflight(tasks, tasks_root)
        light_tasks, heavy_tasks = build_execution_plan(
            tasks,
            tasks_root,
            args.max_parallel_cpus,
            args.max_parallel_memory_mib,
        )
        batch_dir = allocate_batch_dir(condition, mapping_file)
        repeat_numbers = list(range(1, args.repeat + 1))
        for number in repeat_numbers:
            repeat_dir(batch_dir, number).mkdir()
    except Exception as exc:
        print(f"[baseline][preflight-error] {type(exc).__name__}: {exc}", file=sys.stderr)
        return 2

    result_code = 1
    try:
        print(
            f"[baseline] condition={condition} tasks={len(tasks)} "
            f"repeat={args.repeat} "
            f"preload_skills={args.preload_skills} "
            f"run={batch_dir.name} tasks_root={tasks_root} "
            f"mapping_file={mapping_file} skills_root={DEFAULT_SKILLS_ROOT}"
        )
        effective_workers = args.task_workers
        print(
            f"[baseline] scheduler=resource-aware task_workers={effective_workers} "
            f"light_tasks={len(light_tasks)} heavy_tasks={len(heavy_tasks)} "
            f"budget={args.max_parallel_cpus}CPU/"
            f"{args.max_parallel_memory_mib}MiB"
        )
        if heavy_tasks:
            print(
                "[baseline] exclusive_order="
                + ",".join(task.task_id for task in heavy_tasks)
            )

        failures: list[str] = []
        interrupted = False
        setup_failures: list[str] = []
        try:
            execution_results = execute_plan(
                light_tasks,
                heavy_tasks,
                effective_workers,
                task_count=len(tasks),
                repeat_numbers=repeat_numbers,
                condition=condition,
                harbor=harbor,
                docker=docker,
                api=api,
                batch_dir=batch_dir,
                tasks_root=tasks_root,
                mapping_file=mapping_file,
                skill_paths_by_task=skill_paths_by_task,
            )
            for execution_result in execution_results:
                failures.extend(execution_result.failures)
                setup_failures.extend(execution_result.setup_failures)
        except KeyboardInterrupt:
            print("\n[baseline] interrupted by user.", file=sys.stderr)
            interrupted = True

        for number in repeat_numbers:
            write_batch_summary(repeat_dir(batch_dir, number), tasks, condition)
        counts = write_repeated_summary(
            batch_dir,
            tasks,
            condition,
            repeat_numbers,
        )
        print(
            f"[baseline] summary={batch_dir / 'summary.csv'} "
            f"passed={counts['passed']} failed={counts['failed']} "
            f"errors={counts['errors']} not_run={counts['not_run']}"
        )
        if setup_failures:
            print(
                "[baseline] setup failed: " + ", ".join(setup_failures),
                file=sys.stderr,
            )
            result_code = 2
        elif interrupted:
            result_code = 130
        elif failures:
            print(
                f"[baseline] completed with failed runs: {', '.join(failures)}",
                file=sys.stderr,
            )
            result_code = 1
        else:
            print(
                f"[baseline] completed condition={condition} "
                f"tasks={len(tasks)} repeat={args.repeat}"
            )
            result_code = 0
    except Exception as exc:
        print(
            f"[baseline][error] {type(exc).__name__}: {exc}",
            file=sys.stderr,
        )
        result_code = 1

    return result_code


if __name__ == "__main__":
    raise SystemExit(main())
