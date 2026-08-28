from __future__ import annotations

import argparse
import collections
import json
from pathlib import Path
from typing import Any

try:
    import tomllib
except ModuleNotFoundError:  # pragma: no cover
    import tomli as tomllib  # type: ignore

from runner import MissingEnvVarError, normalize_runtime_config


def flatten(value: Any, prefix: str = "") -> list[tuple[str, Any]]:
    if not isinstance(value, dict):
        return [(prefix, value)]
    items: list[tuple[str, Any]] = []
    for key, child in value.items():
        full_key = f"{prefix}.{key}" if prefix else str(key)
        if isinstance(child, dict):
            items.extend(flatten(child, full_key))
        else:
            items.append((full_key, child))
    return items


def inspect_tasks(tasks_dir: Path) -> dict[str, Any]:
    field_counts: collections.Counter[str] = collections.Counter()
    section_counts: collections.Counter[str] = collections.Counter()
    resource_values: dict[str, collections.Counter[str]] = collections.defaultdict(collections.Counter)
    workdirs: collections.Counter[str] = collections.Counter()
    solution_file_counts: collections.Counter[int] = collections.Counter()
    compose_tasks: list[str] = []
    parse_errors: list[dict[str, str]] = []
    runtime_errors: list[dict[str, str]] = []

    task_dirs = sorted(path for path in tasks_dir.iterdir() if path.is_dir())
    for task_dir in task_dirs:
        config_path = task_dir / "task.toml"
        try:
            with config_path.open("rb") as f:
                config = tomllib.load(f)
        except Exception as exc:
            parse_errors.append(
                {"task_id": task_dir.name, "error": f"{type(exc).__name__}: {exc}"}
            )
            continue

        for section, value in config.items():
            if isinstance(value, dict):
                section_counts[section] += 1
        for key, value in flatten(config):
            field_counts[key] += 1
            if key.startswith(("environment.", "agent.", "verifier.", "solution.")):
                if key.endswith(
                    (
                        "timeout_sec",
                        "build_timeout_sec",
                        "cpus",
                        "memory",
                        "memory_mb",
                        "storage",
                        "storage_mb",
                        "gpus",
                        "allow_internet",
                        "network_mode",
                        "workdir",
                        "os",
                    )
                ):
                    resource_values[key][repr(value)] += 1

        try:
            runtime = normalize_runtime_config(config)
            resource_values["normalized.memory_mb"][repr(runtime.memory_mb)] += 1
            resource_values["normalized.storage_mb"][repr(runtime.storage_mb)] += 1
            resource_values["normalized.network_mode"][repr(runtime.network_mode)] += 1
        except MissingEnvVarError as exc:
            runtime_errors.append(
                {"task_id": task_dir.name, "kind": "missing_env", "error": str(exc)}
            )
        except Exception as exc:
            runtime_errors.append(
                {
                    "task_id": task_dir.name,
                    "kind": "normalization_error",
                    "error": f"{type(exc).__name__}: {exc}",
                }
            )

        dockerfile = task_dir / "environment" / "Dockerfile"
        workdir = "<none>"
        if dockerfile.exists():
            for line in dockerfile.read_text(encoding="utf-8", errors="replace").splitlines():
                stripped = line.strip()
                if stripped.upper().startswith("WORKDIR "):
                    workdir = stripped.split(None, 1)[1]
        workdirs[workdir] += 1

        if (task_dir / "environment" / "docker-compose.yaml").exists():
            compose_tasks.append(task_dir.name)

        solution_files = [path for path in (task_dir / "solution").rglob("*") if path.is_file()]
        solution_file_counts[len(solution_files)] += 1

    return {
        "task_count": len(task_dirs),
        "parsed_count": len(task_dirs) - len(parse_errors),
        "parse_errors": parse_errors,
        "runtime_normalization_errors": runtime_errors,
        "sections": dict(section_counts.most_common()),
        "fields": dict(field_counts.most_common()),
        "resource_values": {
            key: dict(counter.most_common()) for key, counter in sorted(resource_values.items())
        },
        "dockerfile_workdirs": dict(workdirs.most_common()),
        "solution_file_count_distribution": {
            str(key): count for key, count in sorted(solution_file_counts.items())
        },
        "compose_tasks": compose_tasks,
    }


def main() -> int:
    parser = argparse.ArgumentParser(description="Inspect task.toml and bundle shape.")
    parser.add_argument(
        "--tasks-dir",
        type=Path,
        default=Path(__file__).resolve().parents[2] / "benchmark" / "datas" / "tasks",
    )
    parser.add_argument("--output", type=Path)
    args = parser.parse_args()

    report = inspect_tasks(args.tasks_dir)
    text = json.dumps(report, indent=2, ensure_ascii=False)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(text + "\n", encoding="utf-8")
    else:
        print(text)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
