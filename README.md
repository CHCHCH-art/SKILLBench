# SKILLBench

SKILLBench 提供 Benchmark 构建、Skill 分组、运行执行和基础验证所需的数据与工具。
仓库包含 Benchmark Task、Standard/High Cost Route 的设计快照、Task-Skill Mapping、
Harbor Runner、端到端运行记录，以及 Task Solution 的重复验证数据。

## 项目概览

仓库覆盖以下 Benchmark 构建与验证环节：

- 保存 Standard Route 与 High Cost Route 对应的 Task Solution 和 Skill 设计快照；
- 将每个 Task 的 Skill 整理为 Standard、High Cost 和 Selected 三类可执行输入；
- 在统一的 Task 镜像和 Harbor Agent 环境中运行不同 Skill 条件；
- 记录通过情况、阶段耗时、峰值内存、Token、LLM 成本和 Skill 加载信息；
- 重复运行 Task Solution，验证设计结果的正确性、稳定性和基础资源开销；
- 构建 Skill 质量评分所需的数据组件、数据集和索引。

主要数据构建与验证关系如下：

```text
Route 设计快照
├── Base  ──> Standard Route ──> standard.jsonl ──> Standard 运行
└── Used  ──> High Cost Route ─> high_cost.jsonl ─> High Cost 运行

Standard Route Skill + High Cost Route Skill + 34k-skills 可复现噪声采样
└── random_selected.jsonl（每个 Task 固定 10 个 Skill）──> Mixed 运行
```

### 路线与目录名称对照

| 含义 | 快照目录名称 | Mapping 名称 | Runner 条件 |
| --- | --- | --- | --- |
| Standard Route | `Base` / `baseline_task` | `standard.jsonl` | `--mapping-file PATH` |
| High Cost Route | `Used` / `used_task` | `high_cost.jsonl` | `--mapping-file PATH` |
| 混合候选集合 | — | `random_selected.jsonl` | `--mapping-file PATH` |
| 无 Skill 对照 | — | — | `--no-skill` |

`Base` 和 `Used` 是构建快照中的物理目录名，分别对应 Standard Route
和 High Cost Route。二者不是“未使用/已使用”的简单运行状态。

## 环境配置

以下命令均从项目根目录运行。

### 环境要求

- Conda 与 Python 3.12；
- Git；
- Docker Desktop，已启动并切换到 Linux 容器；
- 兼容 CUDA 11.8 的 NVIDIA GPU 与驱动（仅在使用相关 GPU 任务或工具时需要）；
- 可访问的 OpenAI-compatible API；
- 足够的本地磁盘空间用于 Task 镜像、运行工作区和实验结果。

### 创建 Conda 环境

本仓库使用名为 `qwen` 的 Conda 环境。创建环境并安装当前验证过的依赖：

```powershell
conda create -n qwen python=3.12 -y
conda activate qwen

python -m pip install torch==2.5.1 torchvision==0.20.1 torchaudio==2.5.1 `
  --index-url https://download.pytorch.org/whl/cu118
python -m pip install harbor==0.17.1 transformers==5.12.1 `
  sentence-transformers==5.6.0 openpyxl==3.1.5 PyYAML==6.0.3 `
  psutil==7.2.2 numpy==2.4.4 scikit-learn==1.9.0
```

`benchmark/Env/requirement.txt` 是早期安装命令备忘，不是可直接用于
`pip install -r` 的锁定依赖文件。请以上述安装步骤为准。

### 安装自定义 Harbor Agent

自定义 Agent 位于 `benchmark/Env/src`，以 editable 方式安装：

```powershell
python -m pip install -e .\benchmark\Env
```

Agent 入口为：

```text
my_agents.dmx_codex:DMXCodex
```

### API 配置

Runner 优先读取环境变量 `OPENAI_API_KEY` 和 `OPENAI_BASE_URL`。也可以创建本地文件
`benchmark/Env/local/API.jsonl`：

```json
{"api_key":"YOUR_API_KEY","base_url":"https://your-openai-compatible-endpoint/v1"}
```

还可以通过 `BENCHMARK_API_CONFIG` 指定其他配置文件。API 配置属于本地凭据，不应
提交到版本库。

### 准备 Task Docker 镜像

统一入口是 `benchmark/Env/images/prepare_task_images.py`。它会先复用或构建 Task
镜像，再安装并验证 Node.js、npm、Codex CLI、uv/uvx 和 ripgrep，最后更新
`benchmark/Env/task_images.json`。

```powershell
# 预览，不修改镜像
python .\benchmark\Env\images\prepare_task_images.py --dry-run

# 准备所有缺失或未映射的 Task 镜像
python .\benchmark\Env\images\prepare_task_images.py

# 审计镜像映射与公共工具
python .\benchmark\Env\images\prepare_task_images.py --audit
```

普通 Benchmark 运行只复用映射中已经存在的本地镜像，不会自动下载、构建或重新
打标签。Dockerfile 或公共工具变化后，可使用 `--force` 强制重建：

```powershell
python .\benchmark\Env\images\prepare_task_images.py --force
```

`benchmark/Env/task_images.json` 是 Runner 使用的权威映射；
`data/datasets/task_images.json` 只是同步生成的数据副本。

## 项目结构

```text
SKILLBench/
├── benchmark/
│   ├── datas/
│   │   ├── tasks/                    # 当前 Benchmark Task
│   │   ├── single_skill_mapping/     # Task 到 Skill 的映射表
│   │   └── optional_skills/skills/   # Runner 使用的统一 Skill 实体库
│   ├── Env/
│   │   ├── src/my_agents/            # 自定义 Harbor Agent
│   │   ├── images/                   # Task 镜像准备、补丁和审计工具
│   │   └── task_images.json          # Task ID 到本地镜像的权威映射
│   └── runner/
│       ├── run_baseline.py           # No Skill、Standard、High Cost、Selected 等入口
│       ├── rerun_error.py            # 失败任务重跑入口
│       └── runtime/                   # 工作目录与 Harbor 运行结果
├── archive_local/
│   ├── Snaps/
│   │   ├── Task_snap/                # Standard/High Cost Route 的 Task 设计快照
│   │   └── Skills_snap/              # 两条 Route 对应的 Skill 设计快照
│   ├── task_solution_validation/      # Task Solution 重复运行与开销验证代码
│   └── ALL-34K-SKILLS/                # Selected 噪声 Skill 的来源快照
├── scoring/skill_quality/             # Skill 质量筛选与分层工具
└── data/
    ├── components/                    # Standard、High Cost、Random 等数据组件
    ├── datasets/                      # 可重建数据集
    └── indexes/                       # 与数据集对应的可重建索引
```

## 关键数据与实验产物

### Route 设计快照：`archive_local/Snaps`

`archive_local/Snaps` 保存路线设计阶段的 Task 与 Skill 快照：

- `Task_snap/baseline_task`：Base，即 Standard Route 的 Task 设计；
- `Task_snap/used_task`：Used，即 High Cost Route 的 Task 设计；
- 每个 Task 的 `solution/` 是该 Route 对应的设计结果；
- `Skills_snap/Base`：Standard Route 对应的 Skill 设计；
- `Skills_snap/Used`：High Cost Route 对应的 Skill 设计。

这些快照用于解释路线是如何设计出来的，不应与 Runner 临时复制到 `runtime/work`
中的执行目录混淆。详细说明见
[`archive_local/Snaps/README.md`](archive_local/Snaps/README.md)。

### Skill 映射：`benchmark/datas/single_skill_mapping`

当前 Mapping 包含 35 个 Task，由三个 JSONL 文件声明 Task 到 Skill 的引用：

| 文件 | 内容 | 用途 |
| --- | --- | --- |
| `standard.jsonl` | Standard Route 对应的 Skill | Standard 基线 |
| `high_cost.jsonl` | High Cost Route 对应的 Skill | High Cost 基线 |
| `random_selected.jsonl` | 上述两组的并集，加来自 34k-skills 的可复现噪声采样 | Mixed/Selected 实验 |

每个 Task 的 `Selected` 固定为 10 个 Skill。噪声数量
`N = 10 - Standard Skill 数 - High Cost Skill 数`，因此不同 Task 的 `N` 可以不同。
当前映射总计包含 86 个 Standard、86 个 High Cost 和 350 个 Selected 引用。
Skill 实体只保存在 `benchmark/datas/optional_skills/skills`。

详细结构与约束见
[`benchmark/datas/single_skill_mapping/Readme.md`](benchmark/datas/single_skill_mapping/Readme.md)。

### Harbor 运行结果：`benchmark/runner/runtime/runs`

Runner 的每次执行会记录 Task 是否通过、阶段耗时、峰值内存、LLM 成本、输入/输出
Token、镜像复用状态，以及提供、可见和实际加载的 Skill 审计信息。

当前基础验证结果按模型和运行条件整理为：

- `Ds-V4-Flash`：DeepSeek V4 Flash 的 No Skill、Standard 和 High Cost 结果；
- `GPT`：GPT 系列模型的 No Skill、Standard 和 High Cost 结果；
- `Mixed`：`Selected` Skill 集合的结果，包含 `Deepseek-V4-Flash` 与
  `GPT-5.6-luna-cdx` 两个模型。

Mixed 结果提供 Skills Loaded 检查数据：可比较 `provided_skills`、
`available_skills`、`loaded_skills` 和 `load_evidence`，确认候选 Skill 的注入、可见
与实际加载情况。
详细说明见
[`benchmark/runner/runtime/runs/README.md`](benchmark/runner/runtime/runs/README.md)。

### Task Solution 重复验证：`archive_local/task_solution_validation`

该目录保存不经过 Harbor Agent、直接重复运行 Task `solution/solve.sh` 与测试的验证
代码。它比较 `baseline_task` 与 `used_task` 中对应 Solution 的运行结果，用于验证
Route 设计结果是否正确，并估计 Standard/High Cost Route 的时间与内存开销。

`benchmark-run-logs/<timestamp>/` 保存一次验证批次：

- `batch_manifest.json`：输入快照、运行次数和资源预算；
- `logs/`：每个 Task、每类 Route、每次运行的原始日志；
- `runs.csv`：逐次运行的状态、通过情况、耗时、内存与退出码；
- `summary.csv`：按 Task 和 Route 聚合后的均值、最小值、最大值与通过次数。

详细说明见
[`archive_local/task_solution_validation/Readme.md`](archive_local/task_solution_validation/Readme.md)。

## 运行 Benchmark

Runner 默认读取 `benchmark/datas/tasks` 和已经准备好的本地镜像映射；Skill 模式
必须显式传入映射文件。

```powershell
# 无 Skill 对照
python .\benchmark\runner\run_baseline.py --no-skill

# Standard Route
python .\benchmark\runner\run_baseline.py --mapping-file `
  .\benchmark\datas\single_skill_mapping\standard.jsonl

# High Cost Route
python .\benchmark\runner\run_baseline.py --mapping-file `
  .\benchmark\datas\single_skill_mapping\high_cost.jsonl

# Standard + High Cost + 噪声 Skill，共 10 个
python .\benchmark\runner\run_baseline.py --mapping-file `
  .\benchmark\datas\single_skill_mapping\random_selected.jsonl
```

运行单个 Task 并重复三次：

```powershell
python .\benchmark\runner\run_baseline.py `
  --mapping-file .\benchmark\datas\single_skill_mapping\random_selected.jsonl `
  --task weighted-gdp-calc `
  --repeat 3
```

Runner 默认最多并行执行 2 个轻量 Task。可显式调整调度资源：

```powershell
python .\benchmark\runner\run_baseline.py `
  --mapping-file .\benchmark\datas\single_skill_mapping\standard.jsonl `
  --task-workers 2 `
  --max-parallel-cpus 16 `
  --max-parallel-memory-mib 24576
```

更完整的调度、重跑和结果结构说明见
[`benchmark/runner/Readme.md`](benchmark/runner/Readme.md)。

## 验证 Task Solution

直接比较 Standard Route 与 High Cost Route 的 Solution，默认每类连续运行三次：

```powershell
python .\archive_local\task_solution_validation\benchmark_repeated_runs.py
```

只验证指定 Task：

```powershell
python .\archive_local\task_solution_validation\benchmark_repeated_runs.py `
  --tasks weighted-gdp-calc dialogue-parser `
  --runs 3
```

## 测试

Runner 与 Skill 质量流水线的主要单元测试：

```powershell
python -m unittest discover -s .\benchmark\runner\tests -v
python -m unittest discover -s .\scoring\skill_quality\tests -v
```

## 数据与版本控制约束

- `benchmark/datas` 是 Benchmark 的版本化输入；
- `data/components` 是数据集构建来源，修改后应重新构建 `data/datasets` 与
  `data/indexes`；
- `benchmark/runner/runtime` 是运行产物，不应作为程序输入；
- `archive_local` 保存 Benchmark 构建阶段的设计快照与基础验证档案；
- `.venv`、Python 缓存、运行工作区、API 配置和其他本地凭据不得提交；
- README 中使用相对路径，运行记录中的绝对路径只代表当次实验环境，不应被代码
  当作固定输入路径。

## 文档索引

- [Benchmark Runner](benchmark/runner/Readme.md)
- [环境与镜像准备](benchmark/Env/README.md)
- [镜像工具说明](benchmark/Env/images/README.md)
- [Single Skill Mapping](benchmark/datas/single_skill_mapping/Readme.md)
- [Route 设计快照](archive_local/Snaps/README.md)
- [Task Solution 重复验证](archive_local/task_solution_validation/Readme.md)
- [Skill 质量流水线](scoring/skill_quality/README.md)
