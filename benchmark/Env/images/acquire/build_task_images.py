from __future__ import annotations

import argparse
import json
import re
import shutil
import subprocess
import sys
import uuid
from pathlib import Path


IMAGE_ROOT = Path(__file__).resolve().parent.parent
BENCHMARK_ROOT = IMAGE_ROOT.parents[1]
PROJECT_ROOT = BENCHMARK_ROOT.parent
ENV_ROOT = BENCHMARK_ROOT / "Env"
DEFAULT_TASKS_ROOT = BENCHMARK_ROOT / "datas" / "tasks"
DEFAULT_IMAGES_FILE = ENV_ROOT / "task_images.json"
DATASET_IMAGES_COPY = PROJECT_ROOT / "data" / "datasets" / "task_images.json"
DEFAULT_REPOSITORY_PREFIX = "benchmark-cache"
IMAGE_ID_PATTERN = re.compile(r"^(?:sha256:)?([0-9a-f]{64})$", re.IGNORECASE)


def run(command: list[str], *, capture: bool = False) -> subprocess.CompletedProcess[str]:
    print("+", subprocess.list2cmdline(command), flush=True)
    return subprocess.run(
        command,
        check=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
    )


def safe_slug(value: str) -> str:
    slug = re.sub(r"[^a-z0-9._-]+", "-", value.lower()).strip("-.")
    if not slug:
        raise ValueError(f"Task name has no usable Docker repository slug: {value!r}")
    return slug


def repository_ref(prefix: str, task_id: str) -> str:
    return f"{prefix.rstrip('/')}/{safe_slug(task_id)}-gold"


def discover_tasks(tasks_root: Path, requested: list[str] | None) -> list[tuple[str, Path]]:
    if not tasks_root.is_dir():
        raise FileNotFoundError(f"Tasks root does not exist: {tasks_root}")
    available = {
        path.name: path
        for path in tasks_root.iterdir()
        if path.is_dir() and (path / "environment" / "Dockerfile").is_file()
    }
    if requested:
        names = list(dict.fromkeys(requested))
        missing = sorted(set(names) - set(available))
        if missing:
            raise ValueError(f"Unknown task(s) or missing environment/Dockerfile: {', '.join(missing)}")
    else:
        names = sorted(available)
    return [(name, available[name]) for name in names]


def load_image_map(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    payload = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise ValueError(f"Image map must be a JSON object: {path}")
    result: dict[str, str] = {}
    for task, image in payload.items():
        if not isinstance(task, str) or not isinstance(image, str):
            raise ValueError(f"Image map entries must be string-to-string: {path}")
        result[task] = image
    return result


def write_image_map(path: Path, images: dict[str, str]) -> None:
    content = json.dumps(dict(sorted(images.items())), ensure_ascii=False, indent=2) + "\n"
    targets = [path]
    if path.resolve() == DEFAULT_IMAGES_FILE.resolve():
        # Publish the passive dataset copy first; runner reads only the Env copy.
        targets = [DATASET_IMAGES_COPY, path]
    for target in targets:
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_suffix(target.suffix + ".tmp")
        temporary.write_text(content, encoding="utf-8", newline="\n")
        temporary.replace(target)


def ensure_docker_available() -> None:
    if shutil.which("docker") is None:
        raise FileNotFoundError("docker was not found on PATH")
    result = subprocess.run(
        ["docker", "info"],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.PIPE,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode != 0:
        reason = (result.stderr or "").strip()
        raise RuntimeError(f"Docker daemon is unavailable. {reason}")


def inspect_image_id(image: str) -> str | None:
    result = subprocess.run(
        ["docker", "image", "inspect", "--format", "{{.Id}}", image],
        stdout=subprocess.PIPE,
        stderr=subprocess.DEVNULL,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=False,
    )
    if result.returncode != 0:
        return None
    match = IMAGE_ID_PATTERN.fullmatch(result.stdout.strip())
    if match is None:
        raise RuntimeError(f"Unexpected Docker Image ID for {image}: {result.stdout.strip()!r}")
    return match.group(1).lower()


def image_references(image: str) -> list[str]:
    result = run(
        ["docker", "image", "inspect", "--format", "{{json .RepoTags}}", image],
        capture=True,
    )
    payload = json.loads(result.stdout)
    if payload is None:
        return []
    if not isinstance(payload, list) or not all(isinstance(item, str) for item in payload):
        raise RuntimeError(f"Unexpected Docker RepoTags for {image}: {payload!r}")
    return sorted(item for item in payload if not item.endswith(":<none>"))


def normalize_single_reference(image: str, keep: str) -> None:
    image_id = inspect_image_id(image)
    if image_id is None:
        raise RuntimeError(f"Cannot normalize missing image: {image}")
    keep_id = inspect_image_id(keep)
    if keep_id is None:
        run(["docker", "tag", image, keep])
        keep_id = inspect_image_id(keep)
    if keep_id != image_id:
        raise RuntimeError(f"Refusing to merge different images: {image} -> {keep}")

    for reference in image_references(keep):
        if reference != keep:
            run(["docker", "image", "rm", reference])

    remaining = image_references(keep)
    if remaining != [keep]:
        raise RuntimeError(
            f"Image must have exactly one reference after normalization: "
            f"image={keep} references={remaining}"
        )


def mapped_reference_for_image(images: dict[str, str], image_id: str) -> str | None:
    for reference in dict.fromkeys(images.values()):
        if inspect_image_id(reference) == image_id:
            return reference
    return None


def task_image_references(task_id: str, canonical_repository: str) -> list[str]:
    result = run(
        ["docker", "image", "ls", "--format", "{{.Repository}}:{{.Tag}}"],
        capture=True,
    )
    task_slug = safe_slug(task_id)
    matching_names = {task_slug, f"{task_slug}-gold"}
    references: set[str] = set()
    for raw_reference in result.stdout.splitlines():
        reference = raw_reference.strip()
        if not reference or reference.endswith(":<none>"):
            continue
        repository = reference.rsplit(":", 1)[0]
        repository_name = repository.rsplit("/", 1)[-1].lower()
        if repository == canonical_repository or repository_name in matching_names:
            references.add(reference)
    return sorted(references)


def remove_other_task_images(
    task_id: str,
    canonical_repository: str,
    keep: str,
    mapped_references: set[str],
) -> None:
    for reference in task_image_references(task_id, canonical_repository):
        if reference != keep and reference not in mapped_references:
            run(["docker", "image", "rm", reference])


def repository_images(repository: str) -> list[str]:
    result = run(
        [
            "docker",
            "image",
            "ls",
            "--format",
            "{{.Repository}}:{{.Tag}}",
            "--filter",
            f"reference={repository}:*",
        ],
        capture=True,
    )
    return sorted(
        {
            line.strip()
            for line in result.stdout.splitlines()
            if line.strip() and not line.rstrip().endswith(":<none>")
        }
    )


def formal_image_ref(repository: str, image_id: str) -> str:
    return f"{repository}:{image_id[:16]}"


def build_staging_image(
    task_id: str,
    environment_dir: Path,
    *,
    pull: bool,
) -> str:
    staging = f"benchmark-build/{safe_slug(task_id)}:staging-{uuid.uuid4().hex[:12]}"
    command = ["docker", "build"]
    if pull:
        command.append("--pull")
    command.extend(
        [
            "--file",
            str(environment_dir / "Dockerfile"),
            "--label",
            f"skillbench.task={task_id}",
            "--label",
            "skillbench.image.stage=raw-task-environment",
            "--tag",
            staging,
            str(environment_dir),
        ]
    )
    run(command)
    return staging


def choose_existing_image(mapped: str | None, repository: str) -> str | None:
    if mapped and inspect_image_id(mapped) is not None:
        return mapped
    candidates = repository_images(repository)
    if not candidates:
        return None
    if len(candidates) > 1:
        raise RuntimeError(
            f"Multiple local images exist for {repository}, but the mapped image is unavailable: "
            + ", ".join(candidates)
            + ". Restore task_images.json or select the intended image manually before retrying."
        )
    return candidates[0]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Adopt an existing local task image when possible; otherwise build its "
            "environment Dockerfile. Tag the result using Docker's own Image ID."
        )
    )
    parser.add_argument("--tasks-root", type=Path, default=DEFAULT_TASKS_ROOT)
    parser.add_argument("--images-file", type=Path, default=DEFAULT_IMAGES_FILE)
    parser.add_argument("--task", action="append", help="Process only this task; may be repeated.")
    parser.add_argument("--repository-prefix", default=DEFAULT_REPOSITORY_PREFIX)
    parser.add_argument("--force", action="store_true", help="Ignore an existing image and rebuild from Dockerfile.")
    parser.add_argument(
        "--pull",
        action=argparse.BooleanOptionalAction,
        default=True,
        help="Ask Docker to refresh FROM images when a build is required. Default: enabled.",
    )
    parser.add_argument("--audit", action="store_true", help="Verify mapped images and Image-ID tags without building.")
    parser.add_argument("--dry-run", action="store_true", help="Show mappings and potential actions without using Docker.")
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    tasks_root = args.tasks_root.resolve()
    images_file = args.images_file.resolve()
    tasks = discover_tasks(tasks_root, args.task)
    images = load_image_map(images_file)
    if not args.task:
        selected_tasks = {task_id for task_id, _ in tasks}
        images = {
            task_id: image
            for task_id, image in images.items()
            if task_id in selected_tasks
        }

    if args.dry_run:
        for task_id, _ in tasks:
            mapped = images.get(task_id)
            action = "force-build" if args.force else "adopt-if-local; otherwise build"
            print(f"[plan] {task_id}: mapped={mapped or '<none>'} action={action}")
        print(f"[dry-run] planned={len(tasks)} mapping={images_file}")
        return 0

    ensure_docker_available()

    if args.audit:
        failures: list[str] = []
        for task_id, _ in tasks:
            mapped = images.get(task_id)
            if mapped is None:
                failures.append(f"{task_id}: no mapping")
                continue
            image_id = inspect_image_id(mapped)
            if image_id is None:
                failures.append(f"{task_id}: mapped image is missing: {mapped}")
                continue
            repository = repository_ref(args.repository_prefix, task_id)
            expected = formal_image_ref(repository, image_id)
            if mapped != expected:
                failures.append(f"{task_id}: mapping={mapped}, Image-ID tag={expected}")
                continue
            references = image_references(mapped)
            if references != [mapped]:
                failures.append(
                    f"{task_id}: image must have one tag; mapping={mapped}, "
                    f"references={references}"
                )
                continue
            related = task_image_references(task_id, repository)
            if related != [mapped]:
                failures.append(
                    f"{task_id}: task must have one image; mapping={mapped}, "
                    f"task_references={related}"
                )
        if failures:
            raise RuntimeError("Image audit failed:\n" + "\n".join(failures))
        print(f"[audit-complete] verified={len(tasks)}")
        return 0

    for task_id, task_dir in tasks:
        repository = repository_ref(args.repository_prefix, task_id)
        source: str | None = None
        staging: str | None = None
        try:
            if not args.force:
                source = choose_existing_image(images.get(task_id), repository)
            if source is None:
                print(f"[build] {task_id}: no reusable local image")
                staging = build_staging_image(
                    task_id,
                    task_dir / "environment",
                    pull=args.pull,
                )
                source = staging
            else:
                print(f"[adopt] {task_id}: {source}")

            image_id = inspect_image_id(source)
            if image_id is None:
                raise RuntimeError(f"Image disappeared before it could be tagged: {source}")
            formal = mapped_reference_for_image(images, image_id)
            if formal is None:
                formal = formal_image_ref(repository, image_id)
            if source != formal:
                run(["docker", "tag", source, formal])
            images[task_id] = formal
            write_image_map(images_file, images)
            normalize_single_reference(formal, formal)
            remove_other_task_images(
                task_id,
                repository,
                formal,
                set(images.values()),
            )
            print(f"[mapped] {task_id}: {formal}")
        finally:
            if staging is not None:
                subprocess.run(
                    ["docker", "image", "rm", staging],
                    stdout=subprocess.DEVNULL,
                    stderr=subprocess.DEVNULL,
                    check=False,
                )

    print(f"[complete] tasks={len(tasks)} mapping={images_file}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"[error] {type(exc).__name__}: {exc}", file=sys.stderr)
        raise SystemExit(1)
