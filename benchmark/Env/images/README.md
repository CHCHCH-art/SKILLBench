# 任务镜像准备

`Env/images` 是任务镜像的唯一导入、构建、工具补丁和映射生成入口。

默认任务目录：

```text
benchmark/datas/tasks
```

唯一权威生产映射表：

```text
benchmark/Env/task_images.json
```

每次更新主映射时，同时生成只读数据副本：

```text
data/datasets/task_images.json
```

Env 和 runner 都只读取 Env 主映射；datasets 中的同名文件不参与运行时解析。

映射表保持简单的 `任务 ID -> 本地镜像名` 结构：

```json
{
  "court-form-filling": "benchmark-cache/court-form-filling-gold:526220d23d28fd90"
}
```

## 使用

```powershell
python .\images\prepare_task_images.py
python .\images\prepare_task_images.py --task court-form-filling
python .\images\prepare_task_images.py --dry-run
python .\images\prepare_task_images.py --audit
```

统一入口依次执行：

1. 复用本地映射镜像或同任务仓库中唯一的现有镜像。
2. 找不到可复用镜像时构建 `environment/Dockerfile`。
3. 从本地校验过的离线包安装并验证 Node.js、npm、Codex CLI、uv/uvx 和 ripgrep。
4. 使用最终 Docker Image ID 生成正式名称。
5. 删除 staging、导入来源镜像，以及所有未被映射引用的同任务旧镜像。
6. 原子更新 `benchmark/Env/task_images.json`，并同步 `data/datasets/task_images.json` 副本。

正式名称格式：

```text
benchmark-cache/<task>-gold:<Docker Image ID 前 16 位>
```

命令结束后，每个任务只能对应一个 Docker Image ID，并且该 Image ID 只能有一个标签。构建过程可以短暂使用随机 staging 标签，但成功或失败后都必须清理。`alexgshaw/<task>` 等上游任务镜像在最终镜像就绪后也会被删除。

`uv`/`uvx` 固定预装为 `0.9.7`。任务验证脚本应先检查镜像中是否已有
`uv` 和 `uvx`，仅在处理未补丁的外部镜像时才使用在线安装器兜底。

`--audit` 只检查映射、本地镜像、单标签约束和 Agent 工具，不修改镜像。

`--force` 会忽略现有任务镜像并根据 Dockerfile 重建。默认任务根目录保持 `benchmark/datas/tasks`；可以通过 `--tasks-root` 显式覆盖。
