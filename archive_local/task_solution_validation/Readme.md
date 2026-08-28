# Task Solution 重复运行验证

本目录保存 Route 设计结果的独立验证工具。它不调用 Harbor Agent，而是在 Task
Docker 环境中直接运行 `solution/solve.sh` 和 Verifier，对比 Standard Route 与
High Cost Route 的正确性和资源开销。

## 默认输入

| 参数 | 默认目录 | 含义 |
| --- | --- | --- |
| `--tasks-root` | `../Snaps/Task_snap/baseline_task` | Base / Standard Route Task |
| `--used-root` | `../Snaps/Task_snap/used_task` | Used / High Cost Route Task |

同名 Task 会组成一对：

- `baseline` 来源运行 Standard Route 的 `solution/`；
- `used` 来源运行 High Cost Route 的 `solution/`。

## 主要脚本

| 文件 | 作用 |
| --- | --- |
| `benchmark_repeated_runs.py` | 成对重复运行 baseline/used Solution，并生成逐次与汇总 CSV |
| `benchmark_rerun_failed.py` | 重跑已有批次中的失败项 |
| `inspect_tasks.py` | 检查 Task 结构与执行前提 |
| `runner.py` | Docker 执行、测试、耗时与内存采样实现 |

## 使用方法

以下命令从项目根目录运行。

```powershell
# 查看参数
python .\archive_local\task_solution_validation\benchmark_repeated_runs.py --help

# 默认对每个来源连续运行 3 次
python .\archive_local\task_solution_validation\benchmark_repeated_runs.py

# 只验证指定 Task
python .\archive_local\task_solution_validation\benchmark_repeated_runs.py `
  --tasks weighted-gdp-calc dialogue-parser `
  --runs 3
```

可通过 `--task-workers`、`--max-parallel-cpus` 和
`--max-parallel-memory-mib` 调整外层调度。每个 Task 的 baseline 与 used 使用独立
容器运行；同一来源的多次运行在同一容器中连续执行，以复用已安装依赖和缓存。

## 输出

默认写入：

```text
benchmark-run-logs/<timestamp>/
├── batch_manifest.json     # 输入快照、运行次数与资源预算
├── logs/
│   └── <task-id>/
│       ├── baseline/      # Standard Route 原始日志
│       └── used/          # High Cost Route 原始日志
├── runs.csv               # 每一次运行的明细
└── summary.csv            # 按 Task 和来源聚合
```

`runs.csv` 包含状态、通过情况、reward、Solution 耗时、峰值内存、采样来源、测试
耗时、退出码和日志位置。`summary.csv` 包含每个 Task/Route 的完成次数、通过次数、
平均/最小/最大耗时和内存。

这些结果衡量的是 Task Solution 设计本身的执行开销，不等同于 Harbor Agent 的
端到端运行开销。后者位于 `benchmark/runner/runtime/runs`，还包含 Agent 执行、
LLM Token 和 Skill Loaded 等指标。

内存峰值默认以 50ms 间隔采样容器 init 进程及其后代进程的 RSS 总和。Linux 宿主
优先读取 `/proc`；Docker Desktop 等环境通过 `docker top` 在 Docker VM 中读取；
均不可用时才逐级降级到 cgroup 或 `docker stats`。
