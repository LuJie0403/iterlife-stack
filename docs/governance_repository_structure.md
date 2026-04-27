# 仓库目录基线

创建日期：2026-04-18
最后更新：2026-04-27

本文档定义 `iterlife-stack` 当前目录边界、控制面治理结论和正式文档维护规则。此前分散在多份 `governance_*` 根目录文档中的稳定结论，已经统一收敛到本文件。

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
- 文件名统一使用 `app_optional_doctype_topic.md`，统一使用下划线 `_` 作为分隔符。
- 文档日期信息不再进入文件名；每份文档在正文开头显式记录“创建日期”和“最后更新”。
- 数据库变更不再通过 Flyway 等运行时迁移框架管理；业务应用仓库不保留自动改库链路。
- 业务系统数据库变更脚本保留在对应业务仓的 `database/` 目录，不再统一存放在 `iterlife-stack`。
- 功能相同或相近的文档必须合并，避免 API/UI 各写一份近似说明。
- 只有在内容确实无法合并时，才通过应用子目录和应用名前缀区分，例如 `docs/reunion/reunion_design_overview.md`、`docs/expenses/expenses_design_overview.md`。
- 应用文档优先收敛为少量“概览型”事实源，不恢复仓库内 `README`、`deploy`、`archive`、`ui-governance` 等平行文档集合。
- 目录索引型 README、历史 PR 描述、阶段性草稿、过细的拆分文档不保留在正式文档集合中。

### 3.4 根目录正式文档集合

`/docs` 根目录当前只保留以下稳定事实源：

- `governance_repository_structure.md`
- `operations_deployment_baseline.md`
- `design_frontend_packages.md`

这意味着以下类型的根目录文档不再单独保留：

- 阶段性治理切换清单
- 历史资产退场说明
- 控制面运行制度拆分稿
- 与正式运维基线重复的接入模板或运维说明

此类文档的稳定结论应并回上述正式事实源。

## 4. 控制面治理基线

### 4.1 控制面唯一事实源

当前生产部署控制面的唯一现役事实源为：

- 控制面仓库：`iterlife-stack`
- 控制面服务器主目录：`/apps/iterlife-stack`
- 控制面真实配置目录：`/apps/config/iterlife-stack`
- 控制面运维文档事实源：`docs/operations_deployment_baseline.md`

其中：

- `iterlife-stack` 是宿主机常驻控制面仓库，不是单独对外提供业务能力的 Docker 应用服务。
- 它既不是“只是一个静态知识库”，也不在统一部署矩阵里以独立容器运行；真正以 Docker 运行的是各业务应用服务。

以下对象不再视为现役事实源：

- 历史 `iterlife-reunion-stack` 仓库名和路径
- 业务仓内的历史部署控制资产
- 依赖业务源码目录的生产 compose
- 手工服务器操作形成的非受控发布路径

### 4.2 业务源码退出生产依赖

当前治理结论是：

- 生产 compose 事实源统一由 `iterlife-stack/deploy/compose/` 承担
- `config/deploy-targets.json` 不再要求业务源码目录作为部署依赖
- 生产部署依赖 GHCR 镜像、`/apps/config/*`、`/apps/data/*`、`/apps/logs/*` 与控制面资产
- 服务器上若仍保留业务源码目录，只视为历史遗留，不再视为生产部署事实源

### 4.3 旧资产退场口径

- `iterlife-stack/webhook/*` 与 `iterlife-stack/systemd/*` 是唯一现役部署控制面入口
- `iterlife-reunion` 中的 webhook 代码属于业务 webhook，不属于部署控制面
- 历史部署控制目录如 `/apps/iterlife-reunion/ops/webhook/*` 若仍存在，只视为遗留资产

### 4.4 命名与路径切换结论

当前控制面相关引用统一切换到：

- 仓库名：`iterlife-stack`
- 服务器目录：`/apps/iterlife-stack`
- 配置目录：`/apps/config/iterlife-stack`

所有正式文档、README 和 workflow 说明都应以此为准，不再保留 `iterlife-reunion-stack` 口径。

### 4.5 运行制度化要求

新增服务接入统一控制面时，必须同时满足：

- 控制面仓中存在独立 `deploy/compose/<service>.yml`
- `config/deploy-targets.json` 中存在完整注册项
- 发布链路对共享 reusable workflow 的引用已建立
- 真实运行配置目录与健康检查地址已定义
- 变更已纳入正式运维文档

禁止继续引入：

- `repo_dir` 一类依赖业务源码目录的部署字段
- 指向业务源码目录的生产 compose 路径
- 手工部署作为正式发布路径

## 5. 变更验证机制

每次控制面结构或治理规则变更后，至少执行以下校验：

### 5.1 结构验证

```bash
find deploy/compose -maxdepth 1 -type f | sort
rg -n 'iterlife-reunion-stack|/apps/iterlife-(reunion|expenses|idaas)' config scripts docs README.md
```

预期：

- 根目录正式文档集合不继续膨胀
- 控制面事实源文件中不再出现旧仓库名或业务源码目录依赖

### 5.2 配置校验

```bash
bash scripts/validate-webhook-config.sh webhook/iterlife-deploy-webhook.env.example config/deploy-targets.json
```

### 5.3 脚本校验

```bash
bash -n scripts/deploy-service-from-ghcr.sh
python3 -m py_compile webhook/iterlife-deploy-webhook-server.py
```

## 6. 文档更新入口

- 目录结构或治理规则变化：更新本文档。
- 版本号或发布基线变化：更新 `operations_deployment_baseline.md`。
- 部署链路、Secrets、服务器路径、接入模板、回滚与巡检规则变化：更新 `operations_deployment_baseline.md`。
- 数据库结构或数据库初始化规则变化：在对应业务仓的 `database/` 新增独立 SQL 文件，并同步更新 `operations_deployment_baseline.md` 和相关应用设计文档。
- 共享包边界、发布或接入方式变化：更新 `design_frontend_packages.md`。
- 身份体系、会话模型、IDaaS 拆分变化：更新 `idaas/idaas_design_identity.md`。
- 应用结构或核心产品方向变化：更新对应的应用概览文档。
