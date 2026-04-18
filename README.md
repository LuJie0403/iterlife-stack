# iterlife-stack

IterLife 控制面、正式文档与共享前端资产仓。

## 当前职责

- 统一 webhook 部署控制面。
- 统一管理正式设计、架构、产品、部署和治理文档。
- 部署目标注册表与通用部署脚本。
- webhook 的 systemd 运行资产。
- 跨前端共享主题包 `@iterlife/theme-dark-universe`。
- 跨前端共享复制交互包 `@iterlife/vue-copy-action`。
- 仓库级治理、运维和跨应用文档事实源。

## 当前目录

```text
.github/workflows/    GitHub Actions 工作流
config/               部署目标注册表
docs/                 跨应用文档与应用子目录文档
packages/             前端共享包（themes / vue）
deploy/compose/       控制面持有的生产 compose 定义
scripts/              通用部署与校验脚本
systemd/              webhook 服务 unit 与 drop-in
webhook/              webhook 服务源码与示例 env
```

## 文档入口

- [docs/governance_repository_structure_20260418.md](./docs/governance_repository_structure_20260418.md)
- [docs/operations_deployment_baseline_20260418.md](./docs/operations_deployment_baseline_20260418.md)
- [docs/design_frontend_packages_20260417.md](./docs/design_frontend_packages_20260417.md)
- [docs/idaas/idaas_design_identity_20260418.md](./docs/idaas/idaas_design_identity_20260418.md)
- [docs/reunion/reunion_design_overview_20260418.md](./docs/reunion/reunion_design_overview_20260418.md)
- [docs/reunion/reunion_product_overview_20260417.md](./docs/reunion/reunion_product_overview_20260417.md)
- [docs/expenses/expenses_design_overview_20260418.md](./docs/expenses/expenses_design_overview_20260418.md)

`/docs` 是 IterLife 体系正式非代码文档的单一事实源。跨应用文档直接放在 `/docs` 根目录，应用专属文档按 `expenses`、`reunion`、`idaas` 子目录规置。

- [docs/governance_repository_structure_20260418.md](./docs/governance_repository_structure_20260418.md)：仓库顶层目录、目录边界、准入规则和持续治理计划。
- [docs/operations_deployment_baseline_20260418.md](./docs/operations_deployment_baseline_20260418.md)：统一 GHCR + webhook 部署链路、服务器初始化、接入模板、发布检查、回滚与排障，以及当前服务器治理基线、发布矩阵与版本治理规则。
- [docs/design_frontend_packages_20260417.md](./docs/design_frontend_packages_20260417.md)：共享前端包的目录边界、发布方式和消费规则。
- [docs/idaas/idaas_design_identity_20260418.md](./docs/idaas/idaas_design_identity_20260418.md)：统一身份、会话、授权和 IDaaS 边界设计。
- [docs/reunion/reunion_design_overview_20260418.md](./docs/reunion/reunion_design_overview_20260418.md)：Reunion API/UI 的统一系统概览。
- [docs/reunion/reunion_product_overview_20260417.md](./docs/reunion/reunion_product_overview_20260417.md)：Reunion 当前产品定位、核心能力和优先级。
- [docs/expenses/expenses_design_overview_20260418.md](./docs/expenses/expenses_design_overview_20260418.md)：花多少 API/UI 的统一系统概览。

## 文档治理规则

- 文件名统一使用 `app_optional_doctype_topic_yyyymmdd.md`，并统一使用下划线 `_` 作为分隔符。
- 文件名中的日期使用该文档最近一次实际内容更新时间；若内容事实、结构或治理结论发生变化，必须同步改名并修复引用。
- 主标题和正文优先使用中文，直接描述当前状态和当前规则。
- 同一主题只保留一个事实源；如果某条规则已经写入专门文档，其它地方只链接，不重复抄写。
- `/docs` 只保留稳定资料；排查笔记、临时方案、迁移草稿不进入该目录。
- 涉及部署链路、共享包发布链路或目录结构的变更时，必须同步更新对应文档。

## 文档更新入口

- 调整顶层目录、目录职责或文档分层时，更新 [docs/governance_repository_structure_20260418.md](./docs/governance_repository_structure_20260418.md)。
- 调整任一应用版本号、正式 tag 或 release 基线时，更新 [docs/operations_deployment_baseline_20260418.md](./docs/operations_deployment_baseline_20260418.md)。
- 调整任一应用的正式设计、架构、产品或部署差异文档时，更新对应的平铺概览文档或同主题文档。
- 调整 webhook、systemd、部署脚本、部署目标注册表、发布流程、接入模板、业务源码是否仍为生产依赖或 workflow secrets 时，更新 [docs/operations_deployment_baseline_20260418.md](./docs/operations_deployment_baseline_20260418.md)。
- 调整共享前端包的目录、发布方式或接入方式时，更新 [docs/design_frontend_packages_20260417.md](./docs/design_frontend_packages_20260417.md)。
- 调整身份体系、会话模型或 IDaaS 拆分设计时，更新 [docs/idaas/idaas_design_identity_20260418.md](./docs/idaas/idaas_design_identity_20260418.md)。

## 运行约束

- 真实配置文件 `/apps/config/iterlife-stack/iterlife-deploy-webhook.env` 不入库。
- 仓库只保留 `webhook/iterlife-deploy-webhook.env.example`。
- 仓库内不存放任何真实 token、secret 或 password。

## 常用校验

```bash
bash scripts/validate-webhook-config.sh webhook/iterlife-deploy-webhook.env.example
cd packages/themes/dark-universe && npm run build
cd packages/vue/copy-action && pnpm build
```
