import json
import os
import re
import sys
import time
import traceback
from concurrent.futures import ThreadPoolExecutor, as_completed
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path
from threading import Lock
from typing import Any, Dict, List, Optional, Tuple

from openai import OpenAI, APIConnectionError, APITimeoutError


PROCESS_ROOT = Path(__file__).resolve().parent
DEFAULT_API_CONFIG = PROCESS_ROOT / "API.jsonl"


def load_api_config() -> Dict[str, str]:
    config_path = Path(
        os.environ.get("DEEPSEEK_API_CONFIG", str(DEFAULT_API_CONFIG))
    ).expanduser().resolve()
    if not config_path.is_file():
        raise FileNotFoundError(f"API config not found: {config_path}")

    config: Dict[str, Any] = {}
    for raw_line in config_path.read_text(encoding="utf-8-sig").splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#"):
            continue
        parsed = json.loads(line)
        if not isinstance(parsed, dict):
            raise ValueError(f"Expected a JSON object in {config_path}")
        config = parsed
        break

    normalized = {
        str(key).strip().lower().replace("-", "_"): str(value).strip()
        for key, value in config.items()
        if value is not None
    }
    required_fields = ("api_key", "base_url", "model")
    missing = [field for field in required_fields if not normalized.get(field)]
    if missing:
        raise ValueError(
            f"Missing required API config field(s) in {config_path}: {', '.join(missing)}"
        )
    return {field: normalized[field] for field in required_fields}


API_CONFIG = load_api_config()
DEEPSEEK_API_KEY = API_CONFIG["api_key"]
DEEPSEEK_BASE_URL = API_CONFIG["base_url"]
DEEPSEEK_MODEL = API_CONFIG["model"]

PROMPT_FILE = PROCESS_ROOT / "prompts" / "skill_description.txt"
OUTPUT_NAME = "skill_llm_describe.json"
DEFAULT_FAIL_LOG = None

TEMPERATURE = 0.1
MAX_TOKENS = 2048

NETWORK_RETRY_SLEEP_SECONDS = 20

MAX_SKILL_MD_CHARS = 500_000
CONTROL_CHAR_RATIO_LIMIT = 0.05

IGNORE_DIRS = {
    ".git",
    "__pycache__",
    ".venv",
    "venv",
    "node_modules",
    ".idea",
    ".vscode",
    "dist",
    "build",
}

EXCLUDE_FILE_NAMES = {
    "Base Describe.md",
    "Base_Describe.md",
    OUTPUT_NAME,
}

BASE_DESCRIBE_CANDIDATES = [
    "Base Describe.md",
    "Base_Describe.md",
]

EXPECTED_FIELDS = [
    "task_tags",
    "service_cost_score",
    "service_safety_score",
]

FAIL_LOG: Path = DEFAULT_FAIL_LOG

log_lock = Lock()
print_lock = Lock()


@dataclass
class ProcessResult:
    ok: bool
    network_retry: bool
    suffix: int
    skill_id: str
    skill_dir: Path
    error_type: str = ""
    error_message: str = ""


def now_iso() -> str:
    return datetime.now().isoformat(timespec="seconds")


def clean_input_path(raw: str) -> Path:
    raw = raw.strip().strip('"').strip("'")
    return Path(raw).expanduser().resolve()


def has_excessive_control_chars(text: str) -> bool:
    if not text:
        return False

    control_count = sum(
        1
        for char in text
        if ord(char) < 32 and char not in "\t\n\r"
    )
    return control_count / len(text) > CONTROL_CHAR_RATIO_LIMIT


def clean_text_content(text: str) -> str:
    return "".join(
        char
        for char in text
        if not (ord(char) < 32 and char not in "\t\n\r")
    )


def is_binary_file(path: Path, sample_size: int = 8192) -> bool:
    try:
        data = path.read_bytes()[:sample_size]
    except Exception:
        return True

    if not data:
        return False

    if b"\x00" in data:
        # Allow lightly corrupted text while rejecting control-heavy binaries.
        for encoding in ["utf-8", "utf-8-sig", "gb18030", "big5"]:
            try:
                text = data.decode(encoding)
                return has_excessive_control_chars(text)
            except UnicodeDecodeError:
                continue
        return True

    # Accept common Chinese encodings before treating a file as binary.
    for encoding in ["utf-8", "utf-8-sig", "gb18030", "big5", "latin-1"]:
        try:
            data.decode(encoding)
            return False
        except UnicodeDecodeError:
            continue

    return True


def read_text_file(path: Path, max_chars: int) -> Optional[str]:
    if not path.exists() or not path.is_file():
        return None

    if is_binary_file(path):
        return None

    encodings = ["utf-8", "utf-8-sig", "gb18030", "big5", "latin-1"]

    for encoding in encodings:
        try:
            text = path.read_text(encoding=encoding, errors="strict")
            original_length = len(text)
            text = clean_text_content(text)
            if len(text) > max_chars:
                return text[:max_chars] + f"\n\n[TRUNCATED: original length {original_length} characters]"
            return text
        except Exception:
            continue

    try:
        text = path.read_text(encoding="utf-8", errors="replace")
        original_length = len(text)
        text = clean_text_content(text)
        if len(text) > max_chars:
            return text[:max_chars] + f"\n\n[TRUNCATED: original length {original_length} characters]"
        return text
    except Exception:
        return None


def get_base_describe_path(skill_dir: Path) -> Path:
    for filename in BASE_DESCRIBE_CANDIDATES:
        candidate = skill_dir / filename
        if candidate.exists() and candidate.is_file():
            return candidate
    raise FileNotFoundError("Base Describe.md / Base_Describe.md is missing")


def extract_skill_id(base_describe_path: Path) -> str:
    text = read_text_file(base_describe_path, max_chars=20_000)
    if not text:
        raise ValueError("Base Describe.md is missing or unreadable")

    match = re.search(r"(?im)^\s*skill_id\s*:\s*(.+?)\s*$", text)
    if not match:
        raise ValueError("Cannot extract skill_id from Base Describe.md")

    return match.group(1).strip()


def parse_base_describe_stats(base_describe_path: Path) -> Dict[str, Any]:
    text = read_text_file(base_describe_path, max_chars=20_000)
    if not text:
        raise ValueError("Base Describe.md is missing or unreadable")

    raw_values: Dict[str, str] = {}
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line or line.startswith("#") or ":" not in line:
            continue
        key, value = line.split(":", 1)
        key = key.strip()
        if key in {"num_files", "num_scripts", "total_size_kb"}:
            raw_values[key] = value.strip()

    missing = [
        key
        for key in ("num_files", "num_scripts", "total_size_kb")
        if key not in raw_values
    ]
    if missing:
        raise ValueError(f"Base Describe.md missing stats: {', '.join(missing)}")

    try:
        num_files = int(raw_values["num_files"])
        num_scripts = int(raw_values["num_scripts"])
        total_size_kb = float(raw_values["total_size_kb"])
    except ValueError as exc:
        raise ValueError(f"Base Describe.md has invalid stats: {exc}") from exc

    return {
        "num_files": num_files,
        "num_scripts": num_scripts,
        "total_size_kb": total_size_kb,
    }


def extract_skill_suffix(skill_id: str) -> int:
    match = re.search(r"-(\d+)\s*$", skill_id)
    if not match:
        raise ValueError(f"Cannot extract numeric suffix from skill_id: {skill_id}")
    return int(match.group(1))


def should_ignore_path(path: Path, skill_dir: Path) -> bool:
    try:
        rel_parts = path.relative_to(skill_dir).parts
    except ValueError:
        return True

    if any(part in IGNORE_DIRS for part in rel_parts):
        return True

    if path.name in EXCLUDE_FILE_NAMES:
        return True

    return False


def iter_files(skill_dir: Path) -> List[Path]:
    files = []

    for path in skill_dir.rglob("*"):
        if not path.is_file():
            continue
        if should_ignore_path(path, skill_dir):
            continue
        files.append(path)

    return sorted(files, key=lambda p: p.relative_to(skill_dir).as_posix().lower())


def build_package(skill_dir: Path) -> Dict[str, Any]:
    skill_md_path = skill_dir / "SKILL.md"
    if not skill_md_path.exists():
        raise FileNotFoundError("SKILL.md is missing")

    skill_md = read_text_file(skill_md_path, max_chars=sys.maxsize)
    if skill_md is None:
        raise ValueError("SKILL.md is unreadable or binary")

    base_stats = parse_base_describe_stats(get_base_describe_path(skill_dir))
    file_tree: List[str] = ["SKILL.md"]

    all_files = iter_files(skill_dir)

    for file_path in all_files:
        rel_path = file_path.relative_to(skill_dir).as_posix()

        # SKILL.md has a dedicated payload field.
        if rel_path == "SKILL.md":
            continue

        file_tree.append(rel_path)

    return {
        "file_tree": file_tree,
        "skill_md": skill_md,
        **base_stats,
    }


def extract_json_object(text: str) -> Dict[str, Any]:
    text = text.strip()

    if text.startswith("```"):
        text = re.sub(r"^```(?:json)?\s*", "", text)
        text = re.sub(r"\s*```$", "", text)

    try:
        return json.loads(text)
    except json.JSONDecodeError:
        pass

    start = text.find("{")
    end = text.rfind("}")
    if start == -1 or end == -1 or end <= start:
        raise ValueError("No valid JSON object found in model output")

    return json.loads(text[start:end + 1])


def build_final_json(skill_id: str, model_json: Dict[str, Any]) -> Dict[str, Any]:
    expected = set(EXPECTED_FIELDS)
    actual = set(model_json)
    missing = sorted(expected - actual)
    extra = sorted(actual - expected)
    if missing:
        raise ValueError(f"Model output missing fields for {skill_id}: {', '.join(missing)}")
    if extra:
        raise ValueError(f"Model output has extra fields for {skill_id}: {', '.join(extra)}")

    final_data = {}
    for field in EXPECTED_FIELDS:
        final_data[field] = model_json[field]
    return final_data


def append_fail_log(
    skill_id: str,
    skill_dir: Path,
    error_type: str,
    error_message: str,
) -> None:
    record = {
        "timestamp": now_iso(),
        "skill_id": skill_id,
        "skill_dir": str(skill_dir),
        "error_type": error_type,
        "error_message": error_message,
    }

    with log_lock:
        FAIL_LOG.parent.mkdir(parents=True, exist_ok=True)
        with FAIL_LOG.open("a", encoding="utf-8") as f:
            f.write(json.dumps(record, ensure_ascii=False) + "\n")


def load_prompt() -> str:
    if not PROMPT_FILE.exists():
        raise FileNotFoundError(f"Prompt file not found: {PROMPT_FILE}")
    return PROMPT_FILE.read_text(encoding="utf-8", errors="replace")


def is_network_error(e: Exception) -> bool:
    """
    网络类错误单独进入重试队列。
    OpenAI SDK 常见连接失败是 APIConnectionError，超时是 APITimeoutError。
    """
    if isinstance(e, (APIConnectionError, APITimeoutError, ConnectionError, TimeoutError)):
        return True

    error_type = type(e).__name__.lower()
    error_message = str(e).lower()

    network_keywords = [
        "apiconnectionerror",
        "apitimeouterror",
        "connection error",
        "connect error",
        "connection refused",
        "connection reset",
        "connection aborted",
        "timed out",
        "timeout",
        "read timed out",
        "connect timeout",
        "remote protocol error",
        "network is unreachable",
        "temporary failure",
        "dns",
        "name resolution",
        "ssl",
        "proxy",
    ]

    return any(keyword in error_type or keyword in error_message for keyword in network_keywords)


def get_network_retry_index_path() -> Path:
    """
    网络错误索引文件。
    放在 fail log 同目录下。
    """
    return FAIL_LOG.with_name("network_retry_pending.json")


def save_network_retry_index(
    retry_items: List[Tuple[int, str, Path]],
    retry_round: int,
) -> None:
    records = [
        {
            "retry_round": retry_round,
            "suffix": suffix,
            "skill_id": skill_id,
            "skill_dir": str(skill_dir),
            "timestamp": now_iso(),
        }
        for suffix, skill_id, skill_dir in retry_items
    ]

    path = get_network_retry_index_path()
    with log_lock:
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(
            json.dumps(records, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )


def clear_network_retry_index() -> None:
    path = get_network_retry_index_path()
    with log_lock:
        if path.exists():
            path.unlink()


def call_deepseek(client: OpenAI, prompt_text: str, package: Dict[str, Any]) -> str:
    response = client.chat.completions.create(
        model=DEEPSEEK_MODEL,
        messages=[
            {
                "role": "system",
                "content": prompt_text,
            },
            {
                "role": "user",
                "content": json.dumps(package, ensure_ascii=False),
            },
        ],
        temperature=TEMPERATURE,
        max_tokens=MAX_TOKENS,
        response_format={"type": "json_object"},
        stream=False,
        extra_body={
            "thinking": {
                "type": "disabled"
            }
        },
    )

    return response.choices[0].message.content or ""


def collect_skill_dirs(root: Path) -> List[Tuple[int, str, Path]]:
    if not root.exists() or not root.is_dir():
        raise NotADirectoryError(f"Root directory does not exist or is not a directory: {root}")

    results: List[Tuple[int, str, Path]] = []

    for child in sorted(root.iterdir(), key=lambda p: p.name.lower()):
        if not child.is_dir():
            continue

        skill_id = "unknown"
        try:
            base_describe_path = get_base_describe_path(child)
            skill_id = extract_skill_id(base_describe_path)
            suffix = extract_skill_suffix(skill_id)
            results.append((suffix, skill_id, child))
        except Exception as e:
            append_fail_log(
                skill_id=skill_id,
                skill_dir=child,
                error_type="skill_id_error",
                error_message=str(e),
            )

    return sorted(results, key=lambda item: item[0])


def process_one_skill(
    prompt_text: str,
    suffix: int,
    skill_id: str,
    skill_dir: Path,
    dry_run: bool,
) -> ProcessResult:
    try:
        client = OpenAI(
            api_key=DEEPSEEK_API_KEY,
            base_url=DEEPSEEK_BASE_URL,
        )

        package = build_package(skill_dir)

        model_raw = call_deepseek(client, prompt_text, package)
        model_data = extract_json_object(model_raw)
        final_data = build_final_json(skill_id, model_data)

        if dry_run:
            with print_lock:
                print("\n" + "=" * 100)
                print(f"[DRY-RUN] skill_id={skill_id}, suffix={suffix}")
                print(f"skill_dir={skill_dir}")

                print("\n[MODEL INPUT PACKAGE]")
                print(json.dumps(package, ensure_ascii=False, indent=2))

                print("\n[MODEL RAW OUTPUT]")
                print(model_raw)

                print("\n[PARSED MODEL JSON]")
                print(json.dumps(model_data, ensure_ascii=False, indent=2))

                print("\n[FINAL JSON TO WRITE]")
                print(json.dumps(final_data, ensure_ascii=False, indent=2))

                print("=" * 100 + "\n")

            return ProcessResult(
                ok=True,
                network_retry=False,
                suffix=suffix,
                skill_id=skill_id,
                skill_dir=skill_dir,
            )

        output_path = skill_dir / OUTPUT_NAME
        output_path.write_text(
            json.dumps(final_data, ensure_ascii=False, indent=2),
            encoding="utf-8",
        )

        with print_lock:
            print(f"[OK] {skill_id} -> {output_path}")

        return ProcessResult(
            ok=True,
            network_retry=False,
            suffix=suffix,
            skill_id=skill_id,
            skill_dir=skill_dir,
        )

    except Exception as e:
        error_type = type(e).__name__
        error_message = str(e)

        if is_network_error(e):
            with print_lock:
                print(f"[NETWORK RETRY QUEUED] {skill_id}: {error_type}: {error_message}")

            return ProcessResult(
                ok=False,
                network_retry=True,
                suffix=suffix,
                skill_id=skill_id,
                skill_dir=skill_dir,
                error_type=error_type,
                error_message=error_message,
            )

        append_fail_log(
            skill_id=skill_id,
            skill_dir=skill_dir,
            error_type=error_type,
            error_message=error_message,
        )

        with print_lock:
            if dry_run:
                print("\n" + "=" * 100)
                print(f"[DRY-RUN FAIL] skill_id={skill_id}, suffix={suffix}")
                print(f"skill_dir={skill_dir}")
                print(f"error_type={error_type}")
                print(f"error_message={error_message}")
                print(traceback.format_exc())
                print("=" * 100 + "\n")
            else:
                print(f"[FAIL] {skill_id}: {error_type}: {error_message}")

        return ProcessResult(
            ok=False,
            network_retry=False,
            suffix=suffix,
            skill_id=skill_id,
            skill_dir=skill_dir,
            error_type=error_type,
            error_message=error_message,
        )


def run_one_round(
    skill_items: List[Tuple[int, str, Path]],
    prompt_text: str,
    dry_run: bool,
    concurrency: int,
    round_name: str,
) -> Tuple[int, int, List[Tuple[int, str, Path]]]:
    ok_count = 0
    fail_count = 0
    network_retry_items: List[Tuple[int, str, Path]] = []

    with print_lock:
        print("-" * 60)
        print(f"{round_name}: 待处理 {len(skill_items)} 个 SKILL")
        print("-" * 60)

    with ThreadPoolExecutor(max_workers=concurrency) as executor:
        future_to_skill = {
            executor.submit(
                process_one_skill,
                prompt_text,
                suffix,
                skill_id,
                skill_dir,
                dry_run,
            ): (suffix, skill_id, skill_dir)
            for suffix, skill_id, skill_dir in skill_items
        }

        for future in as_completed(future_to_skill):
            suffix, skill_id, skill_dir = future_to_skill[future]

            try:
                result = future.result()
            except Exception as e:
                error_type = type(e).__name__
                error_message = str(e)

                if is_network_error(e):
                    with print_lock:
                        print(f"[NETWORK RETRY QUEUED] {skill_id}: {error_type}: {error_message}")

                    network_retry_items.append((suffix, skill_id, skill_dir))
                    continue

                append_fail_log(
                    skill_id=skill_id,
                    skill_dir=skill_dir,
                    error_type=error_type,
                    error_message=error_message,
                )

                with print_lock:
                    print(f"[FAIL] {skill_id}: {error_type}: {error_message}")

                fail_count += 1
                continue

            if result.ok:
                ok_count += 1
            elif result.network_retry:
                network_retry_items.append((result.suffix, result.skill_id, result.skill_dir))
            else:
                fail_count += 1

    return ok_count, fail_count, network_retry_items


def ask_yes_no(prompt: str, default: bool = False) -> bool:
    suffix = "Y/n" if default else "y/N"
    raw = input(f"{prompt} ({suffix}): ").strip().lower()

    if not raw:
        return default

    return raw in {"y", "yes", "1", "true", "t"}


def ask_int_optional(prompt: str) -> Optional[int]:
    raw = input(prompt).strip()
    if not raw:
        return None
    return int(raw)


def ask_int_with_default(prompt: str, default: int) -> int:
    raw = input(f"{prompt}，直接回车则为 {default}: ").strip()
    if not raw:
        return default
    value = int(raw)
    if value < 1:
        raise ValueError("Value must be >= 1")
    return value


def main() -> None:
    global FAIL_LOG

    print("SKILL metadata extraction with DeepSeek V4")
    print("-" * 60)

    root_raw = input("请输入 SKILL 根目录: ")
    root = clean_input_path(root_raw)

    fail_log_raw = input(f"请输入失败日志路径，直接回车则使用默认路径 {DEFAULT_FAIL_LOG}: ").strip()
    if fail_log_raw:
        FAIL_LOG = clean_input_path(fail_log_raw)
    else:
        FAIL_LOG = DEFAULT_FAIL_LOG or (root / "skill_llm_failed.jsonl")

    start_suffix = ask_int_optional("请输入起始 skill_id 后缀编号，直接回车则从头开始: ")

    dry_run = ask_yes_no("是否 dry-run？dry-run 会调用 API，但不写盘，并打印模型输出", default=False)

    limit = ask_int_optional("请输入最多处理数量，直接回车则不限制: ")

    concurrency = ask_int_with_default("请输入并发数量", default=1)

    if not DEEPSEEK_API_KEY:
        print(f"请在 API 配置文件中填写 api_key: {DEFAULT_API_CONFIG}")
        sys.exit(1)

    prompt_text = load_prompt()

    skill_items = collect_skill_dirs(root)

    if start_suffix is not None:
        skill_items = [item for item in skill_items if item[0] >= start_suffix]

    if limit is not None:
        skill_items = skill_items[:limit]

    print(f"根目录: {root}")
    print(f"失败日志: {FAIL_LOG}")
    print(f"网络错误索引: {get_network_retry_index_path()}")
    print(f"待处理 SKILL 数量: {len(skill_items)}")
    if start_suffix is not None:
        print(f"起始后缀: {start_suffix}")
    print(f"dry-run: {dry_run}")
    print(f"模型: {DEEPSEEK_MODEL}")
    print(f"并发数量: {concurrency}")
    print("-" * 60)

    total_ok_count = 0
    total_fail_count = 0
    retry_round = 0
    network_retry_items: List[Tuple[int, str, Path]] = []

    try:
        ok_count, fail_count, network_retry_items = run_one_round(
            skill_items=skill_items,
            prompt_text=prompt_text,
            dry_run=dry_run,
            concurrency=concurrency,
            round_name="第一轮处理",
        )

        total_ok_count += ok_count
        total_fail_count += fail_count

        while network_retry_items:
            retry_round += 1

            save_network_retry_index(
                retry_items=network_retry_items,
                retry_round=retry_round,
            )

            with print_lock:
                print("-" * 60)
                print(f"第 {retry_round} 轮网络错误重试队列数量: {len(network_retry_items)}")
                print(f"网络错误索引已保存: {get_network_retry_index_path()}")
                print(f"{NETWORK_RETRY_SLEEP_SECONDS} 秒后开始重试。按 Ctrl+C 可手动中止。")
                print("-" * 60)

            time.sleep(NETWORK_RETRY_SLEEP_SECONDS)

            ok_count, fail_count, network_retry_items = run_one_round(
                skill_items=network_retry_items,
                prompt_text=prompt_text,
                dry_run=dry_run,
                concurrency=concurrency,
                round_name=f"网络错误重试第 {retry_round} 轮",
            )

            total_ok_count += ok_count
            total_fail_count += fail_count

        clear_network_retry_index()

        print("-" * 60)
        print(f"处理完成。OK={total_ok_count}, FAIL={total_fail_count}")
        print("网络错误队列已清空。")
        print(f"失败日志: {FAIL_LOG}")

    except KeyboardInterrupt:
        if network_retry_items:
            save_network_retry_index(
                retry_items=network_retry_items,
                retry_round=retry_round,
            )
            print("\n手动中止。当前网络错误队列已保存。")
            print(f"网络错误索引: {get_network_retry_index_path()}")
        else:
            print("\n手动中止。当前没有待保存的网络错误队列。")
        sys.exit(130)


if __name__ == "__main__":
    main()
