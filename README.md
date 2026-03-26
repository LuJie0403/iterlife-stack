# iterlife-reunion-stack

IterLife 控制面与共享前端资产仓。

## 当前职责

- 统一 webhook 部署控制面。
- 部署目标注册表与通用部署脚本。
- webhook 的 systemd 运行资产。
- 跨前端共享主题包 `@iterlife/theme-dark-universe`。
- 仓库级治理、运维和 secrets 文档。

## 当前目录

```text
.github/workflows/    GitHub Actions 工作流
config/               部署目标注册表
docs/                 治理、运维与共享包文档
packages/themes/      前端共享主题包
scripts/              通用部署与校验脚本
systemd/              webhook 服务 unit 与 drop-in
webhook/              webhook 服务源码与示例 env
```

## 文档入口

- [docs/repository-directory-governance.md](./docs/repository-directory-governance.md)
- [docs/unified-deployment-and-operations.md](./docs/unified-deployment-and-operations.md)
- [docs/dark-universe-theme-package.md](./docs/dark-universe-theme-package.md)
- [docs/github-actions-secrets-inventory.md](./docs/github-actions-secrets-inventory.md)

`/docs` 只承载当前仍然有效的治理规则、运维基线和共享资产说明，不记录已经下线的迁移过程，也不重复业务仓库自己的 README。

- [docs/repository-directory-governance.md](./docs/repository-directory-governance.md)：仓库顶层目录、目录边界、准入规则和持续治理计划。
- [docs/unified-deployment-and-operations.md](./docs/unified-deployment-and-operations.md)：统一 GHCR + webhook 部署链路、服务器初始化、发布检查、回滚与排障。
- [docs/dark-universe-theme-package.md](./docs/dark-universe-theme-package.md)：`@iterlife/theme-dark-universe` 的目录、边界、发布和消费方式。
- [docs/github-actions-secrets-inventory.md](./docs/github-actions-secrets-inventory.md)：当前 GitHub Actions secrets 的使用归属、作用范围和维护规则。

## 文档治理规则

- 文件名统一使用英文 `kebab-case`。
- 主标题和正文优先使用中文，直接描述当前状态和当前规则。
- 同一主题只保留一个事实源；如果某条规则已经写入专门文档，其它地方只链接，不重复抄写。
- `/docs` 只保留稳定资料；排查笔记、临时方案、迁移草稿不进入该目录。
- 涉及部署链路、共享包发布链路或目录结构的变更时，必须同步更新对应文档。

## 文档更新入口

- 调整顶层目录、目录职责或文档分层时，更新 [docs/repository-directory-governance.md](./docs/repository-directory-governance.md)。
- 调整 webhook、systemd、部署脚本、部署目标注册表或发布流程时，更新 [docs/unified-deployment-and-operations.md](./docs/unified-deployment-and-operations.md)。
- 调整 `packages/themes/dark-universe` 的目录、发布方式或接入方式时，更新 [docs/dark-universe-theme-package.md](./docs/dark-universe-theme-package.md)。
- 调整 workflow secret、仓库 secret 或发布凭证时，更新 [docs/github-actions-secrets-inventory.md](./docs/github-actions-secrets-inventory.md)。

## 运行约束

- 真实配置文件 `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env` 不入库。
- 仓库只保留 `webhook/iterlife-deploy-webhook.env.example`。
- 仓库内不存放任何真实 token、secret 或 password。

## 常用校验

```bash
bash scripts/validate-webhook-config.sh webhook/iterlife-deploy-webhook.env.example
cd packages/themes/dark-universe && npm run build
```
