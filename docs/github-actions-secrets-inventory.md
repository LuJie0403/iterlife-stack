# GitHub Actions Secrets 清单

最后更新：2026-03-26

本文档记录 `iterlife-reunion-stack` 当前仍在使用的 GitHub Actions secrets，以及这些 secret 分别属于哪个仓库和哪条流水线。

## 1. `iterlife-reunion-stack` 仓库自身 Secret

当前本仓库实际需要维护的 repository secret 为：

1. `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`

用途：

- 供 `.github/workflows/publish-theme-dark-universe.yml` 的 `publish` job 使用。
- 作为 `NODE_AUTH_TOKEN` 发布 `@iterlife/theme-dark-universe` 到 npm 官方 registry。

## 2. 共享 Release Workflow 所需 Secret

`.github/workflows/reusable-release-ghcr-webhook.yml` 当前定义了两个必需 secret：

1. `ALIYUN_DEPLOY_WEBHOOK_URL`
2. `ALIYUN_DEPLOY_WEBHOOK_SECRET`

这两个 secret 由调用该 workflow 的业务仓库提供，不配置在 `iterlife-reunion-stack` 仓库自身。

当前消费方包括：

- `iterlife-reunion`
- `iterlife-reunion-ui`
- `iterlife-expenses`
- `iterlife-expenses-ui`

## 3. GitHub 自动提供的 Token

以下 token 由 GitHub Actions 自动提供，不需要手工创建：

1. `GITHUB_TOKEN`

当前用途：

- 登录 GHCR。
- checkout 当前仓库代码。

## 4. 当前不再维护的 Secret 名称

以下名称不属于当前标准事实源：

- `NPM_TOKEN`
- `GH_PACKAGES_PUBLISH_TOKEN`
- `GH_PACKAGES_READ_TOKEN`

如果 workflow 中重新引入这些名称，应先确认是否真的恢复了对应链路，再决定是否更新本文档。

## 5. 维护规则

- workflow 新增 secret 时，先修改 workflow，再更新本文档，再到 GitHub 仓库设置页补齐。
- 若某个 secret 只属于业务仓库，不应误写成 `iterlife-reunion-stack` 的自有 secret。
- 若某个 secret 已经不再被 workflow 使用，应在移除 workflow 依赖后同步从本文档删掉。
- 变更发布链路时，同时检查 [unified-deployment-and-operations.md](./unified-deployment-and-operations.md)。
