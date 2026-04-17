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
- [docs/governance_legacy_control_assets_retirement_20260417.md](./docs/governance_legacy_control_assets_retirement_20260417.md)
- [docs/operations_service_runtime_inventory_20260417.md](./docs/operations_service_runtime_inventory_20260417.md)
- [docs/operations_readonly_inspection_checklist_20260417.md](./docs/operations_readonly_inspection_checklist_20260417.md)
- [docs/governance_server_control_plane_20260417.md](./docs/governance_server_control_plane_20260417.md)
- [docs/shared_design_frontend_packages_20260411.md](./docs/shared_design_frontend_packages_20260411.md)
- [docs/idaas/idaas_design_identity_management_20260411.md](./docs/idaas/idaas_design_identity_management_20260411.md)
- [docs/reunion/reunion_overview_system_overview_20260411.md](./docs/reunion/reunion_overview_system_overview_20260411.md)
- [docs/reunion/reunion_product_product_overview_20260411.md](./docs/reunion/reunion_product_product_overview_20260411.md)
- [docs/expenses/expenses_overview_system_overview_20260411.md](./docs/expenses/expenses_overview_system_overview_20260411.md)

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
