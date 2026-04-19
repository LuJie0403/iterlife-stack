# 控制面自动同步设计方案

创建日期：2026-04-19
最后更新：2026-04-19

本文档描述 `iterlife-stack` 在阿里云宿主机上的控制面自动同步目标方案。本文档仅用于设计评审，不代表当前生产已经实现或启用该能力。

## 1. 背景

当前 `iterlife-stack` 以宿主机控制面仓库的形式常驻在 `/apps/iterlife-stack`，承担以下职责：

- 统一部署 webhook 服务
- 统一部署脚本与 compose 编排
- 统一部署目标注册表
- 统一正式运维文档与数据库人工执行脚本事实源

当前控制面存在一个长期风险：GitHub 主分支继续演进时，阿里云服务器上的 `/apps/iterlife-stack` 不会自动同步，容易出现“仓库主线已更新、生产控制面仍停留在旧提交”的漂移。

## 2. 设计目标

- 当 GitHub 上 `iterlife-stack/main` 更新时，自动触发服务器侧控制面同步。
- 让 `/apps/iterlife-stack` 与远端 `origin/main` 保持受控一致。
- 避免再依赖人工 SSH 登录服务器执行 `git pull`。
- 避免控制面工作树长期漂移。
- 同步过程必须可审计、可观测、可失败退出。

## 3. 非目标

- 本方案不负责业务应用镜像的构建或发布。
- 本方案不替代现有业务应用的 GHCR + webhook 部署链路。
- 本方案不在当前阶段引入新的控制面 Docker 服务。
- 本方案不在当前阶段处理 Git push 权限硬化。
- 本方案不直接修改业务应用数据库或运行时配置。

## 4. 设计约束

- `iterlife-stack` 是宿主机控制面仓库，不是独立业务容器。
- 当前生产环境 webhook 服务运行在 `systemd` 下，且依赖仓库内脚本与配置。
- 生产控制面问题排查默认只读；自动同步能力一旦启用，必须通过受控入口执行。
- 控制面同步不得依赖“脏工作树 merge”。
- 控制面同步不得简单等价于 webhook 进程内部直接 `git pull` 自更新。

## 5. 核心设计原则

### 5.1 控制面同步与业务部署分离

- 业务应用继续使用现有 `PR -> main -> GitHub Actions -> GHCR -> webhook deploy`。
- `iterlife-stack` 自身使用专用控制面同步 webhook，不复用业务应用部署路径。

### 5.2 webhook 只负责触发，不直接自更新

- 当前运行中的 webhook 进程不直接对自身工作目录执行同步。
- webhook 只负责验签、验仓库、验分支并触发异步同步任务。
- 真正的同步动作交给独立脚本或 `systemd` oneshot service 完成。

### 5.3 只允许受控快进同步

- 默认只允许 `fetch + fast-forward`。
- 不允许在自动同步链路中产生 merge commit。
- 当本地工作树不干净或无法 fast-forward 时，同步任务必须失败退出并告警。

## 6. 推荐架构

建议新增一条“控制面自动同步链路”：

1. GitHub 为 `iterlife-stack` 仓库配置专用 webhook。
2. webhook 只监听 `push` 事件。
3. 仅当 `ref == refs/heads/main` 时继续处理。
4. 服务器侧现有部署 webhook 或专用控制面 webhook 接收该回调。
5. 回调通过验签后，异步触发 `iterlife-stack` 同步任务。
6. 同步任务在宿主机执行：
   - 校验 `/apps/iterlife-stack` 是否为干净工作树
   - `git fetch origin main`
   - `git merge --ff-only origin/main`
   - `git submodule sync --recursive`
   - `git submodule update --init --recursive --checkout`
7. 若本次同步涉及 webhook、systemd 模板或脚本，则执行必要的控制面刷新动作。
8. 同步结果写入日志与状态文件。

## 7. 关键流程设计

### 7.1 事件入口

输入事件要求：

- 事件源仓库：`LuJie0403/iterlife-stack`
- 事件类型：`push`
- 分支：`main`

收到非目标仓库或非 `main` 分支事件时：

- 直接记录并忽略
- 不触发同步

### 7.2 同步前置校验

同步任务开始前应执行：

- 校验 `/apps/iterlife-stack/.git` 存在
- 校验远端仓库地址仍为期望值
- 校验当前工作树是否干净
- 校验当前 HEAD 所在分支是否为 `main`
- 校验关键命令可用：`git`、`systemctl`

任一校验失败时：

- 本次同步中止
- 写入失败状态
- 不做任何强制覆盖

### 7.3 同步动作

推荐固定为：

```bash
git fetch origin main
git merge --ff-only origin/main
git submodule sync --recursive
git submodule update --init --recursive --checkout
```

设计原因：

- `fetch + ff-only` 可避免自动 merge
- 子模块同步能保证 `.codex/meta` 等依赖与主仓基线一致
- 保持“与远端主分支一致”的同时，避免直接引入破坏性重置

### 7.4 同步后的控制面刷新

同步成功后，视改动范围决定是否执行以下动作：

- 若 `systemd/` 目录有变更：
  - 重新安装 unit / drop-in
  - `systemctl daemon-reload`
- 若 webhook 服务代码或其依赖脚本有变更：
  - 重启 `iterlife-app-deploy-webhook.service`
- 若仅文档变化：
  - 不重启任何服务

注意：

- 不应由正在处理请求的 webhook 主进程直接重启自己。
- 重启动作应由异步同步任务在回调完成后执行。

## 8. 日志与状态设计

建议新增：

- 控制面同步日志：
  - `/apps/logs/webhook/iterlife-stack-sync-YYYY-MM-DD.log`
- 控制面同步状态文件：
  - `/apps/logs/deploy-state/iterlife-stack-sync.json`

状态文件建议包含：

- 事件时间
- 仓库名
- 分支名
- 同步前 HEAD
- 同步后 HEAD
- 是否 fast-forward
- 是否刷新 systemd
- 是否重启 webhook
- 执行耗时
- 最终状态
- 错误摘要

## 9. 安全与风控设计

### 9.1 不直接开放任意仓库同步

- 只接受 `iterlife-stack` 的专用同步事件。
- 只接受已验签请求。
- 只接受 `main` 分支 push。

### 9.2 不在脏工作树上强行覆盖

- 这是本方案最核心的保护措施之一。
- 一旦 `/apps/iterlife-stack` 工作树不干净，同步应立即失败并进入人工处理流程。

### 9.3 不做裸 `git pull`

- `git pull` 会隐藏 fetch/merge 细节，不利于审计。
- 使用显式 `fetch + merge --ff-only` 更稳妥。

### 9.4 不在当前阶段做 Git 写权限硬化

- 生产控制面 Git push 权限收敛仍然是后续硬化项。
- 本方案只处理“自动同步”，不同时引入权限机制改造，避免治理项相互耦合。

## 10. 故障场景设计

### 10.1 工作树不干净

处理方式：

- 自动同步失败
- 写入状态文件
- 保留现场
- 进入人工治理流程

### 10.2 无法 fast-forward

处理方式：

- 自动同步失败
- 不自动 merge
- 不自动 reset

### 10.3 同步成功但 webhook 重启失败

处理方式：

- 同步本身记为成功
- 服务刷新记为失败
- 状态文件明确拆分“同步状态”和“刷新状态”

### 10.4 子模块更新失败

处理方式：

- 本次同步整体视为失败
- 不进入后续服务刷新动作

## 11. 分阶段落地建议

### 第一阶段：只做可观测同步

- 接入 GitHub webhook
- 同步任务仅记录事件和校验结果
- 不真正执行 `git fetch/merge`

### 第二阶段：启用只读 fast-forward 同步

- 打开 `fetch + merge --ff-only`
- 打开子模块同步
- 暂不自动重启 webhook

### 第三阶段：启用完整控制面刷新

- 根据改动范围自动执行 `daemon-reload`
- 在必要时受控重启 webhook
- 完成完整状态落盘

## 12. 当前建议结论

推荐采用“GitHub 主分支更新 -> 专用 webhook -> 异步同步任务 -> fast-forward only -> 子模块同步 -> 受控刷新”的方案。

不推荐采用以下方案：

- 在当前 webhook 请求线程里直接 `git pull`
- 在脏工作树上强制同步
- 自动 merge 非 fast-forward 变更
- 将控制面同步与业务服务部署混在同一条链路里

## 13. 待确认问题

- 控制面同步 webhook 是否复用现有 `iterlife-deploy-webhook-server.py`，还是拆成单独入口？
- systemd unit 与 drop-in 的刷新是否由同步任务自动执行，还是只在特定文件改动时执行？
- 若未来要引入 Git 写权限硬化，是否与自动同步一并切换到只读 deploy key？
