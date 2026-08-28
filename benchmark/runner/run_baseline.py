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
import time
import tomllib
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Callable

from tool import analyze_skill_usage, read_json

from paths import (
    AGENT_SRC_ROOT,
    CURRENT_TASKS_ROOT,
    DEFAULT_API_CONFIG,
    DEFAULT_MAPPING_ROOT,
    DEFAULT_TASKS_ROOT,
    RUNNER_ROOT,
    RUNS_ROOT,
    SINK_DOCKER_ROOT,
    TASK_IMAGES_FILE,
    WORK_ROOT,
)


SINK_START_SCRIPT = SINK_DOCKER_ROOT / "start_container.sh"
SINK_STOP_SCRIPT = SINK_DOCKER_ROOT / "stop_container.sh"
DANGER_NETWORK_NAME = "skill_net_network"
DANGER_NETWORK_COMPOSE = "danger-network.compose.yaml"
DANGER_MONITOR_LOG_NAME = "danger-monitor.log"

DEFAULT_AGENT = "my_agents.dmx_codex:DMXCodex"
DEFAULT_MODEL = "deepseek-v4-flash"
DEFAULT_CODEX_VERSION = "0.145.0"
DEFAULT_AGENT_SETUP_TIMEOUT_MULTIPLIER = "2.0"
JOB_NAME = "Job_result"
MEMORY_POLL_SECONDS = 0.05
DEFAULT_TASK_WORKERS = 2
DEFAULT_MAX_PARALLEL_CPUS = 16
DEFAULT_MAX_PARALLEL_MEMORY_MIB = 24 * 1024
CONDITION_DIR_NAMES = {
    "standard": "Standard",
    "high_cost": "High_cost",
    "danger": "Danger",
    "selected": "Selected",
    "no_skill": "No_skill",
}
RUN_DIR_PREFIXES = {
    "standard": "Standard",
    "high_cost": "High Cost",
    "danger": "Risk",
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
    monitor_stop_failures: list[str]


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
            "Run Harbor with No Skills, Standard Skills, Danger Path_Read Skills, "
            "task-specific High Cost Skills, or task-specific Selected Skills."
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
        "--standard",
        action="store_true",
        help="Run the Standard baseline for every task (or the tasks selected by --task).",
    )
    condition.add_argument(
        "--high_cost",
        "--high-cost",
        dest="high_cost",
        action="store_true",
        help="Run the High Cost baseline for every task (or the tasks selected by --task).",
    )
    condition.add_argument(
        "--selected",
        action="store_true",
        help="Run the task-specific Skills under each task's Selected directory.",
    )
    condition.add_argument(
        "--danger",
        "--Danger",
        dest="danger",
        action="store_true",
        help=(
            "Run the Danger baseline using every first-level Skill under "
            "Danger/Path_Read for each task."
        ),
    )
    parser.add_argument(
        "--tasks-root",
        type=Path,
        default=DEFAULT_TASKS_ROOT,
        metavar="PATH",
        help=f"Task input directory (default: {DEFAULT_TASKS_ROOT}).",
    )
    parser.add_argument(
        "--mapping-root",
        type=Path,
        default=DEFAULT_MAPPING_ROOT,
        metavar="PATH",
        help=f"Skill Mapping input directory (default: {DEFAULT_MAPPING_ROOT}).",
    )
    parser.add_argument(
        "--repeat",
        type=int,
        default=1,
        metavar="N",
        help=(
            "Number of repetitions in one batch. Repetitions of the same task "
            "stay in one sequential worker unit (default: 1)."
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


def bash_path() -> str:
    candidates: list[Path] = []
    if os.name == "nt":
        program_files = os.environ.get("ProgramFiles")
        if program_files:
            candidates.append(Path(program_files) / "Git" / "bin" / "bash.exe")
    resolved = shutil.which("bash")
    if resolved:
        candidates.append(Path(resolved))

    for candidate in candidates:
        if candidate.is_file():
            return str(candidate)
    raise FileNotFoundError(
        "bash was not found; Git Bash is required to manage the Danger sink container"
    )


def run_sink_script(
    script: Path,
    *,
    extra_env: dict[str, str] | None = None,
) -> str:
    if not script.is_file():
        raise FileNotFoundError(f"Sink lifecycle script not found: {script}")
    relative_script = script.relative_to(RUNNER_ROOT).as_posix()
    env = os.environ.copy()
    env["NETWORK_NAME"] = DANGER_NETWORK_NAME
    if extra_env:
        env.update(extra_env)
    result = subprocess.run(
        [bash_path(), relative_script],
        cwd=RUNNER_ROOT,
        env=env,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    output = result.stdout.rstrip()
    if result.returncode != 0:
        raise RuntimeError(
            f"Sink lifecycle script failed ({script.name}, exit={result.returncode}): "
            f"{output or 'no output'}"
        )
    return output


def git_bash_path(path: Path) -> str:
    resolved = path.resolve().as_posix()
    if os.name == "nt":
        drive_match = re.match(r"^([A-Za-z]):/(.*)$", resolved)
        if drive_match:
            drive, remainder = drive_match.groups()
            return f"/{drive.lower()}/{remainder}"
    return resolved


def start_danger_monitor(log_file: Path) -> dict[str, str]:
    # Always create a fresh receiver lifecycle for this Danger batch so the
    # log cannot be shared with a previous run. Keep the receiver log beside
    # the rest of that batch's artifacts instead of in sink_network.
    log_file.parent.mkdir(parents=True, exist_ok=True)
    stop_output = run_sink_script(SINK_STOP_SCRIPT)
    start_output = run_sink_script(
        SINK_START_SCRIPT,
        extra_env={
            "LOG_DIR": git_bash_path(log_file.parent),
            "LOG_FILE_NAME": log_file.name,
        },
    )
    log_match = re.search(r"^Log file:\s*(.+)$", start_output, re.MULTILINE)
    if log_match is None:
        try:
            run_sink_script(SINK_STOP_SCRIPT)
        except Exception:
            pass
        raise RuntimeError(
            "Danger sink started but did not report its log file: "
            + start_output
        )
    if not log_file.is_file():
        try:
            run_sink_script(SINK_STOP_SCRIPT)
        except Exception:
            pass
        raise RuntimeError(
            "Danger sink did not create its expected batch log: "
            f"{log_file} (reported {log_match.group(1).strip()})"
        )
    return {
        "network": DANGER_NETWORK_NAME,
        "log_file": str(log_file),
        "stop_output": stop_output,
        "start_output": start_output,
    }


def stop_danger_monitor() -> str:
    return run_sink_script(SINK_STOP_SCRIPT)


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
    condition: str,
    tasks_root: Path,
    mapping_root: Path,
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

        group_dir = mapping_root / f"{task_id}_Gold_skill"
        if condition == "standard":
            standard_dir = group_dir / "Standard SKILLs"
            skill_dirs = skill_dirs_under(standard_dir)
            if not skill_dirs:
                raise ValueError(f"No Standard Skills found for {task_id}: {standard_dir}")
        elif condition == "high_cost":
            high_cost_dir = resolve_high_cost_dir(group_dir)
            skill_dirs = skill_dirs_under(high_cost_dir)
            if not skill_dirs:
                raise ValueError(f"No High Cost Skills found for {task_id}: {high_cost_dir}")
        elif condition == "danger":
            danger_dir = group_dir / "Danger" / "Path_Read"
            skill_dirs = danger_skill_dirs(danger_dir)
            if not skill_dirs:
                raise ValueError(f"No Danger Path_Read Skills found for {task_id}: {danger_dir}")
        elif condition == "selected":
            selected_dir = group_dir / "Selected"
            skill_dirs = skill_dirs_under(selected_dir)
            if not skill_dirs:
                raise ValueError(f"No Selected Skills found for {task_id}: {selected_dir}")
        elif condition != "no_skill":
            raise ValueError(f"Unsupported condition: {condition}")

    return harbor, docker, {
        **api,
        "api_config_path": str(api_config_path),
        "mapped_images": mapped_images,
    }


def skill_dirs_under(parent: Path) -> list[Path]:
    if not parent.is_dir():
        return []
    return sorted(
        path
        for path in parent.iterdir()
        if path.is_dir() and (path / "SKILL.md").is_file()
    )


def resolve_high_cost_dir(group_dir: Path) -> Path:
    candidates = [group_dir / "High_Cost_Skills", group_dir / "High cost"]
    existing = [path for path in candidates if path.is_dir()]
    if len(existing) == 1:
        return existing[0]
    if not existing:
        raise FileNotFoundError(
            f"High Cost directory not found under {group_dir}; expected "
            "'High_Cost_Skills' or 'High cost'"
        )
    raise ValueError(
        f"Multiple High Cost directories found under {group_dir}: "
        + ", ".join(path.name for path in existing)
    )


def danger_skill_dirs(path_read_dir: Path) -> list[Path]:
    if not path_read_dir.is_dir():
        return []
    return sorted(
        path
        for path in path_read_dir.iterdir()
        if path.is_dir() and (path / "SKILL.md").is_file()
    )


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


def write_danger_network_compose(run_dir: Path, task_id: str) -> Path:
    compose_path = run_dir / DANGER_NETWORK_COMPOSE
    write_json(
        compose_path,
        {
            "services": {
                "main": {
                    "networks": ["default", DANGER_NETWORK_NAME],
                    "environment": {
                        "BENCHMARK_TASK_ID": task_id,
                        # Backward compatibility for previously injected
                        # injected backup sender copies.
                        "CONTAINER_NAME": task_id,
                    },
                    "labels": {
                        "benchmark.task_id": task_id,
                    },
                }
            },
            "networks": {
                "default": {},
                DANGER_NETWORK_NAME: {
                    "external": True,
                    "name": DANGER_NETWORK_NAME,
                },
            },
        },
    )
    return compose_path


def standard_skill_paths(task_id: str, mapping_root: Path) -> list[Path]:
    source_root = mapping_root / f"{task_id}_Gold_skill" / "Standard SKILLs"
    return skill_dirs_under(source_root)


def danger_skill_paths(task_id: str, mapping_root: Path) -> list[Path]:
    source_root = (
        mapping_root
        / f"{task_id}_Gold_skill"
        / "Danger"
        / "Path_Read"
    )
    return danger_skill_dirs(source_root)


def high_cost_skill_paths(task_id: str, mapping_root: Path) -> list[Path]:
    group_dir = mapping_root / f"{task_id}_Gold_skill"
    return skill_dirs_under(resolve_high_cost_dir(group_dir))


def selected_skill_paths(task_id: str, mapping_root: Path) -> list[Path]:
    source_root = mapping_root / f"{task_id}_Gold_skill" / "Selected"
    return skill_dirs_under(source_root)


def validate_selected_skills(
    condition: str,
    selected: list[Path],
) -> None:
    if condition in {"standard", "high_cost", "danger", "selected"} and not selected:
        raise RuntimeError(f"{condition} runs require at least one Skill directory")
    if condition == "no_skill" and selected:
        raise RuntimeError("No Skill runs must not select any Skill directories")
    for skill_dir in selected:
        if not (skill_dir / "SKILL.md").is_file():
            raise FileNotFoundError(f"Selected Skill has no root SKILL.md: {skill_dir}")


def mapping_run_prefix(mapping_root: Path) -> str:
    parts = mapping_root.name.rsplit("_", 2)
    if len(parts) != 3 or not parts[0]:
        raise ValueError(
            "Mapping directory name must contain at least two underscores so its "
            f"run prefix can be inferred: {mapping_root.name!r}"
        )
    return parts[0]


def allocate_batch_dir(condition: str, mapping_root: Path) -> Path:
    condition_prefix = RUN_DIR_PREFIXES.get(condition)
    if condition_prefix is None:
        raise ValueError(f"Unsupported condition: {condition}")
    prefix = f"{mapping_run_prefix(mapping_root)}_{condition_prefix}"

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


def parse_memory_mib(raw: str) -> float | None:
    value = raw.strip()
    units = {
        "B": 1 / 1024 / 1024,
        "KiB": 1 / 1024,
        "MiB": 1,
        "GiB": 1024,
        "TiB": 1024 * 1024,
        "kB": 1000 / 1024 / 1024,
        "KB": 1000 / 1024 / 1024,
        "MB": 1000 * 1000 / 1024 / 1024,
        "GB": 1000 * 1000 * 1000 / 1024 / 1024,
    }
    for unit in sorted(units, key=len, reverse=True):
        if value.endswith(unit):
            try:
                return float(value[: -len(unit)].strip()) * units[unit]
            except ValueError:
                return None
    return None


def process_tree_rss_bytes(
    root_pid: int,
    *,
    proc_root: Path = Path("/proc"),
    page_size: int | None = None,
) -> int | None:
    """Sum resident pages for a process and all of its descendants."""
    pending = [root_pid]
    seen: set[int] = set()
    total_pages = 0
    sampled = False
    while pending:
        pid = pending.pop()
        if pid in seen:
            continue
        seen.add(pid)
        try:
            fields = (proc_root / str(pid) / "statm").read_text(
                encoding="ascii"
            ).split()
            if len(fields) >= 2:
                total_pages += int(fields[1])
                sampled = True
        except (OSError, ValueError):
            pass
        try:
            children = proc_root / str(pid) / "task" / str(pid) / "children"
            pending.extend(int(value) for value in children.read_text(
                encoding="ascii"
            ).split())
        except (OSError, ValueError):
            pass
    if not sampled:
        return None
    if page_size is None:
        try:
            page_size = os.sysconf("SC_PAGE_SIZE")
        except (AttributeError, OSError, ValueError):
            return None
    return total_pages * page_size


def parse_docker_top_rss_bytes(output: str) -> int | None:
    rss_kib: list[int] = []
    for line in output.splitlines():
        try:
            rss_kib.append(int(line.strip()))
        except ValueError:
            continue
    return sum(rss_kib) * 1024 if rss_kib else None


class DockerMemoryMonitor:
    def __init__(
        self,
        docker: str,
        task_id: str,
        poll_seconds: float = MEMORY_POLL_SECONDS,
    ) -> None:
        self.docker = docker
        # Harbor trial/container names start with a (possibly truncated) task ID.
        # Filtering by a stable prefix prevents parallel tasks from claiming each
        # other's memory samples.
        self.container_name_hint = task_id.lower()[:20]
        self.poll_seconds = poll_seconds
        self.stop_event = threading.Event()
        self.thread: threading.Thread | None = None
        self.baseline_ids: set[str] = set()
        self.peak_memory_mib: float | None = None
        self.peak_memory_raw: str | None = None
        self.metric: str | None = None
        self.sampler_source: str | None = None
        self.error: str | None = None
        self._init_pids: dict[str, int] = {}
        self._procfs_unavailable: set[str] = set()

    def _docker_ids(self, all_containers: bool) -> list[str]:
        option = "-aq" if all_containers else "-q"
        result = subprocess.run(
            [self.docker, "ps", option],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        if result.returncode != 0:
            raise RuntimeError((result.stderr or result.stdout).strip())
        return [line.strip() for line in result.stdout.splitlines() if line.strip()]

    def start(self) -> None:
        try:
            self.baseline_ids = set(self._docker_ids(all_containers=True))
        except Exception as exc:
            self.error = f"baseline: {exc}"
        self.thread = threading.Thread(target=self._sample_loop, daemon=True)
        self.thread.start()

    def _running_task_containers(self) -> list[tuple[str, str]]:
        result = subprocess.run(
            [self.docker, "ps", "--format", "{{.ID}}\t{{.Names}}"],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
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

    def _container_rss_bytes(self, container_id: str) -> int | None:
        if container_id in self._procfs_unavailable:
            return self._docker_top_rss_bytes(container_id)
        pid = self._init_pids.get(container_id)
        if pid is None or not Path(f"/proc/{pid}").is_dir():
            result = subprocess.run(
                [self.docker, "inspect", "--format", "{{.State.Pid}}", container_id],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=False,
            )
            if result.returncode != 0:
                self._procfs_unavailable.add(container_id)
                return self._docker_top_rss_bytes(container_id)
            try:
                pid = int(result.stdout.strip())
            except ValueError:
                self._procfs_unavailable.add(container_id)
                return self._docker_top_rss_bytes(container_id)
            if pid <= 0 or not Path(f"/proc/{pid}").is_dir():
                self._procfs_unavailable.add(container_id)
                return self._docker_top_rss_bytes(container_id)
            self._init_pids[container_id] = pid
        value = process_tree_rss_bytes(pid)
        if value is not None:
            self.sampler_source = "host_procfs"
            return value
        self._procfs_unavailable.add(container_id)
        return self._docker_top_rss_bytes(container_id)

    def _docker_top_rss_bytes(self, container_id: str) -> int | None:
        result = subprocess.run(
            [self.docker, "top", container_id, "-eo", "rss="],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            encoding="utf-8",
            errors="replace",
            check=False,
        )
        if result.returncode != 0:
            return None
        value = parse_docker_top_rss_bytes(result.stdout)
        if value is not None:
            self.sampler_source = "docker_top"
        return value

    def _sample_once(self) -> None:
        containers = self._running_task_containers()
        if not containers:
            return
        rss_values = [
            self._container_rss_bytes(container_id)
            for container_id, _ in containers
        ]
        if self.metric in {None, "process_tree_rss"} and all(
            value is not None for value in rss_values
        ):
            total_mib = (
                sum(value for value in rss_values if value is not None)
                / 1024
                / 1024
            )
            self.metric = "process_tree_rss"
            raw = f"{total_mib:.3f} MiB"
        elif self.metric == "process_tree_rss":
            return
        else:
            result = subprocess.run(
                [
                    self.docker,
                    "stats",
                    "--no-stream",
                    "--format",
                    "{{.MemUsage}}",
                    *(container_id for container_id, _ in containers),
                ],
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
                text=True,
                encoding="utf-8",
                errors="replace",
                check=False,
            )
            if result.returncode != 0:
                raise RuntimeError((result.stderr or result.stdout).strip())
            parsed = [
                parse_memory_mib(line.split(" / ", 1)[0].strip())
                for line in result.stdout.splitlines()
            ]
            available = [value for value in parsed if value is not None]
            if not available:
                return
            total_mib = sum(available)
            self.metric = "docker_stats_memory"
            self.sampler_source = "docker_stats"
            self.poll_seconds = max(self.poll_seconds, 1.0)
            raw = f"{total_mib:.3f} MiB"
        if self.peak_memory_mib is None or total_mib > self.peak_memory_mib:
            self.peak_memory_mib = total_mib
            self.peak_memory_raw = raw

    def _sample_loop(self) -> None:
        while not self.stop_event.is_set():
            started = time.monotonic()
            try:
                self._sample_once()
            except Exception as exc:
                self.error = str(exc)
            elapsed = time.monotonic() - started
            self.stop_event.wait(max(0.0, self.poll_seconds - elapsed))

    def stop(self) -> None:
        try:
            self._sample_once()
        except Exception as exc:
            self.error = str(exc)
        self.stop_event.set()
        if self.thread is not None:
            self.thread.join(timeout=max(self.poll_seconds * 2, 2))

    def report(self) -> dict[str, Any]:
        return {
            "peak_memory_mib": self.peak_memory_mib,
            "peak_memory_raw": self.peak_memory_raw,
            "metric": self.metric or "unavailable",
            "sampler_source": self.sampler_source or "unavailable",
            "sample_interval_seconds": self.poll_seconds,
            "error": self.error,
            "container_name_hint": self.container_name_hint,
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
    mapping_root: Path,
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
        "schema_version": 7,
        "task_id": task_id,
        "condition": condition,
        "batch": batch_name,
        "repeat": repeat,
        "operation": operation,
        "tasks_root": str(tasks_root),
        "mapping_root": str(mapping_root),
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
        "harbor_results_dir": JOB_NAME,
        "danger_monitor": api.get("danger_monitor") if condition == "danger" else None,
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
        if condition == "standard":
            harbor_skill_paths = standard_skill_paths(task_id, mapping_root)
        elif condition == "high_cost":
            harbor_skill_paths = high_cost_skill_paths(task_id, mapping_root)
        elif condition == "danger":
            harbor_skill_paths = danger_skill_paths(task_id, mapping_root)
        elif condition == "selected":
            harbor_skill_paths = selected_skill_paths(task_id, mapping_root)
        elif condition == "no_skill":
            harbor_skill_paths = []
        else:
            raise ValueError(f"Unsupported condition: {condition}")
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
        if condition == "danger":
            danger_compose_path = write_danger_network_compose(run_dir, task_id)
            command.extend(
                [
                    "--ek",
                    "extra_docker_compose="
                    + json.dumps([str(danger_compose_path)], ensure_ascii=False),
                ]
            )
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
        monitor = DockerMemoryMonitor(docker, task_id)
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
    mapping_root: Path,
    operation: str = "run",
    before_run: Callable[[str, Path], None] | None = None,
) -> TaskExecutionResult:
    """Run every repetition for one task sequentially as one scheduling unit."""
    failures: list[str] = []
    setup_failures: list[str] = []
    monitor_stop_failures: list[str] = []
    task_api = dict(api)

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
        danger_monitor_started = False
        if condition == "danger":
            try:
                monitor_info = start_danger_monitor(
                    current_dir / task.task_id / DANGER_MONITOR_LOG_NAME
                )
            except Exception as exc:
                print(
                    f"[baseline][danger-monitor-error] task={task.task_id} "
                    f"{type(exc).__name__}: {exc}",
                    file=sys.stderr,
                )
                setup_failures.append(run_label)
                break
            danger_monitor_started = True
            task_api["danger_monitor"] = {
                "network": monitor_info["network"],
                "log_file": monitor_info["log_file"],
            }
            print(
                f"[baseline][danger-monitor] network={monitor_info['network']} "
                f"log={monitor_info['log_file']}"
            )

        try:
            exit_code = run_task(
                task.task_id,
                condition,
                harbor,
                docker,
                task_api,
                current_dir,
                tasks_root,
                mapping_root,
                operation=operation,
            )
            if exit_code != 0:
                failures.append(run_label)
        finally:
            if danger_monitor_started:
                try:
                    stop_output = stop_danger_monitor()
                    final_line = stop_output.splitlines()[-1] if stop_output else "stopped"
                    print(f"[baseline][danger-monitor] {final_line}")
                except Exception as exc:
                    monitor_stop_failures.append(run_label)
                    print(
                        f"[baseline][danger-monitor-stop-error] task={task.task_id} "
                        f"{type(exc).__name__}: {exc}",
                        file=sys.stderr,
                    )

    return TaskExecutionResult(failures, setup_failures, monitor_stop_failures)


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
        os.environ["BENCHMARK_CLEAN_IMAGE_SKILLS"] = "1"
    elif args.standard:
        condition = "standard"
    elif args.high_cost:
        condition = "high_cost"
    elif args.selected:
        condition = "selected"
    else:
        condition = "danger"
    try:
        tasks_root = args.tasks_root.expanduser().resolve()
        mapping_root = args.mapping_root.expanduser().resolve()
        tasks = resolve_tasks(args.task, tasks_root)
        harbor, docker, api = preflight(tasks, condition, tasks_root, mapping_root)
        light_tasks, heavy_tasks = build_execution_plan(
            tasks,
            tasks_root,
            args.max_parallel_cpus,
            args.max_parallel_memory_mib,
        )
        batch_dir = allocate_batch_dir(condition, mapping_root)
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
            f"run={batch_dir.name} tasks_root={tasks_root} mapping_root={mapping_root}"
        )
        effective_workers = 1 if condition == "danger" else args.task_workers
        print(
            f"[baseline] scheduler=resource-aware task_workers={effective_workers} "
            f"light_tasks={len(light_tasks)} heavy_tasks={len(heavy_tasks)} "
            f"budget={args.max_parallel_cpus}CPU/"
            f"{args.max_parallel_memory_mib}MiB"
        )
        if condition == "danger" and args.task_workers != 1:
            print(
                "[baseline] Danger tasks run serially because they share one "
                "sink network monitor"
            )
        if heavy_tasks:
            print(
                "[baseline] exclusive_order="
                + ",".join(task.task_id for task in heavy_tasks)
            )

        failures: list[str] = []
        interrupted = False
        setup_failures: list[str] = []
        monitor_stop_failures: list[str] = []
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
                mapping_root=mapping_root,
            )
            for execution_result in execution_results:
                failures.extend(execution_result.failures)
                setup_failures.extend(execution_result.setup_failures)
                monitor_stop_failures.extend(execution_result.monitor_stop_failures)
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
        if monitor_stop_failures and result_code == 0:
            result_code = 1
    except Exception as exc:
        print(
            f"[baseline][error] {type(exc).__name__}: {exc}",
            file=sys.stderr,
        )
        result_code = 1

    return result_code


if __name__ == "__main__":
    raise SystemExit(main())
