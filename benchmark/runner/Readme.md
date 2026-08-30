# Benchmark Runner

Runner 只运行任务，并严格复用 `benchmark/Env/task_images.json` 声明的本地镜像；
不会下载、构建或重新标记镜像。

Skill 实体统一从 `benchmark/datas/optional_skills/skills` 读取。除 No Skill 对照外，
所有 Skill 运行都只通过 `--mapping-file` 接收 Task-to-Skill 映射文件：

```powershell
python .\run_baseline.py --no-skill
python .\run_baseline.py --mapping-file ..\datas\single_skill_mapping\standard.jsonl
python .\run_baseline.py --mapping-file ..\datas\single_skill_mapping\high_cost.jsonl
python .\run_baseline.py --mapping-file ..\datas\single_skill_mapping\bm25_top10.jsonl
```

映射支持 JSONL，以及安装 PyYAML 后的 YAML。Runner 会在检查 Docker/API 和创建
运行目录之前完整解析映射，确认本次运行的每个 Task 都有映射、所有 Skill 引用
存在且根部包含 `SKILL.md`。任一错误都会直接终止整个批次。

任务目录可通过 `--tasks-root` 指定：

```powershell
python .\run_baseline.py `
  --mapping-file ..\datas\single_skill_mapping\standard.jsonl `
  --tasks-root ..\datas\tasks `
  --task task-id `
  --repeat 3
```

Runner 默认最多并行执行 2 个轻量任务，并从每个任务的 `task.toml` 读取
`environment.cpus` 与 `environment.memory_mb`。CPU 或内存需求超过总预算一半的
任务会被归为重型任务，等所有轻量任务结束后独占执行。每个任务的多次 repeat
仍在同一 worker 中连续执行。

```powershell
python .\run_baseline.py `
  --mapping-file ..\datas\single_skill_mapping\standard.jsonl `
  --task-workers 2 `
  --max-parallel-cpus 16 `
  --max-parallel-memory-mib 24576
```

`rerun_error.py` 复用同一调度器。Skill 批次重跑时需要通过 `--mapping-file` 传入
原映射文件；No Skill 批次不需要。

运行产物保存在 `runtime/`。`run_summary.json` 会记录 Mapping 文件、统一 Skill 根
目录和实际提供的 Skill。内存监控通过持久 `docker events` 发现当前运行所属容器，
再以单个持久 `docker exec` 每 100ms 读取容器 cgroup 内存；不会为每次采样重复启动
`docker ps`、`docker top` 或 `docker stats`。峰值、样本数、采样间隔和实际容器名均
记录在 `run_summary.json` 的 `peak_memory` 字段中。
