# 花多少系统概览

最后更新：2026-04-11

本文档统一描述花多少 API/UI 的当前结构、部署差异和治理要点。

## 1. 系统范围

花多少当前由两个应用组成：

- `iterlife-expenses`：FastAPI 后端
- `iterlife-expenses-ui`：Vue 3 + Vite 前端

## 2. 当前结构

### API 侧

- 主入口：`backend/app/main.py`
- 运行时配置：`backend/app/core/config.py`
- 初始化脚本：`backend/init_auth_db.py`
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

### UI

- `service`: `iterlife-expenses-ui`
- `compose file`: `deploy/compose/expenses-ui.yml`
- `healthcheck`: `http://127.0.0.1:13180`
- release workflow：`.github/workflows/expenses-ui-release-ghcr-webhook.yml`

统一控制面、Webhook、部署注册表和通用执行器都由 `iterlife-stack` 维护。

## 4. 当前治理结论

- API 与 UI 属于一个业务系统，正式文档不再拆成多级目录分别维护。
- 当前最重要的结构复杂点在后端配置分为运行时配置和初始化脚本配置两套入口。
- 花多少当前统一版本基线已收敛到 `1.1.0 / release_v1.1.0`：
  - API 已声明 `1.1.0`
  - UI 已声明 `1.1.0`
  - 历史 `openclaw-expenses_v*` 标签不再作为当前标准版本线

## 5. 当前重点

- 保持 API/UI 版本与标签同步治理
- 视需要补充 `1.1.0` 版本说明
- 持续收敛认证模型，准备接入统一身份体系
