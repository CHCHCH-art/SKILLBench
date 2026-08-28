# Random_2K

本目录用于从归档的 34K Skill 池中确定性抽取 2,000 个 Random Skills。

## 目录

- `extract_random_2k.py`：精确去重、固定种子抽样和原样复制。
- `Exclude_SKILLS/`：抽样前必须排除的 Skill 注册表。
- `skills/`：实际生成的 Random_2K 结果；可通过脚本重建。

## 排除注册

`Exclude_SKILLS` 下的每个一级子目录都是一项排除记录，目录名必须与 34K Skill 池中的目录名一致，并且必须直接包含 `SKILL.md`。

采样器只从该目录读取排除项，不在代码中维护任务名单。新增或移除排除项时，直接增删完整 Skill 文件夹，然后运行：

```powershell
python .\data\components\Random_2K\extract_random_2k.py --dry-run
```

确认结果后，去掉 `--dry-run` 才会重建 `skills/`。

当前注册的 8 个 Skill 与无 Task Gold 的任务直接对应。项目使用自行生成的 Baseline ZIP，因此必须避免 Random_2K 抽到 34K 中的对应版本，造成语义级 Gold 泄漏。后续数据集构建阶段的精确哈希去重不能替代这里的抽样前排除。
