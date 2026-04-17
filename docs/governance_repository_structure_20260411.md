# 仓库目录基线

最后更新：2026-04-11

本文档定义 `iterlife-stack` 当前目录边界和正式文档维护规则。

## 1. 仓库定位

当前仓库承担三类职责：

- IterLife 统一 CI/CD 控制面。
- IterLife 正式非代码文档事实源。
- IterLife 跨前端共享包发布源仓库。

因此，本仓库只保留控制面资产、正式文档资产和共享包资产，不承载业务应用源码。

## 2. 当前顶层目录

```text
.github/workflows/    仓库级自动化工作流
config/               可入库的静态部署配置
docs/                 跨应用文档与应用子目录文档
packages/             共享前端包
scripts/              通用部署与校验脚本
systemd/              webhook 服务 unit 与 drop-in
webhook/              webhook 服务源码与示例环境文件
```

补充说明：

- `.codex/` 是协作记忆子模块，不属于正式文档体系。
- `.idea/` 和 `node_modules/` 属于本地环境产物，不属于仓库结构主干。

## 3. 目录治理规则

### 3.1 顶层目录准入

- 新增顶层目录前，必须先证明现有目录无法承载该职责。
- 新增目录后，必须同步更新本文档。
- 运行时 secret、日志、容器数据和服务器状态不进入仓库。

### 3.2 配置与脚本分离

- 静态事实放 `config/`。
- 执行动作放 `scripts/`。
- 运行时模板放 `webhook/*.example` 一类示例文件。
- 部署控制面现役资产只保留在当前控制面仓中；历史部署资产如已退出主链路，应标记为遗留，不再在业务仓内继续扩散。

### 3.3 文档治理

- `/docs` 根目录只放跨应用文档；应用专属文档规置到 `docs/expenses/`、`docs/reunion/`、`docs/idaas/`。
- 文件名统一使用 `app_optional_doctype_topic_yyyymmdd.md`，统一使用下划线 `_` 作为分隔符。
- 功能相同或相近的文档必须合并，避免 API/UI 各写一份近似说明。
- 只有在内容确实无法合并时，才通过应用子目录和应用名前缀区分，例如 `docs/reunion/reunion_design_overview_20260411.md`、`docs/expenses/expenses_design_overview_20260411.md`。
- 目录索引型 README、历史 PR 描述、阶段性草稿、过细的拆分文档不保留在正式文档集合中。

## 4. 文档更新入口

- 目录结构或治理规则变化：更新本文档。
- 版本号或发布基线变化：更新 `version_matrix_20260411.md`。
- 部署链路、Secrets、服务器路径变化：更新 `operations_unified_deployment_and_operations_20260411.md`。
- 旧控制面资产退场、现役事实源变化：更新 `governance_legacy_control_assets_retirement_20260417.md`。
- 共享包边界、发布或接入方式变化：更新 `shared_design_frontend_packages_20260411.md`。
- 身份体系、会话模型、IDaaS 拆分变化：更新 `idaas/idaas_design_identity_management_20260411.md`。
- 应用结构或核心产品方向变化：更新对应的应用概览文档。
