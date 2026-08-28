from __future__ import annotations

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import threading
import time
import uuid
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib  # type: ignore


CONTAINER_SOLUTION_DIR = "/solution"
CONTAINER_TESTS_DIR = "/tests"
CONTAINER_LOGS_DIR = "/logs"

_OUTPUT_LOCAL = threading.local()
_STDOUT_LOCK = threading.Lock()
MEMORY_POLL_SECONDS = 0.05


def configure_stdio() -> None:
    for stream in (sys.stdout, sys.stderr):
        reconfigure = getattr(stream, "reconfigure", None)
        if reconfigure is None:
            continue
        try:
            reconfigure(errors="replace")
        except Exception:
            pass


def safe_write(text: str) -> None:
    target = getattr(_OUTPUT_LOCAL, "stream", None)
    if target is not None:
        target.write(text)
        target.flush()
        return

    try:
        with _STDOUT_LOCK:
            sys.stdout.write(text)
            sys.stdout.flush()
    except UnicodeEncodeError:
        encoding = sys.stdout.encoding or "utf-8"
        safe_text = text.encode(encoding, errors="replace").decode(encoding, errors="replace")
        with _STDOUT_LOCK:
            sys.stdout.write(safe_text)
            sys.stdout.flush()


def safe_print(*values: object, sep: str = " ", end: str = "\n") -> None:
    safe_write(sep.join(str(value) for value in values) + end)


def set_thread_output(stream: object) -> None:
    _OUTPUT_LOCAL.stream = stream


def clear_thread_output() -> None:
    _OUTPUT_LOCAL.stream = None


class RunnerError(Exception):
    pass


class MissingEnvVarError(RunnerError):
    pass


@dataclass
class RuntimeConfig:
    build_timeout_sec: float
    solve_timeout_sec: float | None
    verifier_timeout_sec: float
    cpus: int | None
    memory_mb: int | None
    storage_mb: int | None
    gpus: int
    network_mode: str
    environment_env: dict[str, str]
    solution_env: dict[str, str]
    verifier_env: dict[str, str]
    workdir: str | None
    os: str


@dataclass
class CommandResult:
    return_code: int
    elapsed_sec: float


@dataclass
class RunResult:
    task_id: str
    status: str
    reward: float | dict[str, Any] | None
    passed: bool
    build: CommandResult | None = None
    solve: CommandResult | None = None
    test: CommandResult | None = None
    solve_memory_peak_bytes: int | None = None
    test_memory_peak_bytes: int | None = None
    memory_metric: str | None = None
    memory_sampler_source: str | None = None
    memory_sample_interval_seconds: float | None = None
    error: str | None = None


def load_toml(path: Path) -> dict[str, Any]:
    with path.open("rb") as f:
        return tomllib.load(f)


def parse_size_to_mb(value: Any) -> int | None:
    if value is None:
        return None
    if isinstance(value, int):
        return value
    if isinstance(value, float):
        return int(value)
    if not isinstance(value, str):
        raise ValueError(f"Unsupported size value: {value!r}")

    text = value.strip().upper()
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)([GMK]?)B?", text)
    if not match:
        raise ValueError(f"Invalid size format: {value!r}")
    number = float(match.group(1))
    unit = match.group(2)
    if unit == "G":
        return int(number * 1024)
    if unit == "K":
        return int(number / 1024)
    return int(number)


def resolve_env_value(value: str) -> str:
    pattern = re.compile(r"\$\{([^}:]+)(?::-([^}]*))?\}")

    def repl(match: re.Match[str]) -> str:
        name = match.group(1)
        default = match.group(2)
        current = os.environ.get(name)
        if current is not None:
            return current
        if default is not None:
            return default
        raise MissingEnvVarError(f"Required environment variable is missing: {name}")

    return pattern.sub(repl, str(value))


def resolve_env_map(values: dict[str, Any]) -> dict[str, str]:
    return {str(key): resolve_env_value(str(value)) for key, value in values.items()}


def normalize_runtime_config(raw: dict[str, Any]) -> RuntimeConfig:
    env_cfg = dict(raw.get("environment") or {})
    agent_cfg = dict(raw.get("agent") or {})
    verifier_cfg = dict(raw.get("verifier") or {})
    solution_cfg = dict(raw.get("solution") or {})

    memory_mb = env_cfg.get("memory_mb")
    if memory_mb is None and "memory" in env_cfg:
        memory_mb = parse_size_to_mb(env_cfg["memory"])

    storage_mb = env_cfg.get("storage_mb")
    if storage_mb is None and "storage" in env_cfg:
        storage_mb = parse_size_to_mb(env_cfg["storage"])

    network_mode = str(env_cfg.get("network_mode") or "").strip()
    if not network_mode:
        allow_internet = env_cfg.get("allow_internet")
        network_mode = "public" if allow_internet is not False else "no-network"

    solve_timeout = solution_cfg.get("timeout_sec", agent_cfg.get("timeout_sec"))

    return RuntimeConfig(
        build_timeout_sec=float(env_cfg.get("build_timeout_sec", 600.0)),
        solve_timeout_sec=float(solve_timeout) if solve_timeout is not None else None,
        verifier_timeout_sec=float(verifier_cfg.get("timeout_sec", 600.0)),
        cpus=int(env_cfg["cpus"]) if env_cfg.get("cpus") is not None else None,
        memory_mb=int(memory_mb) if memory_mb is not None else None,
        storage_mb=int(storage_mb) if storage_mb is not None else None,
        gpus=int(env_cfg.get("gpus") or 0),
        network_mode=network_mode,
        environment_env=resolve_env_map(dict(env_cfg.get("env") or {})),
        solution_env=resolve_env_map(dict(solution_cfg.get("env") or {})),
        verifier_env=resolve_env_map(dict(verifier_cfg.get("env") or {})),
        workdir=env_cfg.get("workdir"),
        os=str(env_cfg.get("os") or "linux").lower(),
    )


def safe_slug(value: str) -> str:
    slug = re.sub(r"[^a-zA-Z0-9_.-]+", "-", value).strip("-").lower()
    return slug or "task"


def docker_path(path: Path) -> str:
    return str(path.resolve())


def print_section(title: str) -> None:
    safe_print()
    safe_print(f"========== {title} ==========")


def run_streamed(args: list[str], *, timeout: float | None) -> CommandResult:
    start = time.monotonic()
    process = subprocess.Popen(
        args,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True,
        encoding="utf-8",
        errors="replace",
        bufsize=1,
    )
    reader_errors: list[BaseException] = []
    output_target = getattr(_OUTPUT_LOCAL, "stream", None)

    def stream_output() -> None:
        if output_target is not None:
            set_thread_output(output_target)
        try:
            assert process.stdout is not None
            for line in process.stdout:
                safe_write(line)
        except BaseException as exc:
            reader_errors.append(exc)
        finally:
            if output_target is not None:
                clear_thread_output()

    reader = threading.Thread(target=stream_output, daemon=True)
    reader.start()
    try:
        return_code = process.wait(timeout=timeout)
    except subprocess.TimeoutExpired:
        process.kill()
        process.wait(timeout=10)
        raise
    finally:
        reader.join(timeout=5)
        if reader.is_alive() and process.stdout is not None:
            process.stdout.close()
            reader.join(timeout=1)
    if reader_errors:
        raise reader_errors[0]
    return CommandResult(return_code=return_code, elapsed_sec=time.monotonic() - start)


def run_capture(args: list[str], *, timeout: float | None = None) -> subprocess.CompletedProcess[str]:
    return subprocess.run(
        args,
        stdout=subprocess.PIPE,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        timeout=timeout,
    )


def parse_docker_memory_value(value: str) -> int | None:
    text = value.strip().split("/", 1)[0].strip()
    match = re.fullmatch(r"([0-9]+(?:\.[0-9]+)?)\s*([KMGT]?i?B|B)", text, re.IGNORECASE)
    if not match:
        return None
    number = float(match.group(1))
    unit = match.group(2).lower()
    multipliers = {
        "b": 1,
        "kb": 1000,
        "kib": 1024,
        "mb": 1000**2,
        "mib": 1024**2,
        "gb": 1000**3,
        "gib": 1024**3,
        "tb": 1000**4,
        "tib": 1024**4,
    }
    multiplier = multipliers.get(unit)
    if multiplier is None:
        return None
    return int(number * multiplier)


_CGROUP_MEMORY_FILE_CACHE: dict[str, Path | None] = {}
_CGROUP_MEMORY_FILE_CACHE_LOCK = threading.Lock()
_CONTAINER_INIT_PID_CACHE: dict[str, int] = {}
_CONTAINER_INIT_PID_CACHE_LOCK = threading.Lock()


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
            children = (proc_root / str(pid) / "task" / str(pid) / "children")
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


def container_process_tree_rss_bytes(container_name: str) -> int | None:
    with _CONTAINER_INIT_PID_CACHE_LOCK:
        pid = _CONTAINER_INIT_PID_CACHE.get(container_name)
    if pid is None or not Path(f"/proc/{pid}").is_dir():
        try:
            result = run_capture(
                ["docker", "inspect", "--format", "{{.State.Pid}}", container_name],
                timeout=5,
            )
            if result.returncode != 0:
                return None
            pid = int(result.stdout.strip())
        except (OSError, ValueError, subprocess.SubprocessError):
            return None
        if pid <= 0 or not Path(f"/proc/{pid}").is_dir():
            return None
        with _CONTAINER_INIT_PID_CACHE_LOCK:
            _CONTAINER_INIT_PID_CACHE[container_name] = pid
    return process_tree_rss_bytes(pid)


def parse_docker_top_rss_bytes(output: str) -> int | None:
    rss_kib: list[int] = []
    for line in output.splitlines():
        try:
            rss_kib.append(int(line.strip()))
        except ValueError:
            continue
    return sum(rss_kib) * 1024 if rss_kib else None


def docker_top_process_rss_bytes(container_name: str) -> int | None:
    try:
        result = run_capture(
            ["docker", "top", container_name, "-eo", "rss="],
            timeout=5,
        )
    except (OSError, subprocess.SubprocessError):
        return None
    if result.returncode != 0:
        return None
    return parse_docker_top_rss_bytes(result.stdout)


def find_container_cgroup_memory_file(container_name: str) -> Path | None:
    """Find the container's cgroup current-memory counter on the Docker host."""
    with _CGROUP_MEMORY_FILE_CACHE_LOCK:
        if container_name in _CGROUP_MEMORY_FILE_CACHE:
            return _CGROUP_MEMORY_FILE_CACHE[container_name]

    memory_file: Path | None = None
    try:
        result = run_capture(
            ["docker", "inspect", "--format", "{{.State.Pid}}", container_name],
            timeout=5,
        )
        if result.returncode == 0:
            pid = int(result.stdout.strip())
            cgroup_lines = Path(f"/proc/{pid}/cgroup").read_text(
                encoding="utf-8"
            ).splitlines()

            unified_path: str | None = None
            memory_path: str | None = None
            for line in cgroup_lines:
                parts = line.split(":", 2)
                if len(parts) != 3:
                    continue
                _, controllers, cgroup_path = parts
                if controllers == "":
                    unified_path = cgroup_path
                elif "memory" in controllers.split(","):
                    memory_path = cgroup_path

            try:
                private_cgroup_namespace = os.readlink(
                    f"/proc/{pid}/ns/cgroup"
                ) != os.readlink("/proc/self/ns/cgroup")
            except OSError:
                private_cgroup_namespace = False

            candidates: list[Path] = []
            if unified_path is not None:
                candidates.append(
                    Path("/sys/fs/cgroup")
                    / unified_path.lstrip("/")
                    / "memory.current"
                )
                if private_cgroup_namespace:
                    candidates.append(
                        Path(f"/proc/{pid}/root/sys/fs/cgroup/memory.current")
                    )
            if memory_path is not None:
                candidates.append(
                    Path("/sys/fs/cgroup/memory")
                    / memory_path.lstrip("/")
                    / "memory.usage_in_bytes"
                )
                if private_cgroup_namespace:
                    candidates.extend(
                        [
                            Path(
                                f"/proc/{pid}/root/sys/fs/cgroup/memory/"
                                "memory.usage_in_bytes"
                            ),
                            Path(
                                f"/proc/{pid}/root/sys/fs/cgroup/"
                                "memory.usage_in_bytes"
                            ),
                        ]
                    )

            memory_file = next((path for path in candidates if path.is_file()), None)
    except (OSError, ValueError, subprocess.SubprocessError):
        memory_file = None

    with _CGROUP_MEMORY_FILE_CACHE_LOCK:
        _CGROUP_MEMORY_FILE_CACHE[container_name] = memory_file
    return memory_file


def find_container_cgroup_memory_peak_file(container_name: str) -> Path | None:
    """Return cgroup v2's kernel-maintained peak counter when available."""
    current_file = find_container_cgroup_memory_file(container_name)
    if current_file is None or current_file.name != "memory.current":
        return None
    peak_file = current_file.with_name("memory.peak")
    return peak_file if peak_file.is_file() else None


def cgroup_container_memory_bytes(container_name: str) -> int | None:
    memory_file = find_container_cgroup_memory_file(container_name)
    if memory_file is None:
        return None
    try:
        value = int(memory_file.read_text(encoding="ascii").strip())
    except (OSError, ValueError):
        return None
    return value if value >= 0 else None


def docker_container_memory_bytes(container_name: str) -> int | None:
    # Direct cgroup reads are cheap enough for sub-second sampling. Keep the
    # existing docker-stats implementation as a compatibility fallback.
    current = cgroup_container_memory_bytes(container_name)
    if current is not None:
        return current

    try:
        result = run_capture(
            ["docker", "stats", "--no-stream", "--format", "{{.MemUsage}}", container_name],
            timeout=10,
        )
    except Exception:
        return None
    if result.returncode != 0:
        return None
    line = result.stdout.strip().splitlines()
    if not line:
        return None
    return parse_docker_memory_value(line[0])


class ContainerMemoryMonitor:
    def __init__(
        self,
        container_name: str,
        interval_sec: float = MEMORY_POLL_SECONDS,
    ) -> None:
        self.container_name = container_name
        self.interval_sec = interval_sec
        self.peak_bytes: int | None = None
        self.metric = "unavailable"
        self.sampler_source = "unavailable"
        self._lock = threading.Lock()
        self._kernel_peak_lock = threading.Lock()
        self._kernel_peak_fd: int | None = None
        self._stop_event = threading.Event()
        self._thread = threading.Thread(target=self._run, daemon=True)
        self._started = False

    def start(self) -> None:
        if self._started:
            return
        if container_process_tree_rss_bytes(self.container_name) is not None:
            self.metric = "process_tree_rss"
            self.sampler_source = "host_procfs"
        elif docker_top_process_rss_bytes(self.container_name) is not None:
            self.metric = "process_tree_rss"
            self.sampler_source = "docker_top"
        else:
            self.metric = "cgroup_memory"
            self.sampler_source = "cgroup"
            self._open_kernel_peak()
        if self.metric == "cgroup_memory" and (
            self._kernel_peak_fd is None
            and find_container_cgroup_memory_file(self.container_name) is None
        ):
            self.metric = "docker_stats_memory"
            self.sampler_source = "docker_stats"
            self.interval_sec = max(self.interval_sec, 1.0)
        self._sample_once()
        self._thread.start()
        self._started = True

    def stop(self) -> None:
        self._sample_once()
        self._stop_event.set()
        if self._started:
            self._thread.join(timeout=2)
        self._close_kernel_peak()

    def reset_peak(self) -> None:
        with self._lock:
            self.peak_bytes = None
        if self.metric == "cgroup_memory" and self._reset_kernel_peak():
            self._sample_once()
            return
        self._sample_once()

    def snapshot_peak(self) -> int | None:
        self._sample_once()
        with self._lock:
            return self.peak_bytes

    def _open_kernel_peak(self) -> None:
        peak_file = find_container_cgroup_memory_peak_file(self.container_name)
        if peak_file is None:
            return
        try:
            fd = os.open(
                peak_file,
                os.O_RDWR | getattr(os, "O_CLOEXEC", 0),
            )
        except OSError:
            return
        with self._kernel_peak_lock:
            self._kernel_peak_fd = fd
        if not self._reset_kernel_peak():
            self._close_kernel_peak()

    def _close_kernel_peak(self) -> None:
        with self._kernel_peak_lock:
            fd = self._kernel_peak_fd
            self._kernel_peak_fd = None
            if fd is not None:
                try:
                    os.close(fd)
                except OSError:
                    pass

    def _reset_kernel_peak(self) -> bool:
        # cgroup v2 resets memory.peak for subsequent reads through this same FD.
        with self._kernel_peak_lock:
            fd = self._kernel_peak_fd
            if fd is None:
                return False
            try:
                os.lseek(fd, 0, os.SEEK_SET)
                os.write(fd, b"0")
                os.lseek(fd, 0, os.SEEK_SET)
            except OSError:
                try:
                    os.close(fd)
                except OSError:
                    pass
                self._kernel_peak_fd = None
                return False
        return True

    def _read_kernel_peak(self) -> int | None:
        with self._kernel_peak_lock:
            fd = self._kernel_peak_fd
            if fd is None:
                return None
            try:
                os.lseek(fd, 0, os.SEEK_SET)
                data = os.read(fd, 64)
            except OSError:
                try:
                    os.close(fd)
                except OSError:
                    pass
                self._kernel_peak_fd = None
                return None
        try:
            value = int(data.strip())
        except ValueError:
            return None
        return value if value >= 0 else None

    def _sample_once(self) -> None:
        if self.sampler_source == "host_procfs":
            current = container_process_tree_rss_bytes(self.container_name)
        elif self.sampler_source == "docker_top":
            current = docker_top_process_rss_bytes(self.container_name)
        else:
            current = None
        if current is None and self.metric != "process_tree_rss":
            current = self._read_kernel_peak()
        if current is None and self.metric != "process_tree_rss":
            current = docker_container_memory_bytes(self.container_name)
        if current is None:
            return
        with self._lock:
            if self.peak_bytes is None or current > self.peak_bytes:
                self.peak_bytes = current

    def _run(self) -> None:
        while not self._stop_event.wait(self.interval_sec):
            self._sample_once()


TEXT_FILE_SUFFIXES = {
    ".bash",
    ".cfg",
    ".conf",
    ".csv",
    ".dockerfile",
    ".env",
    ".ini",
    ".json",
    ".lean",
    ".md",
    ".py",
    ".pyi",
    ".sh",
    ".toml",
    ".tsv",
    ".txt",
    ".yaml",
    ".yml",
}
TEXT_FILE_NAMES = {
    ".dockerignore",
    "Containerfile",
    "Dockerfile",
    "Makefile",
    "dockerfile",
    "lean-toolchain",
    "makefile",
}
MAX_TEXT_NORMALIZE_BYTES = 5 * 1024 * 1024


def normalize_file_line_endings(path: Path) -> None:
    data = path.read_bytes()
    normalized = data.replace(b"\r\n", b"\n")
    if normalized != data:
        path.write_bytes(normalized)


def is_safe_text_file(path: Path) -> bool:
    if path.name in TEXT_FILE_NAMES or path.suffix.lower() in TEXT_FILE_SUFFIXES:
        return True
    if path.suffix:
        return False
    try:
        data = path.read_bytes()
    except OSError:
        return False
    if len(data) > MAX_TEXT_NORMALIZE_BYTES or b"\0" in data:
        return False
    try:
        data.decode("utf-8")
    except UnicodeDecodeError:
        return False
    return True


def normalize_text_files(root: Path) -> None:
    for path in root.rglob("*"):
        if path.is_file() and is_safe_text_file(path):
            normalize_file_line_endings(path)


def normalize_shell_scripts(root: Path) -> None:
    for script in root.rglob("*.sh"):
        normalize_file_line_endings(script)


def validate_task_dir(task_dir: Path) -> None:
    required = [
        task_dir / "task.toml",
        task_dir / "environment" / "Dockerfile",
        task_dir / "solution" / "solve.sh",
        task_dir / "tests" / "test.sh",
    ]
    missing = [str(path) for path in required if not path.exists()]
    if missing:
        raise RunnerError(f"Task bundle is incomplete. Missing: {missing}")
    if (task_dir / "environment" / "docker-compose.yaml").exists():
        raise RunnerError("This lightweight runner only supports environment/Dockerfile, not docker-compose.yaml.")


def build_image(environment_dir: Path, image_tag: str, runtime: RuntimeConfig) -> CommandResult:
    dockerfile = environment_dir / "Dockerfile"
    return run_streamed(
        [
            "docker",
            "build",
            "-t",
            image_tag,
            "-f",
            docker_path(dockerfile),
            docker_path(environment_dir),
        ],
        timeout=runtime.build_timeout_sec,
    )


def cached_image_repository(task_id: str) -> str:
    return f"benchmark-cache/{safe_slug(task_id)}-gold"


def find_cached_image(task_id: str) -> str | None:
    repository = cached_image_repository(task_id)
    result = run_capture(
        [
            "docker",
            "image",
            "ls",
            "--format",
            "{{.Repository}}:{{.Tag}}",
            "--filter",
            f"reference={repository}:*",
        ],
        timeout=30,
    )
    if result.returncode != 0:
        raise RunnerError(f"docker image lookup failed:\n{result.stderr.strip()}")

    for image_ref in result.stdout.splitlines():
        image_ref = image_ref.strip()
        if image_ref and image_ref != f"{repository}:<none>":
            return image_ref
    return None


def create_container(
    solution_dir: Path,
    tests_dir: Path,
    image_tag: str,
    container_name: str,
    runtime: RuntimeConfig,
    logs_dir: Path,
) -> None:
    for subdir in ("agent", "verifier", "artifacts"):
        (logs_dir / subdir).mkdir(parents=True, exist_ok=True)

    args = [
        "docker",
        "create",
        "--name",
        container_name,
        "--entrypoint",
        "sh",
        "-v",
        f"{docker_path(solution_dir)}:{CONTAINER_SOLUTION_DIR}",
        "-v",
        f"{docker_path(tests_dir)}:{CONTAINER_TESTS_DIR}",
        "-v",
        f"{docker_path(logs_dir)}:{CONTAINER_LOGS_DIR}",
    ]
    if runtime.cpus is not None:
        args.extend(["--cpus", str(runtime.cpus)])
    if runtime.memory_mb is not None:
        args.extend(["--memory", f"{runtime.memory_mb}m"])
    if runtime.gpus > 0:
        args.extend(["--gpus", "all"])
    if runtime.network_mode == "no-network":
        args.extend(["--network", "none"])
    if runtime.workdir:
        args.extend(["--workdir", runtime.workdir])
    for key, value in runtime.environment_env.items():
        args.extend(["--env", f"{key}={value}"])
    args.extend([image_tag, "-c", "sleep infinity"])

    result = run_capture(args)
    if result.returncode != 0:
        raise RunnerError(f"docker create failed:\n{result.stderr.strip()}")


def docker_start(container_name: str) -> None:
    result = run_capture(["docker", "start", container_name])
    if result.returncode != 0:
        raise RunnerError(f"docker start failed:\n{result.stderr.strip()}")


def docker_rm(container_name: str) -> None:
    run_capture(["docker", "rm", "-f", container_name], timeout=30)


def docker_exec_script(
    container_name: str,
    script_path: str,
    env: dict[str, str],
    timeout: float | None,
) -> CommandResult:
    chmod = run_capture(["docker", "exec", "-u", "root", container_name, "chmod", "+x", script_path])
    if chmod.returncode != 0:
        raise RunnerError(f"chmod failed for {script_path}:\n{chmod.stderr.strip()}")

    args = ["docker", "exec"]
    for key, value in env.items():
        args.extend(["--env", f"{key}={value}"])
    command = f"if command -v bash >/dev/null 2>&1; then exec bash {script_path}; else exec sh {script_path}; fi"
    args.extend([container_name, "sh", "-lc", command])
    return run_streamed(args, timeout=timeout)


def read_reward(logs_dir: Path) -> float | dict[str, Any] | None:
    verifier_dir = logs_dir / "verifier"
    reward_json = verifier_dir / "reward.json"
    reward_text = verifier_dir / "reward.txt"
    if reward_json.exists() and reward_json.stat().st_size > 0:
        return json.loads(reward_json.read_text(encoding="utf-8"))
    if reward_text.exists() and reward_text.stat().st_size > 0:
        return float(reward_text.read_text(encoding="utf-8").strip())
    return None


def reward_passed(reward: float | dict[str, Any] | None) -> bool:
    if isinstance(reward, dict):
        value = reward.get("reward")
        return isinstance(value, (int, float)) and float(value) >= 1.0
    return isinstance(reward, (int, float)) and float(reward) >= 1.0


def clear_reward_files(logs_dir: Path) -> None:
    verifier_dir = logs_dir / "verifier"
    for filename in ("reward.json", "reward.txt"):
        path = verifier_dir / filename
        try:
            path.unlink()
        except FileNotFoundError:
            pass


def run_task_repeated(
    task_dir: Path,
    repeat: int,
    before_run: Callable[[int], None] | None = None,
    after_run: Callable[[int, RunResult], None] | None = None,
) -> list[RunResult]:
    if repeat < 1:
        raise ValueError("repeat must be >= 1")

    task_dir = task_dir.resolve()
    task_id = task_dir.name
    validate_task_dir(task_dir)

    runtime = normalize_runtime_config(load_toml(task_dir / "task.toml"))
    if runtime.os != "linux":
        raise RunnerError(f"Only linux containers are supported, got {runtime.os!r}.")

    run_id = f"{time.time_ns()}-{uuid.uuid4().hex[:8]}"
    image_tag = find_cached_image(task_id)
    image_was_cached = image_tag is not None
    if image_tag is None:
        image_tag = f"{cached_image_repository(task_id)}:local"
    container_name = f"test-solution-{safe_slug(task_id)}-{run_id}"
    build_result: CommandResult | None = None
    memory_monitor: ContainerMemoryMonitor | None = None
    results: list[RunResult] = []

    with tempfile.TemporaryDirectory(prefix=f"test-solution-{safe_slug(task_id)}-") as tmp:
        tmp_dir = Path(tmp)
        environment_dir = tmp_dir / "environment"
        solution_dir = tmp_dir / "solution"
        tests_dir = tmp_dir / "tests"
        shutil.copytree(task_dir / "environment", environment_dir)
        shutil.copytree(task_dir / "solution", solution_dir)
        shutil.copytree(task_dir / "tests", tests_dir)
        normalize_text_files(environment_dir)
        normalize_shell_scripts(solution_dir)
        normalize_shell_scripts(tests_dir)
        logs_dir = Path(tmp) / "logs"
        try:
            if image_was_cached:
                print_section("Reuse Image")
                safe_print(f"Using cached image: {image_tag}")
            else:
                print_section("Build Image")
                safe_print(f"No cached gold image found; building and retaining: {image_tag}")
                build_result = build_image(environment_dir, image_tag, runtime)
                if build_result.return_code != 0:
                    return [
                        RunResult(
                            task_id=task_id,
                            status="build_failed",
                            reward=None,
                            passed=False,
                            build=build_result,
                        )
                        for _ in range(repeat)
                    ]

            create_container(solution_dir, tests_dir, image_tag, container_name, runtime, logs_dir)
            docker_start(container_name)
            memory_monitor = ContainerMemoryMonitor(container_name)
            memory_monitor.start()
            safe_print(
                "Memory monitor: "
                f"metric={memory_monitor.metric}, "
                f"source={memory_monitor.sampler_source}, "
                f"interval={memory_monitor.interval_sec:.3f}s"
            )

            for run_index in range(repeat):
                if before_run is not None:
                    before_run(run_index)
                print_section(f"Repeated Run {run_index + 1}/{repeat}")
                clear_reward_files(logs_dir)

                solve_result: CommandResult | None = None
                test_result: CommandResult | None = None
                solve_memory_peak_bytes: int | None = None
                test_memory_peak_bytes: int | None = None
                try:
                    print_section("Run solve.sh")
                    memory_monitor.reset_peak()
                    solve_env = {
                        "DEBIAN_FRONTEND": "noninteractive",
                        **runtime.environment_env,
                        **runtime.solution_env,
                    }
                    solve_result = docker_exec_script(
                        container_name,
                        f"{CONTAINER_SOLUTION_DIR}/solve.sh",
                        solve_env,
                        runtime.solve_timeout_sec,
                    )
                    solve_memory_peak_bytes = memory_monitor.snapshot_peak()

                    print_section("Run test.sh")
                    memory_monitor.reset_peak()
                    test_env = {
                        **runtime.environment_env,
                        **runtime.verifier_env,
                    }
                    test_result = docker_exec_script(
                        container_name,
                        f"{CONTAINER_TESTS_DIR}/test.sh",
                        test_env,
                        runtime.verifier_timeout_sec,
                    )
                    test_memory_peak_bytes = memory_monitor.snapshot_peak()
                    reward = read_reward(logs_dir)
                    passed = reward_passed(reward)
                    result = RunResult(
                        task_id=task_id,
                        status="passed" if passed else "failed",
                        reward=reward,
                        passed=passed,
                        build=build_result,
                        solve=solve_result,
                        test=test_result,
                        solve_memory_peak_bytes=solve_memory_peak_bytes,
                        test_memory_peak_bytes=test_memory_peak_bytes,
                        memory_metric=memory_monitor.metric,
                        memory_sampler_source=memory_monitor.sampler_source,
                        memory_sample_interval_seconds=memory_monitor.interval_sec,
                    )
                except subprocess.TimeoutExpired as exc:
                    result = RunResult(
                        task_id=task_id,
                        status="timeout",
                        reward=None,
                        passed=False,
                        build=build_result,
                        solve=solve_result,
                        test=test_result,
                        solve_memory_peak_bytes=solve_memory_peak_bytes,
                        test_memory_peak_bytes=test_memory_peak_bytes,
                        memory_metric=memory_monitor.metric,
                        memory_sampler_source=memory_monitor.sampler_source,
                        memory_sample_interval_seconds=memory_monitor.interval_sec,
                        error=str(exc),
                    )
                except Exception as exc:
                    result = RunResult(
                        task_id=task_id,
                        status="error",
                        reward=None,
                        passed=False,
                        build=build_result,
                        solve=solve_result,
                        test=test_result,
                        solve_memory_peak_bytes=solve_memory_peak_bytes,
                        test_memory_peak_bytes=test_memory_peak_bytes,
                        memory_metric=memory_monitor.metric,
                        memory_sampler_source=memory_monitor.sampler_source,
                        memory_sample_interval_seconds=memory_monitor.interval_sec,
                        error=f"{type(exc).__name__}: {exc}",
                    )
                results.append(result)
                if after_run is not None:
                    after_run(run_index, result)
                if result.status in {"timeout", "error"}:
                    break
        finally:
            if memory_monitor is not None:
                memory_monitor.stop()
            print_section("Cleanup")
            safe_print(f"Removing container: {container_name}")
            docker_rm(container_name)
    while len(results) < repeat:
        results.append(
            RunResult(
                task_id=task_id,
                status="skipped",
                reward=None,
                passed=False,
                build=build_result,
                error="Skipped because an earlier run made the shared container unusable.",
            )
        )
    return results


def run_task(task_dir: Path) -> RunResult:
    return run_task_repeated(task_dir, repeat=1)[0]


def format_elapsed(result: CommandResult | None) -> str:
    if result is None:
        return "n/a"
    return f"{result.elapsed_sec:.1f}s (exit {result.return_code})"


def format_memory(value: int | None) -> str:
    if value is None:
        return "n/a"
    units = ["B", "KiB", "MiB", "GiB", "TiB"]
    amount = float(value)
    for unit in units:
        if amount < 1024 or unit == units[-1]:
            if unit == "B":
                return f"{int(amount)} {unit}"
            return f"{amount:.1f} {unit}"
        amount /= 1024
    return f"{value} B"


def print_final_result(result: RunResult) -> None:
    print_section("Result")
    safe_print(f"Task: {result.task_id}")
    safe_print(f"Status: {result.status}")
    safe_print(f"Passed: {result.passed}")
    safe_print(f"Reward: {result.reward}")
    safe_print(f"Build: {format_elapsed(result.build)}")
    safe_print(f"Solve: {format_elapsed(result.solve)}")
    safe_print(f"Test: {format_elapsed(result.test)}")
    safe_print(f"Solve Memory Peak: {format_memory(result.solve_memory_peak_bytes)}")
    safe_print(f"Test Memory Peak: {format_memory(result.test_memory_peak_bytes)}")
    safe_print(f"Memory Metric: {result.memory_metric or 'unavailable'}")
    safe_print(
        f"Memory Sampler Source: {result.memory_sampler_source or 'unavailable'}"
    )
    if result.memory_sample_interval_seconds is not None:
        safe_print(
            "Memory Sample Interval: "
            f"{result.memory_sample_interval_seconds:.3f} s"
        )
    if result.error:
        safe_print(f"Error: {result.error}")


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Reuse a task's cached gold image when available, run solution/solve.sh and tests/test.sh, then remove only the container."
    )
    parser.add_argument("task_dir", type=Path, help="Path to a single task bundle directory.")
    return parser


def main() -> int:
    configure_stdio()
    args = build_parser().parse_args()
    try:
        result = run_task(args.task_dir)
    except subprocess.TimeoutExpired as exc:
        result = RunResult(
            task_id=args.task_dir.name,
            status="timeout",
            reward=None,
            passed=False,
            error=str(exc),
        )
    except Exception as exc:
        result = RunResult(
            task_id=args.task_dir.name,
            status="error",
            reward=None,
            passed=False,
            error=str(exc),
        )
    print_final_result(result)
    return 0 if result.passed else 1


if __name__ == "__main__":
    raise SystemExit(main())
