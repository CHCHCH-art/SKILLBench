from __future__ import annotations

import argparse
import subprocess
import sys
from pathlib import Path


IMAGE_ROOT = Path(__file__).resolve().parent
ACQUIRE_SCRIPT = IMAGE_ROOT / "acquire" / "build_task_images.py"
PATCH_SCRIPT = IMAGE_ROOT / "patch" / "prepare_agent_images.py"
ENV_ROOT = IMAGE_ROOT.parent
DEFAULT_IMAGES_FILE = ENV_ROOT / "task_images.json"
DEFAULT_TASKS_ROOT = IMAGE_ROOT.parents[1] / "datas" / "tasks"


def run_step(name: str, command: list[str]) -> None:
    print(f"\n=== {name} ===", flush=True)
    print("+", subprocess.list2cmdline(command), flush=True)
    result = subprocess.run(command, check=False)
    if result.returncode != 0:
        raise RuntimeError(f"{name} failed with exit code {result.returncode}")


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Prepare all Task Docker images in two ordered stages: first adopt "
            "or build task images, then install and verify common Agent tools."
        )
    )
    parser.add_argument("--task", action="append", help="Process only this task; may be repeated.")
    parser.add_argument("--tasks-root", type=Path, default=DEFAULT_TASKS_ROOT)
    parser.add_argument("--images-file", type=Path, default=DEFAULT_IMAGES_FILE)
    parser.add_argument("--repository-prefix", default="benchmark-cache")
    parser.add_argument("--force", action="store_true", help="Force rebuilding Task Dockerfiles in stage 1.")
    parser.add_argument(
        "--pull",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Refresh Dockerfile FROM images if stage 1 must build. Default: enabled.",
    )
    parser.add_argument("--audit", action="store_true", help="Audit both stages without changing images.")
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Preview stage 1 and list the stage-2 selection without using Docker.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    python = sys.executable
    images_file = args.images_file.resolve()

    acquire = [
        python,
        str(ACQUIRE_SCRIPT),
        "--tasks-root",
        str(args.tasks_root.resolve()),
        "--images-file",
        str(images_file),
        "--repository-prefix",
        args.repository_prefix,
    ]
    if args.force:
        acquire.append("--force")
    if not args.pull:
        acquire.append("--no-pull")
    if args.audit:
        acquire.append("--audit")
    if args.dry_run:
        acquire.append("--dry-run")
    for task in args.task or []:
        acquire.extend(["--task", task])

    run_step("Stage 1/2 - acquire or build Task images", acquire)

    if args.dry_run:
        selected = ", ".join(args.task) if args.task else "all mapped tasks"
        print(
            "\n=== Stage 2/2 - install common tools ===\n"
            f"[dry-run] would process {selected} using {images_file}",
            flush=True,
        )
        print("\n[dry-run-complete] no Docker images or mappings were changed", flush=True)
        return 0

    patch = [python, str(PATCH_SCRIPT), "--images-file", str(images_file)]
    if args.audit:
        patch.append("--audit")
    for task in args.task or []:
        patch.extend(["--task", task])

    run_step("Stage 2/2 - install and verify common tools", patch)
    print(f"\n[complete] Task images are ready and {images_file} is current", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, RuntimeError) as exc:
        print(f"[error] {type(exc).__name__}: {exc}", file=sys.stderr)
        raise SystemExit(1)
