#!/usr/bin/env python
"""Run the metadata generation, validation, merge, and cleanup pipeline."""

from __future__ import annotations

import argparse
import importlib
import json
import shutil
import subprocess
import sys
import time
from datetime import datetime
from pathlib import Path
from typing import Any


ROOT = Path(__file__).resolve().parent
ARTIFACT_NAMES = (
    "Base Describe.md",
    "Base_Describe.md",
    "skill_llm_describe.json",
    "All_Desc.jsonl",
)
STOP_ORDER = {
    "l1": 1,
    "base": 2,
    "ds": 3,
    "scan": 4,
    "merge": 5,
    "collect": 6,
    "backup": 7,
}


def now_iso() -> str:
    return datetime.now().isoformat(timespec="seconds")


def clean_path(raw: str) -> Path:
    return Path(raw.strip().strip('"').strip("'")).expanduser().resolve()


def iter_skill_dirs(skills_dir: Path):
    for child in sorted(skills_dir.iterdir(), key=lambda p: p.name.lower()):
        if child.is_dir():
            yield child


def path_is_relative_to(path: Path, parent: Path) -> bool:
    try:
        path.resolve().relative_to(parent.resolve())
        return True
    except ValueError:
        return False


def has_first_level_skill_dirs(path: Path) -> bool:
    if not path.is_dir():
        return False
    return any(
        child.is_dir() and (child / "SKILL.md").is_file()
        for child in path.iterdir()
    )


def json_default(value: Any) -> Any:
    if isinstance(value, Path):
        return str(value)
    return str(value)


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(
        json.dumps(data, ensure_ascii=False, indent=2, default=json_default) + "\n",
        encoding="utf-8",
    )


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def run_command(step: str, command: list[str], report_dir: Path) -> dict[str, Any]:
    started_at = now_iso()
    proc = subprocess.run(
        command,
        cwd=str(ROOT),
        text=True,
        encoding="utf-8",
        errors="replace",
        capture_output=True,
    )
    finished_at = now_iso()

    if proc.stdout:
        print(proc.stdout, end="" if proc.stdout.endswith("\n") else "\n")
    if proc.stderr:
        print(proc.stderr, file=sys.stderr, end="" if proc.stderr.endswith("\n") else "\n")

    write_text(report_dir / f"{step}_stdout.txt", proc.stdout)
    write_text(report_dir / f"{step}_stderr.txt", proc.stderr)

    result = {
        "step": step,
        "command": command,
        "returncode": proc.returncode,
        "started_at": started_at,
        "finished_at": finished_at,
        "stdout_log": str(report_dir / f"{step}_stdout.txt"),
        "stderr_log": str(report_dir / f"{step}_stderr.txt"),
    }
    if proc.returncode != 0:
        raise RuntimeError(f"{step} failed with exit code {proc.returncode}")
    return result


def serialize_l1_result(result: dict[str, Any]) -> dict[str, Any]:
    return {
        "skill_dir": str(result.get("skill_dir", "")),
        "path": result.get("path", ""),
        "skill_relative_dir": result.get("skill_relative_dir", ""),
        "parent_dir": result.get("parent_dir", ""),
        "name": result.get("name", ""),
        "valid": result.get("valid", False),
        "errors": list(result.get("errors", [])),
    }


def run_l1(
    skills_dir: Path,
    invalid_dir: Path,
    report_dir: Path,
    move_invalid: bool,
) -> dict[str, Any]:
    first_select = importlib.import_module("First_select")
    results = first_select.scan(skills_dir, invalid_dir=invalid_dir)
    first_select.print_report(results)

    if move_invalid:
        first_select.move_invalid_skills(
            results=results,
            root=skills_dir,
            invalid_dir=invalid_dir,
            dry_run=False,
        )

    serialized = [serialize_l1_result(result) for result in results]
    summary = {
        "root": str(skills_dir),
        "invalid_dir": str(invalid_dir),
        "move_invalid": move_invalid,
        "total": len(serialized),
        "valid": sum(1 for result in serialized if result["valid"]),
        "invalid": sum(1 for result in serialized if not result["valid"]),
        "results": serialized,
    }
    write_json(report_dir / "l1_report.json", summary)
    return summary


def backup_preexisting_artifacts(skills_dir: Path, report_dir: Path) -> dict[str, Any]:
    backup_root = report_dir / "preexisting_artifacts_backup"
    records: list[dict[str, str]] = []

    for skill_dir in iter_skill_dirs(skills_dir):
        rel_skill = skill_dir.relative_to(skills_dir)
        for filename in ARTIFACT_NAMES:
            source = skill_dir / filename
            if not source.is_file():
                continue

            destination = backup_root / rel_skill / filename
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            records.append(
                {
                    "skill": rel_skill.as_posix(),
                    "source": str(source),
                    "backup": str(destination),
                }
            )

    summary = {
        "backup_root": str(backup_root),
        "files_backed_up": len(records),
        "records": records,
    }
    write_json(report_dir / "preexisting_artifacts_backup_report.json", summary)
    return summary


def backup_llm_desc(skills_dir: Path, report_dir: Path) -> dict[str, Any]:
    output_path = report_dir / "llm_desc_backup.jsonl"
    records = 0
    errors: list[dict[str, str]] = []

    report_dir.mkdir(parents=True, exist_ok=True)
    with output_path.open("w", encoding="utf-8", newline="\n") as handle:
        for skill_dir in iter_skill_dirs(skills_dir):
            rel_skill = skill_dir.relative_to(skills_dir).as_posix()
            source = skill_dir / "skill_llm_describe.json"
            if not source.is_file():
                continue

            try:
                data = json.loads(source.read_text(encoding="utf-8"))
            except Exception as exc:
                errors.append(
                    {
                        "skill": rel_skill,
                        "source": str(source),
                        "error": f"{type(exc).__name__}:{exc}",
                    }
                )
                continue

            handle.write(
                json.dumps(
                    {
                        "skill_relative_dir": rel_skill,
                        "source_path": str(source),
                        "llm_desc": data,
                    },
                    ensure_ascii=False,
                    separators=(",", ":"),
                )
                + "\n"
            )
            records += 1

    summary = {
        "output": str(output_path),
        "records": records,
        "errors": errors,
    }
    write_json(report_dir / "llm_desc_backup_report.json", summary)
    if errors:
        raise RuntimeError(f"LLM desc backup had {len(errors)} parse errors")
    return summary


def cleanup_artifacts(skills_dir: Path, report_dir: Path) -> dict[str, Any]:
    deleted: list[str] = []
    errors: list[dict[str, str]] = []

    for skill_dir in iter_skill_dirs(skills_dir):
        for filename in ARTIFACT_NAMES:
            path = skill_dir / filename
            if not path.exists():
                continue
            if not path.is_file():
                errors.append({"path": str(path), "error": "not_a_file"})
                continue

            try:
                path.unlink()
                deleted.append(str(path))
            except Exception as exc:
                errors.append({"path": str(path), "error": f"{type(exc).__name__}:{exc}"})

    summary = {
        "deleted_count": len(deleted),
        "deleted": deleted,
        "errors": errors,
    }
    write_json(report_dir / "cleanup_report.json", summary)
    if errors:
        raise RuntimeError(f"Cleanup had {len(errors)} errors")
    return summary


def run_ds_desc(
    skills_dir: Path,
    report_dir: Path,
    fail_log: Path,
    start_suffix: int | None,
    limit: int | None,
    concurrency: int,
    dry_run: bool,
    max_network_retries: int | None,
    llm_mode: str,
) -> dict[str, Any]:
    ds_desc = importlib.import_module("DS_Desc")
    ds_desc.FAIL_LOG = fail_log

    if not ds_desc.DEEPSEEK_API_KEY or "在这里填" in ds_desc.DEEPSEEK_API_KEY:
        raise RuntimeError("DEEPSEEK_API_KEY is not configured in DS_Desc.py")

    prompt_text = ds_desc.load_prompt()
    skill_items = ds_desc.collect_skill_dirs(skills_dir)

    if start_suffix is not None:
        skill_items = [item for item in skill_items if item[0] >= start_suffix]

    skipped_existing = 0
    if llm_mode == "missing":
        before_count = len(skill_items)
        skill_items = [
            item for item in skill_items if not (item[2] / "skill_llm_describe.json").is_file()
        ]
        skipped_existing = before_count - len(skill_items)

    if limit is not None:
        skill_items = skill_items[:limit]

    total_ok = 0
    total_fail = 0
    retry_round = 0
    retry_items: list[tuple[int, str, Path]] = []

    ok_count, fail_count, retry_items = ds_desc.run_one_round(
        skill_items=skill_items,
        prompt_text=prompt_text,
        dry_run=dry_run,
        concurrency=concurrency,
        round_name="pipeline DS_Desc first round",
    )
    total_ok += ok_count
    total_fail += fail_count

    while retry_items and (max_network_retries is None or retry_round < max_network_retries):
        retry_round += 1
        ds_desc.save_network_retry_index(retry_items, retry_round)
        time.sleep(ds_desc.NETWORK_RETRY_SLEEP_SECONDS)
        ok_count, fail_count, retry_items = ds_desc.run_one_round(
            skill_items=retry_items,
            prompt_text=prompt_text,
            dry_run=dry_run,
            concurrency=concurrency,
            round_name=f"pipeline DS_Desc network retry {retry_round}",
        )
        total_ok += ok_count
        total_fail += fail_count

    if retry_items:
        ds_desc.save_network_retry_index(retry_items, retry_round)
    else:
        ds_desc.clear_network_retry_index()

    summary = {
        "root": str(skills_dir),
        "fail_log": str(fail_log),
        "dry_run": dry_run,
        "llm_mode": llm_mode,
        "start_suffix": start_suffix,
        "limit": limit,
        "concurrency": concurrency,
        "skipped_existing": skipped_existing,
        "items_seen": len(skill_items),
        "ok": total_ok,
        "fail": total_fail,
        "network_retry_pending": len(retry_items),
        "network_retry_pending_items": [
            {"suffix": suffix, "skill_id": skill_id, "skill_dir": str(skill_dir)}
            for suffix, skill_id, skill_dir in retry_items
        ],
    }
    write_json(report_dir / "ds_desc_report.json", summary)

    if retry_items:
        raise RuntimeError(f"DS_Desc left {len(retry_items)} network retry items")
    if total_fail:
        raise RuntimeError(f"DS_Desc had {total_fail} non-network failures")
    return summary


def should_stop(args: argparse.Namespace, step: str) -> bool:
    return bool(args.stop_after and STOP_ORDER[step] >= STOP_ORDER[args.stop_after])


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Run the Agent_Skills metadata pipeline for one dataset."
    )
    parser.add_argument(
        "root",
        nargs="?",
        help="Skill library root, for example path/to/library/skills.",
    )
    parser.add_argument(
        "--skill-id-prefix",
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--invalid-dir",
        help=argparse.SUPPRESS,
    )
    parser.add_argument(
        "--report-dir",
        help=argparse.SUPPRESS,
    )
    parser.set_defaults(move_invalid=True, run_ds_desc=True)
    parser.add_argument("--move-invalid", dest="move_invalid", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--no-move-invalid", dest="move_invalid", action="store_false", help=argparse.SUPPRESS)
    parser.add_argument("--run-ds-desc", dest="run_ds_desc", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--skip-ds-desc", dest="run_ds_desc", action="store_false", help=argparse.SUPPRESS)
    parser.add_argument(
        "--ds-dry-run",
        action="store_true",
        help=argparse.SUPPRESS,
    )
    parser.add_argument("--limit", type=int, help=argparse.SUPPRESS)
    parser.add_argument("--start-suffix", type=int, help=argparse.SUPPRESS)
    parser.add_argument(
        "--no_llm",
        "--no-llm",
        dest="no_llm",
        action="store_true",
        help=(
            "Skip LLM labeling and validation. All.jsonl is generated from base "
            "metadata without task_tags or service score fields."
        ),
    )
    parser.add_argument("--concurrency", type=int, default=1, help="DS_Desc concurrency. Default: 1.")
    parser.add_argument(
        "--llm-mode",
        choices=("missing", "overwrite"),
        default="missing",
        help="DS_Desc rerun mode. 'missing' only processes skills without skill_llm_describe.json; 'overwrite' regenerates all. Default: missing.",
    )
    parser.add_argument(
        "--max-network-retries",
        type=int,
        default=None,
        help=argparse.SUPPRESS,
    )
    parser.add_argument("--keep-artifacts", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument(
        "--stop-after",
        choices=tuple(STOP_ORDER),
        help=argparse.SUPPRESS,
    )
    parser.add_argument("--skip-l1", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--skip-base", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--skip-scan", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--skip-merge", action="store_true", help=argparse.SUPPRESS)
    parser.add_argument("--skip-collect", action="store_true", help=argparse.SUPPRESS)
    return parser.parse_args()


def main() -> int:
    args = parse_args()

    root_raw = args.root
    if not root_raw:
        print("Skill library root is required.", file=sys.stderr)
        return 2

    input_root = clean_path(root_raw)
    skills_dir = input_root
    dataset_root = skills_dir.parent
    root_mode = "skills_root"
    dataset_name = dataset_root.name
    skill_id_prefix = args.skill_id_prefix or dataset_name
    invalid_dir = clean_path(args.invalid_dir) if args.invalid_dir else ROOT / "L1_Fail" / dataset_name
    report_dir = clean_path(args.report_dir) if args.report_dir else dataset_root / "report"
    dataset_base_describe = dataset_root / "Base Describe.md"
    fail_log = report_dir / "ds_fail_log.jsonl"

    if not dataset_root.is_dir():
        print(f"Dataset root does not exist: {dataset_root}", file=sys.stderr)
        return 2
    if not skills_dir.is_dir():
        print(f"Skills dir does not exist: {skills_dir}", file=sys.stderr)
        return 2
    if not has_first_level_skill_dirs(skills_dir):
        print(
            "Input root must contain first-level skill folders with SKILL.md: "
            f"{skills_dir}",
            file=sys.stderr,
        )
        return 2
    if not dataset_base_describe.is_file():
        print(f"Dataset Base Describe.md does not exist: {dataset_base_describe}", file=sys.stderr)
        return 2
    if args.concurrency < 1:
        print("--concurrency must be >= 1", file=sys.stderr)
        return 2
    if args.max_network_retries is not None and args.max_network_retries < 0:
        print("--max-network-retries must be >= 0", file=sys.stderr)
        return 2

    report_dir.mkdir(parents=True, exist_ok=True)
    pipeline_report: dict[str, Any] = {
        "started_at": now_iso(),
        "dataset_root": str(dataset_root),
        "skills_dir": str(skills_dir),
        "input_root": str(input_root),
        "root_mode": root_mode,
        "dataset_name": dataset_name,
        "skill_id_prefix": skill_id_prefix,
        "invalid_dir": str(invalid_dir),
        "report_dir": str(report_dir),
        "final_output": str(dataset_root / "All.jsonl"),
        "llm_enabled": not args.no_llm,
        "steps": [],
    }

    try:
        pipeline_report["preexisting_artifacts"] = backup_preexisting_artifacts(skills_dir, report_dir)

        if not args.skip_l1:
            print("\n[1/7] L1 scan")
            result = run_l1(skills_dir, invalid_dir, report_dir, args.move_invalid)
            pipeline_report["steps"].append({"step": "l1", "status": "ok", "summary": result})
        else:
            pipeline_report["steps"].append({"step": "l1", "status": "skipped"})
        if should_stop(args, "l1"):
            return 0

        if not args.skip_base:
            print("\n[2/7] Base Describe generation")
            result = run_command(
                "base_describe",
                [
                    sys.executable,
                    str(ROOT / "complete_base_describe.py"),
                    "--skills-dir",
                    str(skills_dir),
                    "--base-describe",
                    str(dataset_base_describe),
                    "--skill-id-prefix",
                    skill_id_prefix,
                    "--out-prefix",
                    str(report_dir / "base_describe_index"),
                ],
                report_dir,
            )
            pipeline_report["steps"].append({"step": "base", "status": "ok", "summary": result})
        else:
            pipeline_report["steps"].append({"step": "base", "status": "skipped"})
        if should_stop(args, "base"):
            return 0

        if args.no_llm:
            print("\n[3/7] DS_Desc skipped (--no_llm)")
            pipeline_report["steps"].append(
                {"step": "ds", "status": "skipped", "reason": "no_llm"}
            )
        elif args.run_ds_desc:
            print("\n[3/7] DS_Desc")
            result = run_ds_desc(
                skills_dir=skills_dir,
                report_dir=report_dir,
                fail_log=fail_log,
                start_suffix=args.start_suffix,
                limit=args.limit,
                concurrency=args.concurrency,
                dry_run=args.ds_dry_run,
                max_network_retries=args.max_network_retries,
                llm_mode=args.llm_mode,
            )
            pipeline_report["steps"].append({"step": "ds", "status": "ok", "summary": result})
        else:
            print("\n[3/7] DS_Desc skipped")
            pipeline_report["steps"].append({"step": "ds", "status": "skipped"})
        if should_stop(args, "ds"):
            return 0

        if args.no_llm:
            print("\n[4/7] LLM description scan skipped (--no_llm)")
            pipeline_report["steps"].append(
                {"step": "scan", "status": "skipped", "reason": "no_llm"}
            )
        elif not args.skip_scan:
            print("\n[4/7] Scan skill_llm_describe")
            result = run_command(
                "scan",
                [
                    sys.executable,
                    str(ROOT / "scan_skill_llm_describe.py"),
                    str(skills_dir),
                    "--report",
                    str(report_dir / "scan_report.json"),
                ],
                report_dir,
            )
            pipeline_report["steps"].append({"step": "scan", "status": "ok", "summary": result})
        else:
            pipeline_report["steps"].append({"step": "scan", "status": "skipped"})
        if should_stop(args, "scan"):
            return 0

        if not args.skip_merge:
            print("\n[5/7] Merge per-skill records")
            merge_command = [
                sys.executable,
                str(ROOT / "merge_all_desc.py"),
                str(skills_dir),
                "--report",
                str(report_dir / "merge_report.json"),
            ]
            if args.no_llm:
                merge_command.append("--no_llm")
            result = run_command(
                "merge",
                merge_command,
                report_dir,
            )
            pipeline_report["steps"].append({"step": "merge", "status": "ok", "summary": result})
        else:
            pipeline_report["steps"].append({"step": "merge", "status": "skipped"})
        if should_stop(args, "merge"):
            return 0

        if not args.skip_collect:
            print("\n[6/7] Collect All_Desc.jsonl")
            result = run_command(
                "collect",
                [
                    sys.executable,
                    str(ROOT / "collect_all_desc.py"),
                    "--input-dir",
                    str(skills_dir),
                    "--output-dir",
                    str(dataset_root),
                    "--report",
                    str(report_dir / "collect_report.json"),
                ],
                report_dir,
            )
            pipeline_report["steps"].append({"step": "collect", "status": "ok", "summary": result})
        else:
            pipeline_report["steps"].append({"step": "collect", "status": "skipped"})
        if should_stop(args, "collect"):
            return 0

        if args.no_llm:
            print("\n[7/7] Backup LLM desc skipped (--no_llm)")
            pipeline_report["steps"].append(
                {"step": "backup", "status": "skipped", "reason": "no_llm"}
            )
        else:
            print("\n[7/7] Backup LLM desc")
            result = backup_llm_desc(skills_dir, report_dir)
            pipeline_report["steps"].append(
                {"step": "backup", "status": "ok", "summary": result}
            )
        if should_stop(args, "backup"):
            return 0

        ds_dry_run_active = args.ds_dry_run and not args.no_llm
        if args.keep_artifacts or args.skip_collect or ds_dry_run_active:
            reason = "keep_artifacts"
            if args.skip_collect:
                reason = "skip_collect"
            elif ds_dry_run_active:
                reason = "ds_dry_run"
            pipeline_report["steps"].append(
                {"step": "cleanup", "status": "skipped", "reason": reason}
            )
        else:
            print("\n[cleanup] Remove per-skill temporary artifacts")
            result = cleanup_artifacts(skills_dir, report_dir)
            pipeline_report["steps"].append({"step": "cleanup", "status": "ok", "summary": result})

        pipeline_report["status"] = "ok"
        pipeline_report["finished_at"] = now_iso()
        write_json(report_dir / "pipeline_report.json", pipeline_report)
        print(f"\nPipeline complete: {dataset_root / 'All.jsonl'}")
        print(f"Reports: {report_dir}")
        return 0

    except Exception as exc:
        pipeline_report["status"] = "error"
        pipeline_report["error"] = f"{type(exc).__name__}: {exc}"
        pipeline_report["finished_at"] = now_iso()
        write_json(report_dir / "pipeline_report.json", pipeline_report)
        print(f"\nPipeline failed: {type(exc).__name__}: {exc}", file=sys.stderr)
        print(f"Report written: {report_dir / 'pipeline_report.json'}", file=sys.stderr)
        return 1

    finally:
        if "status" not in pipeline_report:
            pipeline_report["status"] = "stopped"
            pipeline_report["finished_at"] = now_iso()
            write_json(report_dir / "pipeline_report.json", pipeline_report)


if __name__ == "__main__":
    raise SystemExit(main())
