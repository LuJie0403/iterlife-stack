# IterLife Reunion Stack GitHub Actions Secrets Reference

最后更新：2026-03-26

本文件记录 `iterlife-reunion-stack` 仓库当前使用的 GitHub Actions secrets，并区分：

- 当前仓库自身需要配置的 secrets
- 共享 reusable workflow 由业务仓库提供的 secrets
- GitHub Actions 自动提供、无需人工配置的内置 token

## 1. 当前仓库自身 Secrets

以 `gh secret list --repo LuJie0403/iterlife-reunion-stack` 为准，当前仓库实际存在的 repository secret 如下：

1. `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`

用途：

- 仅供 [publish-theme-dark-universe.yml](/Users/iter_1024/repository/iterlife-reunion-stack/.github/workflows/publish-theme-dark-universe.yml) 的 `publish` job 使用
- 在向 npm 官方公共 registry 发布 `@iterlife/theme-dark-universe` 时，通过 `NODE_AUTH_TOKEN` 注入给 `npm publish`

当前绑定关系：

- workflow: `Publish Theme Dark Universe`
- package: `@iterlife/theme-dark-universe`
- registry: `https://registry.npmjs.org`

## 2. 共享 Release Workflow 所需 Secrets

[reusable-release-ghcr-webhook.yml](/Users/iter_1024/repository/iterlife-reunion-stack/.github/workflows/reusable-release-ghcr-webhook.yml) 定义了两个必需 secrets：

1. `ALIYUN_DEPLOY_WEBHOOK_URL`
2. `ALIYUN_DEPLOY_WEBHOOK_SECRET`

但这两个 secret 不需要配置在 `iterlife-reunion-stack` 仓库自身。

原因：

- 该 workflow 是 `workflow_call` 类型的共享模板
- secret 由调用它的业务仓库传入
- 实际应配置在各业务仓库的 `Repository secrets` 中

当前消费这些 secrets 的仓库包括：

1. `iterlife-reunion`
2. `iterlife-reunion-ui`
3. `iterlife-expenses`
4. `iterlife-expenses-ui`

用途：

- `ALIYUN_DEPLOY_WEBHOOK_URL`：GitHub Actions 在镜像构建完成后回调阿里云部署 webhook
- `ALIYUN_DEPLOY_WEBHOOK_SECRET`：用于生成 webhook HMAC 签名

## 3. GitHub 内置 Token

以下 token 由 GitHub Actions 自动提供，不需要手工配置为 repository secret：

1. `GITHUB_TOKEN`

当前用途：

- [reusable-release-ghcr-webhook.yml](/Users/iter_1024/repository/iterlife-reunion-stack/.github/workflows/reusable-release-ghcr-webhook.yml) 中登录 GHCR 并推送镜像
- checkout 当前仓库代码

说明：

- 该 token 是 GitHub Actions 运行时自动注入
- 不应手工创建同名 repository secret

## 4. 已移除或不再需要的 Secrets

以下 secret 名称已不再作为当前标准流程的一部分：

1. `NPM_TOKEN`
2. `GH_PACKAGES_PUBLISH_TOKEN`
3. `GH_PACKAGES_READ_TOKEN`

说明：

- `NPM_TOKEN` 已统一更名为 `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`
- `GH_PACKAGES_PUBLISH_TOKEN` / `GH_PACKAGES_READ_TOKEN` 对应的是旧的 GitHub Packages 主题发布或 UI 包读取路径
- 当前 UI 仓库消费的是公开 npm 包 `@iterlife/theme-dark-universe`，不再需要这类私有包读取 token

## 5. 维护规则

更新本文件时应同时检查以下三处是否一致：

1. `gh secret list --repo LuJie0403/iterlife-reunion-stack`
2. `.github/workflows/*.yml`
3. 相关运维或前端共享包文档

若后续新增新的 workflow secret：

1. 先修改 workflow
2. 再更新本文件
3. 最后在 GitHub 仓库设置页补齐对应 secret
