from pathlib import Path


RUNNER_ROOT = Path(__file__).resolve().parent
BENCHMARK_ROOT = RUNNER_ROOT.parent
PROJECT_ROOT = BENCHMARK_ROOT.parent

DATAS_ROOT = BENCHMARK_ROOT / "datas"
DEFAULT_TASKS_ROOT = DATAS_ROOT / "tasks"
DEFAULT_MAPPING_ROOT = DATAS_ROOT / "single_skill_mapping"

ENV_ROOT = BENCHMARK_ROOT / "Env"
AGENT_SRC_ROOT = ENV_ROOT / "src"
DEFAULT_API_CONFIG = ENV_ROOT / "local" / "API.jsonl"
TASK_IMAGES_FILE = ENV_ROOT / "task_images.json"

SINK_DOCKER_ROOT = RUNNER_ROOT / "sink_network"

RUNTIME_ROOT = RUNNER_ROOT / "runtime"
WORK_ROOT = RUNTIME_ROOT / "work"
# Keep Harbor's staged tasks directly under the work root.  The shorter path
# stays below Windows MAX_PATH when dirhash/scantree reopens task files without
# an extended-length prefix.
CURRENT_TASKS_ROOT = WORK_ROOT
RUNS_ROOT = RUNTIME_ROOT / "runs"
