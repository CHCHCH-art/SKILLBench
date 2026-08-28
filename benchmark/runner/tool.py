from __future__ import annotations

import json
import os
import posixpath
import re
from pathlib import Path, PurePosixPath
from typing import Any, Iterator


TASK_SKILLS_PREFIX = PurePosixPath("/root/.agents/skills")


def filesystem_path(path: Path) -> Path:
    """Use Windows extended-length paths when reading deep Harbor artifacts."""
    if os.name != "nt":
        return path
    absolute = Path(os.path.abspath(path))
    value = str(absolute)
    if value.startswith("\\\\?\\"):
        return absolute
    if value.startswith("\\\\"):
        return Path("\\\\?\\UNC\\" + value[2:])
    return Path("\\\\?\\" + value)


def read_json(path: Path) -> dict[str, Any] | None:
    readable_path = filesystem_path(path)
    if not readable_path.is_file():
        return None
    payload = json.loads(readable_path.read_text(encoding="utf-8-sig"))
    if not isinstance(payload, dict):
        raise ValueError(f"Expected a JSON object in {path}")
    return payload


def iter_strings(value: Any) -> Iterator[str]:
    if isinstance(value, str):
        yield value
    elif isinstance(value, dict):
        for item in value.values():
            yield from iter_strings(item)
    elif isinstance(value, list):
        for item in value:
            yield from iter_strings(item)


def _available_skills_block(trajectory: dict[str, Any]) -> str | None:
    steps = trajectory.get("steps")
    steps = steps if isinstance(steps, list) else []
    for step in steps:
        if not isinstance(step, dict) or step.get("source") != "system":
            continue
        message = step.get("message")
        if (
            isinstance(message, str)
            and "### Available skills" in message
            and "<skills_instructions>" in message
        ):
            return message
    return None


def available_task_skills(trajectory: dict[str, Any]) -> dict[str, str]:
    """Return task Skill directory names and SKILL.md paths advertised to the Agent."""
    block = _available_skills_block(trajectory)
    if block is None:
        raise ValueError("Available skills block not found")
    return task_skills_from_text(block)


def task_skills_from_text(block: str) -> dict[str, str]:
    """Extract task Skills from a Codex available-skills instruction block."""

    skills: dict[str, str] = {}
    for raw_line in block.splitlines():
        line = raw_line.strip()
        if not line.startswith("- ") or "(file: " not in line:
            continue
        path_match = re.search(r"\(file: ([^)]+)\)\s*$", line)
        if path_match is None:
            continue
        raw_path = path_match.group(1).strip()
        normalized = PurePosixPath(raw_path.replace("\\", "/"))
        try:
            relative = normalized.relative_to(TASK_SKILLS_PREFIX)
        except ValueError:
            # System and plugin Skills are intentionally outside benchmark scope.
            continue
        if len(relative.parts) >= 2 and relative.parts[-1] == "SKILL.md":
            skills[relative.parts[0]] = raw_path
    return skills


def _tool_calls(trajectory: dict[str, Any]) -> Iterator[tuple[dict[str, Any], dict[str, Any]]]:
    steps = trajectory.get("steps")
    steps = steps if isinstance(steps, list) else []
    for step in steps:
        if not isinstance(step, dict) or step.get("source") != "agent":
            continue
        calls = step.get("tool_calls")
        calls = calls if isinstance(calls, list) else []
        for call in calls:
            if isinstance(call, dict):
                yield step, call


def loaded_task_skills(
    trajectory: dict[str, Any],
    skill_paths: dict[str, str],
) -> tuple[set[str], dict[str, list[dict[str, Any]]]]:
    """Detect explicit Agent tool-call references to task SKILL.md files."""
    loaded: set[str] = set()
    evidence: dict[str, list[dict[str, Any]]] = {}
    for step, call in _tool_calls(trajectory):
        arguments = call.get("arguments")
        arguments = arguments if isinstance(arguments, (dict, list, str)) else {}
        serialized = json.dumps(arguments, ensure_ascii=False, separators=(",", ":"))
        workdir = arguments.get("workdir") if isinstance(arguments, dict) else None
        normalized_workdir = (
            posixpath.normpath(workdir.replace("\\", "/"))
            if isinstance(workdir, str) and workdir
            else None
        )

        for skill_name, raw_path in skill_paths.items():
            normalized_path = posixpath.normpath(raw_path.replace("\\", "/"))
            references = {normalized_path, raw_path}
            if normalized_workdir:
                relative = posixpath.relpath(normalized_path, normalized_workdir)
                references.update({relative, f"./{relative}"})
            matched = next(
                (reference for reference in references if reference and reference in serialized),
                None,
            )
            if matched is None:
                continue
            loaded.add(skill_name)
            evidence.setdefault(skill_name, []).append(
                {
                    "step_id": step.get("step_id"),
                    "tool_call_id": call.get("tool_call_id"),
                    "function_name": call.get("function_name"),
                    "reference": matched,
                }
            )
    return loaded, evidence


def raw_session_skill_usage(
    session_path: Path,
    provided: set[str],
) -> tuple[set[str], set[str], dict[str, list[dict[str, Any]]]]:
    """Recover Skill audit data directly from a preserved Codex session JSONL."""
    raw_events: list[dict[str, Any]] = []
    for raw_line in filesystem_path(session_path).read_text(encoding="utf-8").splitlines():
        if not raw_line.strip():
            continue
        event = json.loads(raw_line)
        if isinstance(event, dict):
            raw_events.append(event)

    available_paths: dict[str, str] = {}
    agent_steps: list[dict[str, Any]] = []
    for index, event in enumerate(raw_events):
        if event.get("type") != "response_item":
            continue
        payload = event.get("payload")
        payload = payload if isinstance(payload, dict) else {}
        if payload.get("type") == "message" and payload.get("role") == "developer":
            for text in iter_strings(payload.get("content", [])):
                if "### Available skills" in text and "<skills_instructions>" in text:
                    available_paths.update(task_skills_from_text(text))
        if payload.get("type") != "function_call":
            continue
        arguments = payload.get("arguments")
        if not isinstance(arguments, (dict, list, str)):
            continue
        agent_steps.append(
            {
                "source": "agent",
                "step_id": index,
                "tool_calls": [
                    {
                        "tool_call_id": payload.get("call_id"),
                        "function_name": payload.get("name"),
                        "arguments": arguments,
                    }
                ],
            }
        )

    candidate_paths = {
        name: f"{TASK_SKILLS_PREFIX.as_posix()}/{name}/SKILL.md"
        for name in provided | set(available_paths)
    }
    candidate_paths.update(available_paths)
    loaded, evidence = loaded_task_skills({"steps": agent_steps}, candidate_paths)
    return set(available_paths), loaded, evidence


def session_trial_id(session_path: Path) -> str:
    """Return the Harbor trial directory name that contains a session file."""
    for parent in session_path.parents:
        if parent.name == "agent":
            return parent.parent.name
    return session_path.stem


def analyze_skill_usage(
    job_dir: Path,
    provided_skills: list[str],
) -> dict[str, Any]:
    provided = set(provided_skills)
    # Harbor normally stores trajectories at <trial>/agent/trajectory.json.
    # Keep that fast, deterministic path first, then support newer Harbor
    # layouts that add another artifact directory below the trial.
    trajectory_paths = sorted(job_dir.glob("*/agent/trajectory.json"))
    if not trajectory_paths:
        trajectory_paths = sorted(job_dir.rglob("trajectory.json"))
    trials: list[dict[str, Any]] = []
    errors: list[str] = []
    available_union: set[str] = set()
    loaded_union: set[str] = set()
    if not trajectory_paths:
        session_paths = sorted(job_dir.glob("*/agent/sessions/**/*.jsonl"))
        if not session_paths:
            errors.append(f"No trajectory.json or session JSONL found under {job_dir}")
        for session_path in session_paths:
            trial_id = session_trial_id(session_path)
            try:
                available, loaded, evidence = raw_session_skill_usage(session_path, provided)
                missing_available = sorted(provided - available)
                unexpected_available = sorted(available - provided)
                trial_passed = not missing_available and not unexpected_available
                available_union.update(available)
                loaded_union.update(loaded)
                trials.append(
                    {
                        "trial_id": trial_id,
                        "source": "session_jsonl",
                        "passed": trial_passed,
                        "provided_skills": sorted(provided),
                        "available_skills": sorted(available),
                        "loaded_skills": sorted(loaded),
                        "missing_available": missing_available,
                        "unexpected_available": unexpected_available,
                        "load_evidence": evidence,
                    }
                )
            except Exception as exc:
                message = f"{trial_id}: {type(exc).__name__}: {exc}"
                errors.append(message)
                trials.append(
                    {
                        "trial_id": trial_id,
                        "source": "session_jsonl",
                        "passed": False,
                        "provided_skills": sorted(provided),
                        "available_skills": [],
                        "loaded_skills": [],
                        "missing_available": sorted(provided),
                        "unexpected_available": [],
                        "load_evidence": {},
                        "error": message,
                    }
                )

    for trajectory_path in trajectory_paths:
        trial_id = trajectory_path.parent.parent.name
        try:
            trajectory = read_json(trajectory_path)
            if trajectory is None:
                raise ValueError("trajectory is missing or empty")
            available_paths = available_task_skills(trajectory)
            # Also recognize a provided Skill if its standard mounted path is
            # referenced even when the advertised list is malformed.
            candidate_paths = {
                name: f"{TASK_SKILLS_PREFIX.as_posix()}/{name}/SKILL.md"
                for name in provided | set(available_paths)
            }
            candidate_paths.update(available_paths)
            loaded, evidence = loaded_task_skills(trajectory, candidate_paths)
            available = set(available_paths)
            missing_available = sorted(provided - available)
            unexpected_available = sorted(available - provided)
            trial_passed = not missing_available and not unexpected_available
            available_union.update(available)
            loaded_union.update(loaded)
            trials.append(
                {
                    "trial_id": trial_id,
                    "passed": trial_passed,
                    "provided_skills": sorted(provided),
                    "available_skills": sorted(available),
                    "loaded_skills": sorted(loaded),
                    "missing_available": missing_available,
                    "unexpected_available": unexpected_available,
                    "load_evidence": evidence,
                }
            )
        except Exception as exc:
            message = f"{trial_id}: {type(exc).__name__}: {exc}"
            errors.append(message)
            trials.append(
                {
                    "trial_id": trial_id,
                    "passed": False,
                    "provided_skills": sorted(provided),
                    "available_skills": [],
                    "loaded_skills": [],
                    "missing_available": sorted(provided),
                    "unexpected_available": [],
                    "load_evidence": {},
                    "error": message,
                }
            )

    return {
        "passed": bool(trials) and all(trial["passed"] for trial in trials) and not errors,
        "provided_skills": sorted(provided),
        "available_skills": sorted(available_union),
        "loaded_skills": sorted(loaded_union),
        "trials": trials,
        "error": "; ".join(errors) if errors else None,
    }
