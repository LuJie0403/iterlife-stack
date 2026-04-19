# iterlife-stack

IterLife 控制面、正式文档、数据库人工执行脚本与共享前端资产仓。

## 当前职责

- 统一 webhook 部署控制面。
- 统一管理正式设计、架构、产品、部署和治理文档。
- 统一管理数据库人工执行 SQL 脚本。
- 部署目标注册表与通用部署脚本。
- webhook 的 systemd 运行资产。
- 跨前端共享主题包 `@iterlife/theme-dark-universe`。
- 跨前端共享复制交互包 `@iterlife/vue-copy-action`。
- 仓库级治理、运维和跨应用文档事实源。

## 当前目录

```text
.github/workflows/    GitHub Actions 工作流
config/               部署目标注册表
docs/                 跨应用文档、应用子目录文档与数据库 SQL
packages/             前端共享包（themes / vue）
deploy/compose/       控制面持有的生产 compose 定义
scripts/              通用部署与校验脚本
systemd/              webhook 服务 unit 与 drop-in
webhook/              webhook 服务源码与示例 env
```

## 文档入口

- [docs/governance_repository_structure.md](./docs/governance_repository_structure.md)
- [docs/operations_deployment_baseline.md](./docs/operations_deployment_baseline.md)
- [docs/design_frontend_packages.md](./docs/design_frontend_packages.md)
- [docs/design_control_plane_auto_sync.md](./docs/design_control_plane_auto_sync.md)
- [docs/idaas/idaas_design_identity.md](./docs/idaas/idaas_design_identity.md)
- [docs/reunion/reunion_design_overview.md](./docs/reunion/reunion_design_overview.md)
- [docs/reunion/reunion_product_overview.md](./docs/reunion/reunion_product_overview.md)
- [docs/expenses/expenses_design_overview.md](./docs/expenses/expenses_design_overview.md)
- [docs/sql/20260419_01_idaas_provider_config.sql](./docs/sql/20260419_01_idaas_provider_config.sql)

`/docs` 是 IterLife 体系正式非代码文档与数据库人工执行脚本的单一事实源。跨应用文档直接放在 `/docs` 根目录，应用专属文档按 `expenses`、`reunion`、`idaas` 子目录规置；数据库变更脚本统一放在 `/docs/sql`。

- [docs/governance_repository_structure.md](./docs/governance_repository_structure.md)：仓库顶层目录、目录边界、准入规则和持续治理计划。
- [docs/operations_deployment_baseline.md](./docs/operations_deployment_baseline.md)：统一 GHCR + webhook 部署链路、服务器初始化、接入模板、发布检查、回滚与排障，以及当前服务器治理基线、发布矩阵、数据库变更基线与版本治理规则。
- [docs/design_frontend_packages.md](./docs/design_frontend_packages.md)：共享前端包的目录边界、发布方式和消费规则。
- [docs/design_control_plane_auto_sync.md](./docs/design_control_plane_auto_sync.md)：控制面仓库自动同步到宿主机的目标方案设计，仅用于评审，不代表当前已上线。
- [docs/idaas/idaas_design_identity.md](./docs/idaas/idaas_design_identity.md)：统一身份、会话、授权和 IDaaS 边界设计。
- [docs/reunion/reunion_design_overview.md](./docs/reunion/reunion_design_overview.md)：Reunion API/UI 的统一系统概览。
- [docs/reunion/reunion_product_overview.md](./docs/reunion/reunion_product_overview.md)：Reunion 当前产品定位、核心能力和优先级。
- [docs/expenses/expenses_design_overview.md](./docs/expenses/expenses_design_overview.md)：花多少 API/UI 的统一系统概览。
- [docs/sql/20260419_01_idaas_provider_config.sql](./docs/sql/20260419_01_idaas_provider_config.sql)：IDaaS 登录方式配置与账号来源字段的人工执行 SQL。

## 文档治理规则

- `iterlife-stack` 在生产上以宿主机控制面仓库的形式存在于 `/apps/iterlife-stack`，不作为独立业务 Docker 镜像运行。
- 控制面 webhook 当前统一以 `/usr/local/bin/python3.11` 作为运行时，不依赖宿主机默认 `python3`。
- 文件名统一使用 `app_optional_doctype_topic.md`，并统一使用下划线 `_` 作为分隔符。
- 文档正文开头统一维护“创建日期”和“最后更新”；日期信息不再进入文件名。
- SQL 文件统一使用 `yyyymmdd_NNN_topic.sql`；其中每个日期的 `NNN` 都从 `01` 开始，按当天执行顺序递增。
- 主标题和正文优先使用中文，直接描述当前状态和当前规则。
- 同一主题只保留一个事实源；如果某条规则已经写入专门文档，其它地方只链接，不重复抄写。
- `/docs` 只保留稳定资料；排查笔记、临时方案、迁移草稿不进入该目录。
- 数据库变更脚本以 `.sql` 文件单独存放在 `/docs/sql`；业务应用不通过 Flyway 等运行时迁移框架自动改库。
- 涉及部署链路、共享包发布链路或目录结构的变更时，必须同步更新对应文档。

## 文档更新入口

- 调整顶层目录、目录职责或文档分层时，更新 [docs/governance_repository_structure.md](./docs/governance_repository_structure.md)。
- 调整任一应用版本号、正式 tag 或 release 基线时，更新 [docs/operations_deployment_baseline.md](./docs/operations_deployment_baseline.md)。
- 调整任一应用的正式设计、架构、产品或部署差异文档时，更新对应的平铺概览文档或同主题文档。
- 调整 webhook、systemd、部署脚本、部署目标注册表、发布流程、业务源码是否仍为生产依赖、数据库变更管理规则或 workflow secrets 时，更新 [docs/operations_deployment_baseline.md](./docs/operations_deployment_baseline.md)。
- 调整控制面自动同步目标方案时，更新 [docs/design_control_plane_auto_sync.md](./docs/design_control_plane_auto_sync.md)。
- 调整共享前端包的目录、发布方式或接入方式时，更新 [docs/design_frontend_packages.md](./docs/design_frontend_packages.md)。
- 调整身份体系、会话模型或 IDaaS 拆分设计时，更新 [docs/idaas/idaas_design_identity.md](./docs/idaas/idaas_design_identity.md)。

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
