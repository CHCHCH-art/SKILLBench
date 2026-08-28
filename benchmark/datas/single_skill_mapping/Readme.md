# Single Skill Mapping

本目录按 Task 保存 Runner 使用的三类 Skill 集合。当前共有 35 个 Task，每个 Task
对应一个 `<task-id>_Gold_skill/` 目录。

## 目录结构

```text
<task-id>_Gold_skill/
├── Standard SKILLs/       # Standard Route 的 Skill
├── High_Cost_Skills/      # High Cost Route 的 Skill
└── Selected/              # 两条 Route 的 Skill + 可复现噪声 Skill
```

每个 Skill 保留独立目录和完整内容，且目录根部必须直接包含 `SKILL.md`。Runner 不再
从 ZIP 文件读取 Skill。

## 三类 Skill 组

### `Standard SKILLs`

对应 Base/Standard Route，来源于
`archive_local/Snaps/Skills_snap/Base` 中按 Task 保存的设计 Skill。

### `High_Cost_Skills`

对应 Used/High Cost Route，来源于
`archive_local/Snaps/Skills_snap/Used` 中按 Task 保存的设计 Skill。

### `Selected`

用于 Mixed 实验。每个 Task 固定包含 10 个 Skill，由以下内容组成：

1. 该 Task 的全部 Standard Skill；
2. 该 Task 的全部 High Cost Skill；
3. 从 34k-skills 候选池中可复现采样的 `N` 个无关噪声 Skill。

噪声数量按 Task 计算：

```text
N = 10 - Standard Skill 数 - High Cost Skill 数
```

因此不同 Task 的噪声数量不同，但 `Selected` 总数始终为 10。当前统计为：

| 项目 | 数量 |
| --- | ---: |
| Task | 35 |
| Standard Skill 条目 | 86 |
| High Cost Skill 条目 | 86 |
| Selected Skill 条目 | 350 |

`Selected` 的噪声 Skill 来源快照位于 `archive_local/ALL-34K-SKILLS`。可复现采样的
目的，是在固定候选规模下生成可比较的 Skill 注入与加载验证数据，而不是把
噪声 Skill 当作 Task 的 Gold Skill。

## Runner 对应关系

```powershell
python .\benchmark\runner\run_baseline.py --standard
python .\benchmark\runner\run_baseline.py --high-cost
python .\benchmark\runner\run_baseline.py --selected
```

Runner 会按 Task ID 查找 `<task-id>_Gold_skill`，并只加载当前条件对应的一级 Skill
目录。`court-form-filling` 已停用，不属于当前 Task 集合。

## 维护约束

- 修改 Standard 或 High Cost 集合后，必须重新核对 `Selected` 是否仍为 10 个；
- Skill 目录名在同一 Task 内应保持大小写不敏感唯一；
- 每个 Skill 根目录必须包含 `SKILL.md`；
- 不要把运行时修改写回本目录；Runner 会在 `runtime/work` 中创建任务副本；
- 更新 Mapping 后，应同步检查数据组件和相关运行结果的版本一致性。
