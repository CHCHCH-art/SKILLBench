# Single Skill Mapping

本目录只保存 Task 到 Skill 目录名的映射，不再保存 Skill 内容副本。实际 Skill 统一位于：

```text
benchmark/datas/optional_skills/skills/<skill-name>/SKILL.md
```

当前映射文件：

- `standard.jsonl`：Standard Route，35 个 Task、86 个 Skill 引用；
- `high_cost.jsonl`：High Cost Route，35 个 Task、86 个 Skill 引用；
- `random_selected.jsonl`：Mixed/Selected 实验，35 个 Task、350 个 Skill 引用；
- `bm25_top10.jsonl`：BM25 初级检索 Top10，35 个 Task、350 个 Skill 引用；
- `qwen_meta_top10.jsonl`：Qwen-Meta 初级检索 Top10，35 个 Task、350 个 Skill 引用；
- `skillrouter_top10.jsonl`：SkillRouter 初级检索 Top10，35 个 Task、350 个 Skill 引用。

## JSONL 格式

每行必须是一个对象：

```json
{"task_id":"dialogue-parser","skills":["dialogue-graph-validation-serialization","dialogue-section-choice-parser"]}
```

同一文件中 `task_id` 不得重复，同一 Task 的 Skill 名也不得重复。Skill 字段只能是
`optional_skills/skills` 下的一级目录名，不能填写任意路径。

Runner 同时接受 `.yaml`/`.yml`，其顶层必须是相同记录组成的列表：

```yaml
- task_id: dialogue-parser
  skills:
    - dialogue-graph-validation-serialization
    - dialogue-section-choice-parser
```

YAML 解析需要 PyYAML；JSONL 只依赖 Python 标准库，是仓库内的默认格式。

## Runner 用法

```powershell
python .\benchmark\runner\run_baseline.py --mapping-file `
  .\benchmark\datas\single_skill_mapping\standard.jsonl

python .\benchmark\runner\run_baseline.py --mapping-file `
  .\benchmark\datas\single_skill_mapping\high_cost.jsonl

python .\benchmark\runner\run_baseline.py --mapping-file `
  .\benchmark\datas\single_skill_mapping\bm25_top10.jsonl
```

Runner 在调用 Harbor、Docker、API 或创建运行批次之前解析整份映射，并检查：

1. 映射格式及字段类型；
2. 本次运行的每个 Task 都存在映射；
3. Task 和 Skill 引用没有重复；
4. Skill 目录名没有路径穿越或大小写不一致；
5. 每个 Skill 目录存在且根部包含 `SKILL.md`。

任一检查失败都会汇总错误并立即退出，不启动任何 Task。
