# Benchmark 环境准备

`Env` 保存运行 Benchmark 所需的宿主机 Agent 环境、API 本地配置和任务镜像准备工具。

## Agent 环境

`requirement.txt` 当前是环境安装过程和具体指导记录，不是可直接传给 `pip install -r` 的锁定依赖文件。后续版本固定后再整理为可重复安装的依赖清单。

自定义 Harbor Agent 使用标准 `src` 布局，安装入口为：

```powershell
pip install -e .\benchmark\Env
```

Agent 名称保持为：

```text
my_agents.dmx_codex:DMXCodex
```

## 本地配置

`local/API.jsonl` 包含本地 API 配置，不提交 Git。也可以通过 `BENCHMARK_API_CONFIG` 指定其他位置。

## 镜像准备

镜像环境分为三个环节：

1. `images/acquire`：优先采用本地已有任务镜像；只有找不到可用镜像时才构建 Task 的 `environment/Dockerfile`，并用 Docker Image ID 生成正式 tag。
2. `images/packages`：Node、Codex、ripgrep 通用离线包及校验清单；当前保存现成离线包，尚未实现自动下载脚本。
3. `images/patch`：检查本地任务镜像，并将缺失工具装入镜像。

当前执行镜像检查和装载：

```powershell
python .\images\patch\prepare_agent_images.py
```

推荐使用统一入口，它会严格按照“采用或构建 Task 镜像 → 装入并验证通用包”的顺序执行：

```powershell
python .\images\prepare_task_images.py
```

第一步采用本地镜像或在缺失时构建，并更新主映射 `benchmark/Env/task_images.json`，同时同步同名副本到 `data/datasets/task_images.json`；第二步要求主映射中的镜像已经存在，只装入本地通用包，不拉取基础镜像，也不联网下载通用包。runner 只读取 Env 主映射，datasets 文件仅作为数据副本。两个阶段结束后，每个任务只保留一个 Image ID 和一个正式名称，上游任务镜像与旧版本会被清理。第一步失败时不会执行第二步。
