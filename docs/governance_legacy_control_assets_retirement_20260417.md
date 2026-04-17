# 旧控制面资产退场说明

最后更新：2026-04-17

本文档用于记录第四阶段“旧资产退场治理”的当前结论、现役事实源、遗留风险与验证结果。

## 1. 退场目标

第四阶段的目标不是简单删除文件，而是确保以下结论成立：

- 生产部署控制面只有一套现役事实源
- 历史部署资产不再被误认为生产现役入口
- 业务应用内部 webhook 与部署控制面 webhook 的职责边界清晰

## 2. 当前现役事实源

当前生产部署控制面的唯一现役事实源为：

- 控制面仓库：`iterlife-stack`
- webhook 服务源码：`iterlife-stack/webhook/iterlife-deploy-webhook-server.py`
- webhook 示例环境文件：`iterlife-stack/webhook/iterlife-deploy-webhook.env.example`
- systemd 模板：`iterlife-stack/systemd/iterlife-app-deploy-webhook.service`
- 真实运行配置：`/apps/config/iterlife-stack/iterlife-deploy-webhook.env`

以上路径之外，其他部署 webhook 相关资产都不应再被视为生产控制面入口。

## 3. 历史旧资产判断

根据服务器巡检结果，历史上存在过如下旧控制面资产路径：

- `/apps/iterlife-reunion/ops/webhook/*`

但在当前本地主干代码中，`iterlife-reunion` 仓库已经不存在对应部署控制目录，说明：

- 代码事实源已完成切换
- 服务器上如仍存在该目录，应视为历史遗留运行资产，而不是当前生产事实源

## 4. 业务 webhook 与部署 webhook 的边界

`iterlife-reunion` 仓库当前仍存在：

- `WebhookController`
- `GithubSignatureService`
- `GITHUB_WEBHOOK_SECRET`

但它们的职责是：

- 接收 GitHub push 事件
- 触发文章内容同步
- 处理业务域内的内容发布事件

它们不是生产部署控制面的 webhook。

因此应明确区分：

- 部署 webhook：由 `iterlife-stack/webhook/*` 承担
- 业务 webhook：由 `iterlife-reunion` 的业务代码承担

这两类 webhook 不应再被混淆。

## 5. 本次退场治理的实际结果

### 5.1 本地主干代码层面

检查结果：

- `iterlife-reunion` 仓库中已不存在 `ops/webhook` 部署控制目录
- `iterlife-stack` 仓库中保留唯一现役部署控制资产

### 5.2 文档层面

本次已明确：

- `iterlife-stack` 是唯一部署控制面事实源
- `iterlife-reunion` 中的 webhook 能力属于业务能力，不属于部署控制面

## 6. 当前剩余风险

当前仍需注意的风险包括：

1. 服务器上可能仍残留旧路径 `/apps/iterlife-reunion/ops/webhook`
2. 值班人员如果只看服务器目录、不看最新文档，仍可能误判历史目录为现役入口
3. `WebhookController` 名称在业务仓中仍可能被误解为部署入口

## 7. 建议的运行口径

从当前阶段开始，统一采用以下口径：

- `iterlife-stack` 是唯一部署控制面仓库
- `iterlife-reunion/ops/webhook` 若在服务器上仍存在，只视为历史遗留
- `iterlife-reunion/src/.../WebhookController` 属于业务 webhook，不属于部署控制面

## 8. 验证结果

### 8.1 本地仓库旧部署资产检查

检查结果：

- 通过
- `iterlife-reunion` 本地主干代码中不存在旧部署控制目录

### 8.2 现役控制面唯一性检查

检查结果：

- 通过
- `iterlife-stack/webhook/*` 和 `iterlife-stack/systemd/*` 为唯一现役控制面源码入口

### 8.3 业务 webhook 边界检查

检查结果：

- 通过
- `iterlife-reunion` 中的 webhook 代码仅承担 GitHub push 内容同步职责

## 9. 完成定义

第四阶段“旧资产退场治理”在代码与文档层面的完成定义为：

- 现役部署控制面事实源唯一
- 历史部署资产被明确标记为遗留
- 业务 webhook 与部署 webhook 边界明确
- 值班人员不再需要靠猜测判断哪套 webhook 是生产入口

## 10. 相关文档

- `docs/governance_repository_directory_20260411.md`
- `docs/operations_unified_deployment_and_operations_20260411.md`
