# 服务器控制面治理方案

最后更新：2026-04-17

本文档基于阿里云服务器当前 `/apps` 目录巡检结果整理，统一沉淀现状结构、问题判断、治理顺序与阶段验证机制，作为 IterLife 生产服务器控制面的正式治理方案。

## 1. 文档目标

本文档解决三个问题：

- 解释当前 `/apps` 目录下各类资产的职责边界
- 明确当前控制面存在的核心治理问题
- 给出按依赖关系排序的治理顺序与每阶段验证机制

本文档只描述治理方案，不直接执行服务器变更。

## 2. 当前结构总览

`/apps` 当前按五类职责组织：

- 应用源码目录
- 统一部署控制面目录
- 运行时配置目录
- 日志与数据目录
- 静态资源目录

当前已观测到的顶层关键目录如下：

- `/apps/config`
- `/apps/iterlife-reunion-stack`
- `/apps/iterlife-reunion`
- `/apps/iterlife-reunion-ui`
- `/apps/iterlife-expenses`
- `/apps/iterlife-expenses-ui`
- `/apps/iterlife-idaas`
- `/apps/iterlife-idaas-ui`
- `/apps/data`
- `/apps/logs`
- `/apps/static`

### 2.1 配置中心

- `/apps/config`

作用：

- 保存服务器真实运行时配置
- 按应用拆分 `backend.env`、`ui.env`
- 保存 webhook 真实 env
- 保存 Nginx 历史备份与证书相关配置

当前关键路径：

- `/apps/config/iterlife-reunion/backend.env`
- `/apps/config/iterlife-reunion/ui.env`
- `/apps/config/iterlife-expenses/backend.env`
- `/apps/config/iterlife-expenses/ui.env`
- `/apps/config/iterlife-expenses/ui-runtime-config.js`
- `/apps/config/iterlife-idaas/backend.env`
- `/apps/config/iterlife-idaas/ui.env`
- `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`
- `/apps/config/certs/aliyun-dns.env`

说明：

- 仓库中的 `.env.example` 只作模板
- 服务器真实配置统一以 `/apps/config` 为准

### 2.2 统一部署控制面

- `/apps/iterlife-reunion-stack`

作用：

- 维护统一 release workflow 基线
- 提供部署 webhook 服务
- 提供 GHCR 统一部署脚本
- 管理 deploy target 注册表
- 管理 systemd 模板与运维文档

关键资产：

- `/apps/iterlife-reunion-stack/.github/workflows/reusable-release-ghcr-webhook.yml`
- `/apps/iterlife-reunion-stack/scripts/deploy-service-from-ghcr.sh`
- `/apps/iterlife-reunion-stack/scripts/validate-webhook-config.sh`
- `/apps/iterlife-reunion-stack/webhook/iterlife-deploy-webhook-server.py`
- `/apps/iterlife-reunion-stack/systemd/iterlife-app-deploy-webhook.service`

说明：

- 该目录当前已承担全系统控制面职责
- 但目录名仍保留 `reunion` 语义，存在认知滞后

### 2.3 应用源码目录

当前纳入统一控制面的应用源码仓包括：

- `/apps/iterlife-reunion`
- `/apps/iterlife-reunion-ui`
- `/apps/iterlife-expenses`
- `/apps/iterlife-expenses-ui`
- `/apps/iterlife-idaas`
- `/apps/iterlife-idaas-ui`

当前职责：

- 保存应用源码
- 保存 Dockerfile
- 保存 compose 文件
- 保存各自仓库级 GitHub Actions workflow
- 保存应用特有文档与示例配置

### 2.4 日志、数据与静态资源

- `/apps/data`
  - 当前已观测：`/apps/data/iterlife-reunion`
- `/apps/logs`
  - 当前关键子目录：`/apps/logs/webhook`
- `/apps/static`
  - 当前关键子目录：`/apps/static/reunion`
  - `/apps/static/expenses`
  - `/apps/static/shared`

## 3. 当前发布链路

当前控制面链路可抽象为：

1. 开发者合并代码到业务仓库主分支
2. 业务仓库 release workflow 构建并推送 GHCR 镜像
3. release workflow 回调阿里云部署 webhook
4. webhook 服务校验签名并解析部署 payload
5. 统一部署脚本根据 `service` 查找 deploy target
6. 服务器执行 `docker compose up -d`
7. 目标容器更新并接受健康检查

当前链路中的关键事实源：

- workflow 模板：`/apps/iterlife-reunion-stack/.github/workflows/reusable-release-ghcr-webhook.yml`
- webhook 服务：`/apps/iterlife-reunion-stack/webhook/iterlife-deploy-webhook-server.py`
- webhook 真实配置：`/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`
- 部署执行器：`/apps/iterlife-reunion-stack/scripts/deploy-service-from-ghcr.sh`

## 4. 当前治理问题

### 4.1 控制面命名滞后

`/apps/iterlife-reunion-stack` 当前实际承担全系统控制面职责，但目录名仍带 `reunion`，与控制面角色不一致。

风险：

- 新成员会误判该目录只服务于 Reunion
- 文档、路径、配置名与仓库名长期不一致
- 后续继续扩服务时，命名债务会不断放大

### 4.2 旧资产和新控制面并存

当前旧资产与新控制面并存的典型例子包括：

- `/apps/iterlife-reunion/ops/webhook/*`
- `/apps/iterlife-reunion-stack/webhook/*`
- `/apps/iterlife-reunion-stack/systemd/*`
- `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`

风险：

- 修改错位置
- 文档内容分裂
- 事故排障时难以一眼确认哪套才是现役事实源
- 历史遗留资产会持续制造错误操作入口

### 4.3 当前运行版本不可一眼识别

当前容器镜像呈现为：

- `iterlife-reunion-api:local`
- `iterlife-reunion-ui:local`
- `iterlife-expenses-api:local`
- `iterlife-expenses-ui:local`
- `iterlife-idaas-api:local`
- `iterlife-idaas-ui:local`

问题：

- `local` 只表达“本机标签”，不表达环境和版本
- 运维人员必须阅读部署脚本，才能推断当前到底跑的是哪一个 GHCR 版本
- 线上版本回溯链不直观

### 4.4 业务源码仍驻留生产机

当前生产机仍保留完整业务仓源码目录：

- `/apps/iterlife-reunion`
- `/apps/iterlife-reunion-ui`
- `/apps/iterlife-expenses`
- `/apps/iterlife-expenses-ui`
- `/apps/iterlife-idaas`
- `/apps/iterlife-idaas-ui`

问题：

- 生产运行与源码 checkout 仍然耦合
- 容易形成手工拉代码、手工变更服务器的路径依赖
- 违反“生产运行只依赖制品和配置”的长期目标

## 5. 治理目标

目标状态如下：

- 控制面命名统一，生产事实源唯一
- 运行中的版本可直接识别，不依赖阅读部署脚本
- 旧控制面资产退出现役链路
- 业务应用部署不再依赖生产机上的源码 checkout
- 控制面、配置、数据、日志、静态资源职责边界稳定

## 6. 治理顺序

治理顺序必须服从依赖关系，不建议跳阶段推进。

### 第一阶段：基线固化与现状可观测化

目标：

- 固化 `/apps` 当前结构
- 固化 webhook、systemd、容器、日志、配置文件的对应关系
- 建立“生产事实源清单”

主要工作：

- 补齐 `/apps` 目录说明
- 补齐 deploy target 与服务映射表
- 补齐 webhook 链路说明
- 明确 Nginx 生效路径与备份路径

完成后验证：

- 任意值班人员无需读代码，能回答：
  - webhook 服务由哪个 unit 承载
  - webhook 真实 env 在哪里
  - 指定服务配置文件在哪里
  - 指定服务日志入口在哪里
- 随机抽一个服务，5 分钟内能完成只读链路巡检

通过标准：

- 结构、配置、服务、日志、发布链路均已文档化
- 第一阶段正式交付物已归档：
  - `docs/operations_unified_deployment_and_operations_20260411.md`
  - `docs/operations_service_runtime_inventory_20260417.md`
  - `docs/operations_readonly_inspection_checklist_20260417.md`

### 第二阶段：版本标识治理

依赖：

- 第一阶段完成

目标：

- 让运维人员不读脚本也能一眼判断当前生产版本

主要工作：

- 停止使用只有本机语义的 `:local`
- 引入双轨版本标识：
  - 不可变事实源：GHCR digest 或 sha tag
  - 环境别名：`prod`
- 给容器补标准 labels
- 为部署结果落部署状态文件

完成后验证：

- 任意服务都能直接查到：
  - commit sha
  - image digest
  - deploy time
  - workflow run
- 能从运行容器反查 GHCR 事实版本

通过标准：

- 版本追溯不再依赖部署脚本阅读

### 第三阶段：控制面命名与路径治理

依赖：

- 第二阶段完成

目标：

- 将控制面路径与语义统一到 `iterlife-stack`

主要工作：

- 统一控制面源码目录名
- 统一 `/apps/config` 下控制面配置目录名
- 统一 systemd、脚本、文档、运维命令中的绝对路径
- 使用兼容迁移，不做一次性硬切

建议策略：

- 先建立新路径
- 再切换引用
- 再保留旧路径兼容
- 最后移除旧路径

完成后验证：

- webhook 服务正常启动
- release workflow 能正常回调 webhook
- deploy target 能正常解析
- 全量巡检不再依赖旧控制面路径
- 保留明确可执行的回滚路径

通过标准：

- 新路径成为唯一主路径
- 旧路径只保留临时兼容角色

### 第四阶段：旧资产退场治理

依赖：

- 第三阶段完成

目标：

- 让生产事实源唯一，消除旧控制面资产造成的歧义

主要工作：

- 识别旧 webhook 资产、旧 service 模板、旧 example 配置
- 标记哪些为 archived，哪些为 deprecated
- 从业务仓中移除已被控制面接管的现役部署资产

完成后验证：

- 任一部署能力只保留一套现役事实源
- 仓库检索 webhook 关键实现时，不再出现双事实源冲突
- 值班人员不会对“哪套在生产生效”产生歧义

通过标准：

- 历史资产不再参与生产链路

### 第五阶段：业务源码退出生产机治理

依赖：

- 前四阶段完成

目标：

- 让业务服务运行与发布不再依赖生产机上的源码 checkout

主要工作：

- 梳理当前业务部署还依赖哪些源码目录文件
- 将必要部署元数据迁入控制面或独立制品目录
- 让生产运行仅依赖：
  - GHCR 镜像
  - 控制面脚本
  - `/apps/config`
  - `/apps/data`
  - `/apps/logs`
  - `/apps/static`

完成后验证：

- 删除业务源码 checkout 后，服务仍能重建和发布
- 新版本发布不再依赖服务器上的业务仓 git 工作树
- 配置、compose、日志、静态资源、数据均能独立工作

通过标准：

- 业务应用源码目录退出生产机运行依赖

### 第六阶段：收口与制度化治理

依赖：

- 前五阶段完成

目标：

- 将治理成果固化为制度和模板

主要工作：

- 输出服务器目录基线文档
- 输出新增服务接入模板
- 输出 deploy target 注册规范
- 输出镜像标签与版本追溯规范
- 输出运行配置规范
- 输出变更前后验证清单

完成后验证：

- 用新增服务接入演练验证模板可复用
- 用一次故障排查演练验证文档可执行

通过标准：

- 治理成果可复用、可培训、可审计

## 7. 通用验证机制

每个阶段完成后，都建议执行以下四类验证：

### 7.1 结构验证

- 路径是否与文档一致
- 引用是否已经全部切换
- 是否仍存在双事实源冲突

### 7.2 运行验证

- webhook 服务正常
- systemd unit 正常
- 核心容器正常
- 健康检查通过

### 7.3 发布验证

- 通过标准 CI/CD 发起一次非破坏性测试发布
- 验证 workflow -> webhook -> deploy script -> container 更新链路完整

### 7.4 回滚验证

- 能回到治理前状态
- 回滚步骤明确、可复现、可文档化执行

## 8. 实施约束

- 治理动作必须通过代码、PR、审批和标准 CI/CD 流程推进
- 不通过旁路手工变更完成结构治理
- 任何删除动作必须在兼容迁移与验证完成后执行
- 任何生产事实源迁移都必须先补文档、再改链路、后删旧资产

## 9. 结论

当前服务器控制面已经具备统一发布、统一配置和统一日志入口的基础，但仍处于“控制面已形成、运行资产尚未完全制品化”的过渡阶段。

后续治理应坚持以下主线：

1. 先固化基线，再做重命名和清理
2. 先补版本可观测性，再做路径迁移
3. 先建立唯一事实源，再让源码退出生产机
4. 每一步都必须有结构、运行、发布、回滚四类验证

## 10. 相关文档

- `docs/operations_unified_deployment_and_operations_20260411.md`
- `docs/operations_service_runtime_inventory_20260417.md`
- `docs/operations_readonly_inspection_checklist_20260417.md`
- `docs/governance_repository_directory_20260411.md`
- `docs/version_matrix_20260411.md`
