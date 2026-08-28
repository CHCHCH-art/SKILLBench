# 原始任务镜像获取

`build_task_images.py` 默认遍历 `benchmark/datas/tasks`，并更新唯一权威生产映射表：

```text
benchmark/Env/task_images.json
```

主映射更新时会同步同名副本到 `data/datasets/task_images.json`。运行代码只读取 Env 主映射。

它优先复用映射中仍存在的本地镜像，或者采用同任务仓库中唯一的现有镜像。找不到可复用镜像或指定 `--force` 时，才构建任务的 `environment/Dockerfile`。

正式名称格式：

```text
benchmark-cache/<task>-gold:<Docker Image ID 前 16 位>
```

导入或构建完成后，脚本会移除同一 Image ID 的其他标签，并删除所有未被映射引用的同任务镜像，包括 `alexgshaw/<task>` 等上游镜像。命令结束后，每个任务只能保留一个 Image ID、一个名称。

```powershell
python .\build_task_images.py --dry-run
python .\build_task_images.py
python .\build_task_images.py --task court-form-filling
python .\build_task_images.py --audit
```

默认构建使用 `--pull` 更新 Dockerfile 的 `FROM` 镜像；`--no-pull` 可完全依赖本地基础镜像。Dockerfile 修改后需要显式使用 `--force` 才会重建。
