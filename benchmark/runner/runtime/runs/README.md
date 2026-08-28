# Harbor Benchmark 运行结果

本目录保存 `run_baseline.py` 和 `rerun_error.py` 产生的端到端 Harbor 运行结果。

## 当前结果分组

| 目录 | 内容 |
| --- | --- |
| `Ds-V4-Flash` | DeepSeek V4 Flash 的 No Skill、Standard、High Cost 结果 |
| `GPT` | GPT 系列模型的 No Skill、Standard、High Cost 结果 |
| `Mixed` | Selected Skill 集合在两个模型上的结果 |

`Mixed` 当前包含：

- `Deepseek-V4-Flash`；
- `GPT-5.6-luna-cdx`。

这里的 Mixed 与 Runner 条件 `selected` 含义相同：每个 Task 获得 10 个 Skill，包含
Standard Skill、High Cost Skill 和来自 34k-skills 的可复现噪声 Skill。

## 单次结果

典型目录层次为：

```text
<group>/<batch-or-model>/Repeat_<N>/<task-id>/<condition>/
├── run_summary.json
├── baseline.log
└── Job_result/            # Harbor 原始 Job 结果
```

其中 `run_summary.json` 是分析的主要入口，记录：

- `status`、`passed`、`failure_reason`；
- `phase_cost`：环境、Agent、执行、Verifier 和总耗时；
- `peak_memory`：峰值内存及采样来源；
- `llm_cost_usd`、`agent_input_tokens`、`agent_output_tokens`；
- `image_cache`：使用的 Task 镜像与是否复用；
- `skill_audit`：提供、可见、加载的 Skill 及加载证据。

## Skills Loaded 数据

Mixed 结果重点比较以下字段：

| 字段 | 含义 |
| --- | --- |
| `provided_skills` | Runner 传给 Harbor 的 10 个候选 Skill |
| `available_skills` | Agent 环境中实际可见的 Skill |
| `loaded_skills` | 运行过程中观察到被加载的 Skill |
| `load_evidence` | 支持 Skill Loaded 判断的运行证据 |

分析时应同时检查 `skill_audit.passed`。如果 Skill 注入或审计本身失败，不应直接把
空的 `loaded_skills` 解释为 Agent 主动拒绝加载。

## 与 Solution 验证结果的区别

- 本目录：Harbor Agent 端到端结果，包含 LLM、Skill 和 Agent 执行开销；
- `archive_local/task_solution_validation/benchmark-run-logs`：直接执行 Task Solution
  的重复验证结果，用于衡量 Route 设计本身的耗时与内存。

运行结果可能记录生成时机器的绝对路径。这些字段只用于实验追踪，不是代码的固定
输入路径；移动项目后无需保持原盘符。
