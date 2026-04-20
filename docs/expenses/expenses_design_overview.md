# 花多少系统概览

创建日期：2026-04-18
最后更新：2026-04-20

本文档统一描述花多少 API/UI 的当前结构、部署方式和治理要点。正式文档在 `iterlife-stack/docs/expenses/` 内继续收敛为本概览文档，不再拆回仓库内 `README / deploy / archive` 一组平行文档。

## 1. 系统范围

花多少当前由两个应用组成：

- `iterlife-expenses`：FastAPI 后端
- `iterlife-expenses-ui`：Vue 3 + Vite 前端

## 2. 当前结构

### API 侧

- 主入口：`backend/app/main.py`
- 运行时配置：`backend/app/core/config.py`
- 初始化脚本：`backend/init_auth_db.py`
- 兼容脚本配置：`backend/config.py`
- 当前接口覆盖：认证、汇总、月度统计、分类、支付方式、时间线、星尘视图

### UI 侧

- 主入口：`src/main.ts`
- 页面壳层：`src/App.vue`
- 路由：`src/router/index.ts`
- API 封装：`src/services/api.ts`

## 3. 当前部署差异

### API

- `service`: `iterlife-expenses-api`
- `compose file`: `deploy/compose/expenses-api.yml`
- `healthcheck`: `http://127.0.0.1:18180/api/health`
- release workflow：`.github/workflows/expenses-release-ghcr-webhook.yml`
- runtime image：`iterlife-expenses-api:prod`

### UI

- `service`: `iterlife-expenses-ui`
- `compose file`: `deploy/compose/expenses-ui.yml`
- `healthcheck`: `http://127.0.0.1:13180`
- release workflow：`.github/workflows/expenses-ui-release-ghcr-webhook.yml`
- runtime image：`iterlife-expenses-ui:prod`

统一控制面、Webhook、部署注册表和通用执行器都由 `iterlife-stack` 维护。

## 4. 当前治理结论

- API 与 UI 属于一个业务系统，正式文档不再拆成多级目录分别维护。
- 当前最重要的结构复杂点在后端配置分为运行时配置和初始化脚本配置两套入口。
- 当前主线仍保留本地用户名密码 + JWT 登录实现，后续继续向统一身份体系收敛。
- 正式版本、发布标签与发布状态只在 `../operations_deployment_baseline.md` 维护。
- 历史 PR 描述、仓库内部署参考和阶段性归档不再进入正式文档集合。

## 5. 运行时边界

- Docker 和生产 API 实际运行的是 `backend/app/main.py`
- `backend/start.sh` 用于本地开发，内部执行 `uvicorn app.main:app --reload`
- `backend/main.py` 和 `backend/config.py` 不是生产 Docker 入口，它们保留给历史兼容路径和根目录脚本使用

这意味着当前存在两套配置模块：

- `backend/app/core/config.py`：服务运行时配置，供 FastAPI 应用与业务代码使用
- `backend/config.py`：供 `init_auth_db.py` 与兼容脚本使用

如果修改数据库、鉴权、环境变量默认值，需要同步检查这两处配置，避免行为漂移。

## 6. 数据与安全约束

- 默认数据库：`iterlife_reunion`
- 默认用户表：`user_account`
- 统一认证相关基表：`user_account`、`authenticate_identity`、`authenticate_session`、`authenticate_provider_config`
- 默认明细表：`expenses_item`
- 默认类型表：`expenses_type`
- token 使用 JWT，payload 包含 `sub` 与 `user_id`
- 生产环境要求显式设置 `SECRET_KEY`
- `DB_NAME=iterlife_reunion` 属于当前代码中的历史沿用默认值，不代表花多少与 Reunion 共用同一业务边界。

## 7. 当前边界

- 发布基线与运维事实统一收敛在 `../operations_deployment_baseline.md`。
- 认证主线仍处在本地 JWT 向统一身份体系的收敛过程中。
