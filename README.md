# iterlife-stack / IterLife Stack

## 项目概述 / Overview

`iterlife-stack` 是 IterLife 体系的控制面仓库，负责统一部署控制、正式文档治理和共享前端资产维护。

## 当前职责 / Current Scope

- 维护统一 webhook + GHCR + Aliyun 的部署控制面。
- 维护 IterLife 正式文档事实源。
- 维护共享前端包与主题资产。
- 维护部署目标注册表、通用脚本和 webhook 运行资产。

## 目录与边界 / Structure and Boundaries

- `.github/workflows/`: GitHub Actions 工作流
- `config/`: 部署目标注册表
- `docs/`: 正式文档事实源
- `packages/`: 前端共享包
- `scripts/`: 通用脚本
- `systemd/`: webhook systemd 资产
- `webhook/`: webhook 服务源码与示例配置

## 本地运行 / Local Development

常用校验命令：

```bash
bash scripts/validate-webhook-config.sh webhook/iterlife-deploy-webhook.env.example
cd packages/themes/dark-universe && npm run build
cd packages/vue/copy-action && pnpm build
```

版本查询入口：

- `bash scripts/show-runtime-versions.sh`

## 文档入口
## 关键入口 / Key Entry Points

- `config/deploy-targets.json`
- `scripts/`
- `packages/themes/dark-universe/`
- `packages/vue/copy-action/`
- `webhook/`

## 文档入口 / Documentation

- [docs/governance_repository_directory_20260411.md](./docs/governance_repository_directory_20260411.md)
- [docs/version_matrix_20260411.md](./docs/version_matrix_20260411.md)
- [docs/operations_unified_deployment_and_operations_20260411.md](./docs/operations_unified_deployment_and_operations_20260411.md)
- [docs/governance_control_plane_path_cutover_20260417.md](./docs/governance_control_plane_path_cutover_20260417.md)
- [docs/governance_legacy_control_assets_retirement_20260417.md](./docs/governance_legacy_control_assets_retirement_20260417.md)
- [docs/operations_service_runtime_inventory_20260417.md](./docs/operations_service_runtime_inventory_20260417.md)
- [docs/operations_readonly_inspection_checklist_20260417.md](./docs/operations_readonly_inspection_checklist_20260417.md)
- [docs/governance_server_control_plane_20260417.md](./docs/governance_server_control_plane_20260417.md)
- [docs/shared_design_frontend_packages_20260411.md](./docs/shared_design_frontend_packages_20260411.md)
- [docs/idaas/idaas_design_identity_management_20260411.md](./docs/idaas/idaas_design_identity_management_20260411.md)
- [docs/reunion/reunion_overview_system_overview_20260411.md](./docs/reunion/reunion_overview_system_overview_20260411.md)
- [docs/reunion/reunion_product_product_overview_20260411.md](./docs/reunion/reunion_product_product_overview_20260411.md)
- [docs/expenses/expenses_overview_system_overview_20260411.md](./docs/expenses/expenses_overview_system_overview_20260411.md)

`/docs` 是 IterLife 体系正式非代码文档的单一事实源。跨应用文档直接放在 `/docs` 根目录，应用专属文档按 `expenses`、`reunion`、`idaas` 子目录规置。

- [docs/governance_repository_directory_20260411.md](./docs/governance_repository_directory_20260411.md)：仓库顶层目录、目录边界、准入规则和持续治理计划。
- [docs/version_matrix_20260411.md](./docs/version_matrix_20260411.md)：当前应用版本矩阵、版本台账和统一版本治理规则。
- [docs/operations_unified_deployment_and_operations_20260411.md](./docs/operations_unified_deployment_and_operations_20260411.md)：统一 GHCR + webhook 部署链路、服务器初始化、发布检查、回滚与排障，以及当前服务器治理基线与 secrets 事实。
- [docs/governance_control_plane_operating_baseline_20260417.md](./docs/governance_control_plane_operating_baseline_20260417.md)：控制面运行基线、新服务接入标准、镜像命名、配置规范与禁止项。
- [docs/operations_service_onboarding_template_20260417.md](./docs/operations_service_onboarding_template_20260417.md)：新增服务接入统一控制面的执行模板与验证清单。
- [docs/shared_design_frontend_packages_20260411.md](./docs/shared_design_frontend_packages_20260411.md)：共享前端包的目录边界、发布方式和消费规则。
- [docs/idaas/idaas_design_identity_management_20260411.md](./docs/idaas/idaas_design_identity_management_20260411.md)：统一身份、会话、授权和 IDaaS 拆分设计。
- [docs/reunion/reunion_overview_system_overview_20260411.md](./docs/reunion/reunion_overview_system_overview_20260411.md)：Reunion API/UI 的统一系统概览。
- [docs/reunion/reunion_product_product_overview_20260411.md](./docs/reunion/reunion_product_product_overview_20260411.md)：Reunion 当前产品定位、核心能力和优先级。
- [docs/expenses/expenses_overview_system_overview_20260411.md](./docs/expenses/expenses_overview_system_overview_20260411.md)：花多少 API/UI 的统一系统概览。

## 文档治理规则

- 文件名统一使用 `app_optional_doctype_topic_yyyymmdd.md`，并统一使用下划线 `_` 作为分隔符。
- 主标题和正文优先使用中文，直接描述当前状态和当前规则。
- 同一主题只保留一个事实源；如果某条规则已经写入专门文档，其它地方只链接，不重复抄写。
- `/docs` 只保留稳定资料；排查笔记、临时方案、迁移草稿不进入该目录。
- 涉及部署链路、共享包发布链路或目录结构的变更时，必须同步更新对应文档。

## 文档更新入口

- 调整顶层目录、目录职责或文档分层时，更新 [docs/governance_repository_directory_20260411.md](./docs/governance_repository_directory_20260411.md)。
- 调整任一应用版本号、正式 tag 或 release 基线时，更新 [docs/version_matrix_20260411.md](./docs/version_matrix_20260411.md)。
- 调整任一应用的正式设计、架构、产品或部署差异文档时，更新对应的平铺概览文档或同主题文档。
- 调整 webhook、systemd、部署脚本、部署目标注册表、发布流程或 workflow secrets 时，更新 [docs/operations_unified_deployment_and_operations_20260411.md](./docs/operations_unified_deployment_and_operations_20260411.md)。
- 调整控制面制度、接入标准、发布禁止项或值班完成定义时，更新 [docs/governance_control_plane_operating_baseline_20260417.md](./docs/governance_control_plane_operating_baseline_20260417.md)。
- 新增服务接入统一控制面时，按 [docs/operations_service_onboarding_template_20260417.md](./docs/operations_service_onboarding_template_20260417.md) 执行并回填结果。
- 调整共享前端包的目录、发布方式或接入方式时，更新 [docs/shared_design_frontend_packages_20260411.md](./docs/shared_design_frontend_packages_20260411.md)。
- 调整身份体系、会话模型或 IDaaS 拆分设计时，更新 [docs/idaas/idaas_design_identity_management_20260411.md](./docs/idaas/idaas_design_identity_management_20260411.md)。

## 运行约束

- 真实配置文件 `/apps/config/iterlife-stack/iterlife-deploy-webhook.env` 不入库。
- 仓库只保留 `webhook/iterlife-deploy-webhook.env.example`。
- 仓库内不存放任何真实 token、secret 或 password。

## 常用校验
## 质量检查 / Quality Checks

```bash
bash scripts/validate-webhook-config.sh webhook/iterlife-deploy-webhook.env.example
cd packages/themes/dark-universe && npm run build
cd packages/vue/copy-action && pnpm build
```

## 交付约束 / Delivery Constraints

- 正式非代码文档统一维护在 `/docs`。
- 真实配置、真实 secret 和生产环境变量不入库。
- 影响部署、版本、共享包或文档治理的改动，必须同步更新正式文档。
- 生产发布只通过标准 CI/CD 流程执行，不使用旁路发布方式。
