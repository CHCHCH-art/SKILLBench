# Skill Quality Pipeline

`run_skill_pipeline.py` 用于生成和校验 Skill 元数据，并汇总为数据集根目录下的 `All.jsonl`。

输入目录应包含一级 Skill 子目录，数据集根目录还需提供 `Base Describe.md`：

```text
dataset/
  Base Describe.md
  skills/
    example/SKILL.md
```

## 运行

在仓库根目录执行：

```powershell
python scoring/skill_quality/run_skill_pipeline.py data/components/Gold/skills --concurrency 2
```

默认只为缺少 `skill_llm_describe.json` 的 Skill 调用模型。需要全部重新生成时使用：

```powershell
python scoring/skill_quality/run_skill_pipeline.py data/components/Gold/skills --llm-mode overwrite --concurrency 2
```

模型配置读取自 `API.jsonl`。执行结果写入数据集根目录的 `All.jsonl`，过程报告写入 `report/`。

## 不使用 LLM 标签

只生成静态与基础元数据、完全不调用 LLM 时，使用：

```powershell
python scoring/skill_quality/run_skill_pipeline.py data/components/Gold/skills --no_llm
```

该模式仍会执行 L1 检查、`Base Describe.md` 生成、逐 Skill 聚合、`All.jsonl` 汇总和临时文件清理；会跳过 LLM 生成、LLM 结果扫描与 LLM 结果备份。最终记录不包含 `task_tags`、`service_cost_score`、`service_safety_score`。即使 Skill 目录中残留旧的 `skill_llm_describe.json`，也不会将其标签混入本次输出。`--no-llm` 是等价写法。

## Dry run

```powershell
python scoring/skill_quality/run_skill_pipeline.py path/to/dataset/skills --ds-dry-run --limit 1
```

`--ds-dry-run` 仍会调用模型，但不写入模型响应；其他检查、临时元数据和报告仍会正常生成。
