# Benchmark Run Logs

本目录保存 Task Solution 的重复验证结果。每个时间戳目录代表一次独立验证批次，
比较 `baseline`（Standard Route）和 `used`（High Cost Route）的 Solution。

```text
<timestamp>/
├── batch_manifest.json
├── logs/<task-id>/{baseline,used}/
├── runs.csv
└── summary.csv
```

- `batch_manifest.json` 记录该批次的输入快照、运行次数与资源预算；
- `logs/` 用于排查单次运行和测试失败；
- `runs.csv` 用于逐次统计与异常值分析；
- `summary.csv` 用于比较两条 Route 的通过率、平均耗时和峰值内存。

这里的日志验证的是 Task `solution/`，不包含 Harbor Agent、LLM 调用或 Skill 加载
过程。Agent 端到端结果见 `benchmark/runner/runtime/runs`。
