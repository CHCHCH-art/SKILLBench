from __future__ import annotations

import argparse
import hashlib
import json
import subprocess
import sys
import uuid
from pathlib import Path
from typing import Any


PATCH_ROOT = Path(__file__).resolve().parent
IMAGE_ROOT = PATCH_ROOT.parent
PROJECT_ROOT = IMAGE_ROOT.parents[2]
ENV_ROOT = IMAGE_ROOT.parent
DEFAULT_IMAGES_FILE = ENV_ROOT / "task_images.json"
DATASET_IMAGES_COPY = PROJECT_ROOT / "data" / "datasets" / "task_images.json"
INSTALL_DOCKERFILE = PATCH_ROOT / "Dockerfile.install-tools"
MANIFEST_PATH = IMAGE_ROOT / "packages" / "manifest.json"
PACKAGE_DIR = IMAGE_ROOT / "packages" / "linux-x64"


def run(
    command: list[str],
    *,
    capture: bool = False,
    check: bool = True,
) -> subprocess.CompletedProcess[str]:
    print("+", subprocess.list2cmdline(command), flush=True)
    return subprocess.run(
        command,
        text=True,
        encoding="utf-8",
        errors="replace",
        stdout=subprocess.PIPE if capture else None,
        stderr=subprocess.PIPE if capture else None,
        check=check,
    )


def docker_inspect(image: str) -> dict[str, Any]:
    result = run(["docker", "image", "inspect", image], capture=True)
    payload = json.loads(result.stdout)
    if not isinstance(payload, list) or len(payload) != 1:
        raise RuntimeError(f"Unexpected docker inspect result for {image}")
    return payload[0]


def validate_packages() -> dict[str, Any]:
    manifest = json.loads(MANIFEST_PATH.read_text(encoding="utf-8"))
    failures: list[str] = []
    for key, details in manifest["files"].items():
        path = PACKAGE_DIR / details["name"]
        if not path.is_file():
            failures.append(f"{key}: missing {path}")
            continue
        size = path.stat().st_size
        if size != details["size"]:
            failures.append(
                f"{key}: size mismatch, expected {details['size']}, found {size}"
            )
            continue
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        if digest != details["sha256"]:
            failures.append(
                f"{key}: SHA-256 mismatch, expected {details['sha256']}, found {digest}"
            )
    if failures:
        raise RuntimeError("Invalid offline packages:\n" + "\n".join(failures))
    print(
        "[packages] verified "
        f"Node {manifest['node_version']}, "
        f"Codex {manifest['codex_version']}, "
        f"uv {manifest['uv_version']}, "
        f"ripgrep {manifest['ripgrep_version']}",
        flush=True,
    )
    return manifest


def load_images(images_file: Path) -> dict[str, str]:
    if not images_file.is_file():
        raise RuntimeError(f"Image mapping file not found: {images_file}")

    payload = json.loads(images_file.read_text(encoding="utf-8"))
    if not isinstance(payload, dict):
        raise RuntimeError(
            f"Image mapping file must contain a JSON object: {images_file}"
        )

    tasks: dict[str, str] = {}
    for task_id, image in payload.items():
        if not isinstance(task_id, str) or not task_id.strip():
            raise RuntimeError(f"Invalid task ID in image mapping file: {task_id!r}")
        if not isinstance(image, str) or not image.strip():
            raise RuntimeError(
                f"Invalid image for task {task_id!r} in {images_file}"
            )
        tasks[task_id.strip()] = image.strip()

    if not tasks:
        raise RuntimeError(
            f"No image mappings found in {images_file}. "
            "Add entries in the form {\"task-id\": \"image:tag\"}."
        )
    return tasks


def write_images(images_file: Path, images: dict[str, str]) -> None:
    content = json.dumps(dict(sorted(images.items())), ensure_ascii=False, indent=2) + "\n"
    targets = [images_file]
    if images_file.resolve() == DEFAULT_IMAGES_FILE.resolve():
        # Publish the passive dataset copy first; runner reads only the Env copy.
        targets = [DATASET_IMAGES_COPY, images_file]
    for target in targets:
        target.parent.mkdir(parents=True, exist_ok=True)
        temporary = target.with_suffix(target.suffix + ".tmp")
        temporary.write_text(content, encoding="utf-8", newline="\n")
        temporary.replace(target)


def image_references(image: str) -> list[str]:
    inspected = docker_inspect(image)
    payload = inspected.get("RepoTags")
    if payload is None:
        return []
    if not isinstance(payload, list) or not all(isinstance(item, str) for item in payload):
        raise RuntimeError(f"Unexpected Docker RepoTags for {image}: {payload!r}")
    return sorted(item for item in payload if not item.endswith(":<none>"))


def normalize_single_reference(image: str, keep: str) -> None:
    inspected = docker_inspect(image)
    image_id = str(inspected.get("Id") or "")
    keep_inspected = docker_inspect(keep)
    if str(keep_inspected.get("Id") or "") != image_id:
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


def task_image_references(task_id: str, canonical_repository: str) -> list[str]:
    result = run(
        ["docker", "image", "ls", "--format", "{{.Repository}}:{{.Tag}}"],
        capture=True,
    )
    task_slug = task_id.strip().lower()
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
    keep: str,
    mapped_references: set[str],
) -> None:
    repository = keep.rsplit(":", 1)[0]
    for reference in task_image_references(task_id, repository):
        if reference != keep and reference not in mapped_references:
            # A stopped Harbor container may still reference the old image ID.
            # Force only removes this obsolete tag; Docker retains the image
            # layers while the historical container still needs them.
            run(["docker", "image", "rm", "--force", reference])


def formalize_image_reference(image: str) -> str:
    inspected = docker_inspect(image)
    raw_image_id = str(inspected.get("Id") or "")
    image_id = raw_image_id.removeprefix("sha256:").lower()
    if len(image_id) != 64 or any(character not in "0123456789abcdef" for character in image_id):
        raise RuntimeError(f"Unexpected Docker Image ID for {image}: {raw_image_id!r}")
    repository = image.rsplit(":", 1)[0]
    formal = f"{repository}:{image_id[:16]}"
    if formal != image:
        run(["docker", "tag", image, formal])
    normalize_single_reference(formal, formal)
    if formal != image:
        print(f"[rename] {image} -> {formal}", flush=True)
    return formal


def inspect_tools(image: str) -> dict[str, str | None]:
    script = r"""
for tool in node npm codex uv uvx rg; do
    if command -v "$tool" >/dev/null 2>&1; then
        path="$(command -v "$tool")"
        version="$("$tool" --version 2>/dev/null | head -n 1 || true)"
        printf '%s\t%s\t%s\n' "$tool" "$path" "$version"
    else
        printf '%s\t\t\n' "$tool"
    fi
done
"""
    result = run(
        ["docker", "run", "--rm", "--entrypoint", "sh", image, "-c", script],
        capture=True,
    )
    tools: dict[str, str | None] = {}
    for line in result.stdout.splitlines():
        fields = line.split("\t", 2)
        if len(fields) != 3:
            continue
        name, path, version = fields
        tools[name] = f"{path} ({version or 'version unknown'})" if path else None
    missing = {"node", "npm", "codex", "uv", "uvx", "rg"} - set(tools)
    if missing:
        raise RuntimeError(
            f"Unable to inspect tools in {image}; missing probe output: "
            + ", ".join(sorted(missing))
        )
    return tools


def print_tool_status(task_id: str, image: str, tools: dict[str, str | None]) -> None:
    print(f"[inspect] {task_id}: {image}", flush=True)
    for name in ("node", "npm", "codex", "uv", "uvx", "rg"):
        value = tools[name]
        print(f"  {name}: {value or 'missing'}", flush=True)


def inspect_suricata_environment(image: str) -> tuple[bool, bool]:
    command = (
        "if command -v suricata >/dev/null 2>&1 && "
        "command -v rpm >/dev/null 2>&1 && "
        "rpm -q curl-minimal >/dev/null 2>&1 && "
        "test -x /opt/node22/bin/node && "
        "test -x /opt/claude-code/bin/claude; then "
        "  claude --version >/dev/null 2>&1 && exit 0; "
        "  exit 1; "
        "fi; "
        "exit 2"
    )
    result = run(
        ["docker", "run", "--rm", "--entrypoint", "sh", image, "-c", command],
        capture=True,
        check=False,
    )
    if result.returncode == 2:
        return False, False
    return True, result.returncode == 0


def validate_image(
    image: str,
    task_id: str,
    *,
    validate_suricata: bool,
) -> None:
    command = (
        "set -eu; "
        'printf "node=%s\\n" "$(node --version)"; '
        'printf "npm=%s\\n" "$(npm --version)"; '
        'printf "codex=%s\\n" "$(codex --version)"; '
        'printf "uv=%s\\n" "$(uv --version)"; '
        'printf "uvx=%s\\n" "$(uvx --version)"; '
        'printf "rg=%s\\n" "$(rg --version | head -n 1)"'
    )
    run(["docker", "run", "--rm", "--entrypoint", "sh", image, "-c", command])

    if validate_suricata:
        special_check = (
            "set -eu; "
            "command -v suricata >/dev/null; "
            "rpm -q curl-minimal; "
            'test "$(/opt/node22/bin/node --version)" = "v22.12.0"; '
            "test -x /usr/local/bin/claude; "
            'claude_version="$(claude --version)"; '
            'printf "suricata_node=%s\\n" "$(/opt/node22/bin/node --version)"; '
            'printf "active_node=%s\\n" "$(node --version)"; '
            'printf "claude=%s\\n" "$claude_version"'
        )
        run(
            [
                "docker",
                "run",
                "--rm",
                "--entrypoint",
                "sh",
                image,
                "-c",
                special_check,
            ]
        )


def remove_old_dangling_image(image_id: str) -> None:
    inspected = run(
        [
            "docker",
            "image",
            "inspect",
            image_id,
            "--format",
            "{{json .RepoTags}}",
        ],
        capture=True,
        check=False,
    )
    if inspected.returncode != 0:
        return
    if inspected.stdout.strip() not in {"null", "[]"}:
        return
    removed = run(
        ["docker", "image", "rm", image_id],
        capture=True,
        check=False,
    )
    if removed.returncode == 0:
        print(f"[cleanup] removed old untagged image {image_id}", flush=True)
    else:
        print(
            f"[cleanup-skip] Docker retained old image {image_id}: "
            f"{removed.stderr.strip()}",
            flush=True,
        )


def promote_staging_image(
    staging_image: str,
    original_image: str,
    original_image_id: str,
) -> str:
    staged = docker_inspect(staging_image)
    staged_image_id = str(staged.get("Id") or "")
    normalized_id = staged_image_id.removeprefix("sha256:").lower()
    if len(normalized_id) != 64 or any(
        character not in "0123456789abcdef" for character in normalized_id
    ):
        raise RuntimeError(
            f"Unexpected Docker Image ID for {staging_image}: {staged_image_id!r}"
        )
    repository = original_image.rsplit(":", 1)[0]
    formal = f"{repository}:{normalized_id[:16]}"
    try:
        run(["docker", "tag", staging_image, formal])
        normalize_single_reference(formal, formal)
    except (RuntimeError, subprocess.CalledProcessError):
        if formal != original_image:
            run(["docker", "image", "rm", formal], capture=True, check=False)
        raise
    finally:
        run(
            ["docker", "image", "rm", staging_image],
            capture=True,
            check=False,
        )
    if original_image != formal:
        run(["docker", "image", "rm", original_image], capture=True, check=False)
    remove_old_dangling_image(original_image_id)
    return formal


def install_missing_tools(
    task_id: str,
    image: str,
) -> str:
    inspected = docker_inspect(image)
    old_image_id = str(inspected["Id"])
    original_user = str((inspected.get("Config") or {}).get("User") or "root")
    tools = inspect_tools(image)
    suricata_detected, claude_works = inspect_suricata_environment(image)
    validate_suricata = task_id == "suricata-custom-exfil" or suricata_detected
    print_tool_status(task_id, image, tools)

    missing = [name for name, value in tools.items() if value is None]
    if validate_suricata and not claude_works:
        missing.append("claude-entrypoint")
    if not missing:
        validate_image(image, task_id, validate_suricata=validate_suricata)
        print(f"[skip] {task_id}: all required tools already exist", flush=True)
        return formalize_image_reference(image)

    print(f"[install] {task_id}: missing {', '.join(missing)}", flush=True)
    staging_image = f"benchmark-agent-install-staging:{uuid.uuid4().hex}"
    try:
        run(
            [
                "docker",
                "build",
                "--pull=false",
                "--file",
                str(INSTALL_DOCKERFILE),
                "--build-arg",
                f"BASE_IMAGE={image}",
                "--build-arg",
                f"FINAL_USER={original_user}",
                "--tag",
                staging_image,
                str(IMAGE_ROOT),
            ]
        )
        validate_image(
            staging_image,
            task_id,
            validate_suricata=validate_suricata,
        )
        formal = promote_staging_image(staging_image, image, old_image_id)
    except (RuntimeError, subprocess.CalledProcessError):
        run(
            ["docker", "image", "rm", staging_image],
            capture=True,
            check=False,
        )
        raise

    print(f"[ready] {task_id}: {formal}", flush=True)
    return formal


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description=(
            "Install missing Node.js, Codex CLI, uv/uvx, and ripgrep directly into "
            "existing task image names."
        )
    )
    source = parser.add_mutually_exclusive_group()
    source.add_argument(
        "--images-file",
        type=Path,
        default=DEFAULT_IMAGES_FILE,
        help=(
            "JSON task-to-image mapping file. "
            f"Defaults to {DEFAULT_IMAGES_FILE}"
        ),
    )
    source.add_argument(
        "--image",
        action="append",
        help="Process this exact local Docker image name. May be repeated.",
    )
    parser.add_argument(
        "--task",
        action="append",
        help="With --images-file, process only this task. May be repeated.",
    )
    parser.add_argument(
        "--audit",
        action="store_true",
        help="Check the selected images without building them.",
    )
    return parser.parse_args()


def select_images(args: argparse.Namespace) -> dict[str, str]:
    if args.image:
        if args.task:
            raise ValueError("--task can only be used together with --images-file")
        return {image: image for image in dict.fromkeys(args.image)}

    images_file = args.images_file.resolve()
    tasks = load_images(images_file)
    if not args.task:
        return tasks

    selected = set(args.task)
    missing = sorted(selected - set(tasks))
    if missing:
        raise ValueError(
            f"Unknown task(s) in {images_file}: {', '.join(missing)}"
        )
    return {task: image for task, image in tasks.items() if task in selected}


def main() -> int:
    args = parse_args()
    tasks = select_images(args)
    validate_packages()

    if args.audit:
        for task_id, image in sorted(tasks.items()):
            inspected = docker_inspect(image)
            raw_image_id = str(inspected.get("Id") or "")
            image_id = raw_image_id.removeprefix("sha256:").lower()
            expected = f"{image.rsplit(':', 1)[0]}:{image_id[:16]}"
            if image != expected:
                raise RuntimeError(
                    f"Mapped image name does not match its Image ID: "
                    f"task={task_id} mapping={image} expected={expected}"
                )
            references = image_references(image)
            if references != [image]:
                raise RuntimeError(
                    f"Mapped image must have exactly one tag: "
                    f"task={task_id} mapping={image} references={references}"
                )
            if not args.image:
                related = task_image_references(task_id, image.rsplit(":", 1)[0])
                if related != [image]:
                    raise RuntimeError(
                        f"Task must have exactly one image: task={task_id} "
                        f"mapping={image} task_references={related}"
                    )
            tools = inspect_tools(image)
            suricata_detected, claude_works = inspect_suricata_environment(image)
            validate_suricata = task_id == "suricata-custom-exfil" or suricata_detected
            print_tool_status(task_id, image, tools)
            missing = [name for name, value in tools.items() if value is None]
            if validate_suricata and not claude_works:
                missing.append("claude-entrypoint")
            if missing:
                raise RuntimeError(
                    f"{image} is missing required tools: {', '.join(missing)}"
                )
            validate_image(image, task_id, validate_suricata=validate_suricata)
            print(f"[audited] {task_id}: {image}", flush=True)
        print(f"[audit-complete] verified {len(tasks)} image(s)", flush=True)
        return 0

    full_mapping = None if args.image else load_images(args.images_file.resolve())
    for task_id, image in sorted(tasks.items()):
        formal = install_missing_tools(task_id, image)
        if full_mapping is not None:
            full_mapping[task_id] = formal
            write_images(args.images_file.resolve(), full_mapping)
            remove_other_task_images(task_id, formal, set(full_mapping.values()))
            print(f"[mapped] {task_id}: {formal}", flush=True)
    print(f"[complete] processed {len(tasks)} image(s)", flush=True)
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError, RuntimeError, subprocess.CalledProcessError) as exc:
        print(f"[error] {type(exc).__name__}: {exc}", file=sys.stderr)
        raise SystemExit(1)
