# Benchmark Runner

Runner 只运行任务并严格复用 `benchmark/Env/task_images.json` 中声明的本地镜像。`data/datasets/task_images.json` 只是由 Env 同步生成的数据副本，runner 不读取它。

Runner 不下载、不构建、不重新打标签，也不修改镜像映射表。

启动时对每个任务执行以下检查：

1. 映射表文件存在且格式为 `任务 ID -> 镜像名`。
2. 当前任务在映射表中存在。
3. 映射的 Docker 镜像在本地存在。

任一条件不满足都会在 preflight 阶段直接退出，并提示先运行：

```powershell
python .\benchmark\Env\images\prepare_task_images.py
```

默认映射表可以通过 `BENCHMARK_TASK_IMAGES_FILE` 显式覆盖，但不会启用任何下载兜底。

常用命令：

```powershell
python .\run_baseline.py --no_skill
python .\run_baseline.py --standard
python .\run_baseline.py --high-cost
```

Runner 默认最多并行执行 2 个轻量任务，并从每个任务的 `task.toml` 读取
`environment.cpus` 与 `environment.memory_mb`。CPU 或内存需求超过总预算一半的
任务会被归为重型任务，等所有轻量任务结束后独占执行。每个任务的多次 repeat
仍在同一 worker 中连续执行，以保留 task-major 顺序和缓存局部性。Danger 模式
共享一个网络监控容器，因此始终串行。

可以显式调整并发数和资源预算：

```powershell
python .\run_baseline.py --standard `
  --task-workers 2 `
  --max-parallel-cpus 16 `
  --max-parallel-memory-mib 24576
```

使用 `--task-workers 1` 可恢复外层串行调度；Harbor 单个任务内部仍固定使用
`--n-concurrent 1`。

`rerun_error.py` 复用同一调度器和三个资源参数；不同任务可并行替换，同一任务
目录仍只由一个 worker 操作。Danger rerun 同样强制串行。

任务目录通过 `--tasks-root` 选择，Mapping 目录通过 `--mapping-root` 选择。例如：

```powershell
$tasks = '..\datas\tasks'

python .\run_baseline.py --standard `
  --tasks-root $tasks `
  --mapping-root '..\datas\single_skill_mapping'

python .\run_baseline.py --high-cost `
  --tasks-root $tasks `
  --mapping-root '..\datas\single_skill_mapping' `
  --task task-id --repeat 3
```

默认任务目录为 `benchmark/datas/tasks`，默认 Mapping 目录为
`benchmark/datas/single_skill_mapping`。Runner 从 `Standard SKILLs` 以及
`High_Cost_Skills`/`High cost` 的一级子目录直接读取 Skill；每个子目录必须直接包含
`SKILL.md`，不再支持 ZIP 压缩包。

运行批次目录会自动从 Mapping 目录名移除最后两个下划线分段并添加前缀，例如
`single_skill_mapping` 生成 `single_Standard_Run001`。Second Map 当前只在
`archive_local/Snaps/Map_snap/Second_Map` 保存构建方法快照，不作为 Runner 输入。

运行产物保存在 `runtime/`；任务执行前会复制任务目录，并将映射中的镜像名明确写入临时任务的 `task.toml`。

`run_summary.json` 中的 `peak_memory` 默认以 50ms 间隔汇总任务相关容器内
init 进程及其所有后代进程的 RSS。Linux 宿主直接读取 `/proc`；Docker Desktop
等环境通过 `docker top` 在 Docker VM 内读取。`metric` 与 `sampler_source` 会记录
实际指标和来源；两种 RSS 方式都不可用时才降级为 `docker_stats_memory`。
