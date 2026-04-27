# iterlife-stack

IterLife 控制面与正式文档仓。

## 当前职责

- 统一维护跨系统正式文档
- 统一维护部署控制面、webhook 与通用部署资产
- 统一维护共享前端资产与仓库级治理规则

本仓库不再保存业务系统的过程型数据库脚本、阶段性迁移草稿或旧版 IDaaS 设计分支文档。

## 目录边界

```text
.github/workflows/    控制面与共享包工作流
config/               部署目标注册表
deploy/compose/       控制面持有的生产 compose 定义
docs/                 正式跨系统文档
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

`/docs` 只保留稳定、当前有效的正式文档。过程型 SQL、临时方案、迁移草稿和已废弃设计不再进入该目录。

## 文档治理规则

- 同一主题只保留一个事实源。
- 文档正文开头统一维护“创建日期”和“最后更新”。
- 文件名统一使用下划线 `_`。
- 业务系统数据库变更脚本保留在对应业务仓的 `database/` 目录，不再统一收口在控制面仓。
- 任何涉及正式运行规则的变更，都必须同步更新对应正式文档。

## 当前 IDaaS 文档基线

- 控制面仓唯一正式设计文档： [docs/idaas/idaas_design_identity.md](./docs/idaas/idaas_design_identity.md)
- 后端最终迁移脚本：`iterlife-idaas/database/20260427_01_account_auth_baseline.sql`

## 运行约束

- 真实配置文件不入库。
- 仓库内不存放任何真实 token、secret 或 password。
- 控制面 webhook 当前统一以 `/usr/local/bin/python3.11` 作为运行时，不依赖宿主机默认 `python3`。
