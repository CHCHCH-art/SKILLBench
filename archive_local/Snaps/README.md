# Route 设计快照

`Snaps` 保存 SKILLBench 两条 Route 的 Task 与 Skill 设计档案。这里的内容用于解释
设计来源和复现实验输入，不是 Runner 的临时工作目录。

## 语义对照

| 快照命名 | 对应路线 | Task 目录 | Skill 目录 |
| --- | --- | --- | --- |
| Base | Standard Route | `Task_snap/baseline_task` | `Skills_snap/Base` |
| Used | High Cost Route | `Task_snap/used_task` | `Skills_snap/Used` |

## Task 快照

```text
Task_snap/
├── baseline_task/         # Standard Route
└── used_task/             # High Cost Route
```

两个目录都按 Task ID 保存完整 Task bundle。每个 Task 的主要内容包括：

- `instruction.md`：任务说明；
- `task.toml`：Task 与资源配置；
- `environment/`：Docker 环境与输入资源；
- `tests/`：Verifier；
- `solution/`：该 Route 对应的设计结果。

因此，同一个 Task 在 `baseline_task` 与 `used_task` 下的 `solution/`，分别代表
Standard Route 和 High Cost Route 的 Solution 设计。它们由
`task_solution_validation` 重复运行，以验证正确性和开销。

## Skill 快照

```text
Skills_snap/
├── Base/                  # Standard Route Skill 设计
└── Used/                  # High Cost Route Skill 设计
```

这些 Skill 随后按 Task 整理到：

- `benchmark/datas/single_skill_mapping/<task>_Gold_skill/Standard SKILLs`；
- `benchmark/datas/single_skill_mapping/<task>_Gold_skill/High_Cost_Skills`。

Mapping 中的 `Selected` 不是第三条人工设计 Route，而是 Standard、High Cost 两组
Skill 与可复现噪声 Skill 的混合集合。

## 与运行结果的关系

```text
Task_snap/*/solution
└── task_solution_validation/benchmark-run-logs
    └── 验证 Solution 的通过率、耗时与内存

Skills_snap/*
└── benchmark/datas/single_skill_mapping
    └── benchmark/runner/runtime/runs
        └── 验证 Agent 在不同 Skill 条件下的表现与开销
```

## 维护约束

- 快照是设计档案，非必要不要原地修改；
- 如需修复 Task，应记录修改原因，并同步相应 Route；
- 新增 Task 时，应同时确认 Task 快照、Skill 快照、Mapping 和镜像映射；
- 重要快照应保留仓库之外的可靠备份。
