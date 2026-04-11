# 花哪儿后端架构概览

本文档只描述当前代码中的真实结构，不展开重复的部署说明。标准部署链路请看 `../../unified-deployment-and-operations.md`，应用文档入口见 `../README.md`。

## 1. 代码分层

- Web API 入口：`backend/app/main.py`
- 业务路由：`backend/app/auth`、`backend/app/expenses`
- API 运行时配置：`backend/app/core/config.py`
- API 数据访问与鉴权：`backend/app/core/*`
- 本地初始化与兼容脚本配置：`backend/config.py`
- 管理员初始化：`backend/init_auth_db.py`

## 2. 对外接口

- 认证：`/api/auth/login`、`/api/auth/me`
- 消费数据：`/api/expenses/{summary,monthly,categories,payment-methods,timeline,stardust}`
- 健康检查：`/health`、`/api/health`

## 3. 运行时入口与边界

- Docker 和生产 API 实际运行的是 `backend/app/main.py`
- `backend/start.sh` 用于本地开发，内部执行 `uvicorn app.main:app --reload`
- `backend/main.py` 和 `backend/config.py` 不是生产 Docker 入口，它们保留给历史兼容路径和根目录脚本使用

这意味着有两套配置模块：

- `backend/app/core/config.py`：服务运行时配置，供 FastAPI 应用与业务代码使用
- `backend/config.py`：供 `init_auth_db.py` 与兼容脚本使用

如果修改数据库、鉴权、环境变量默认值，需要同步检查这两处配置，避免行为漂移。

## 4. 数据与安全约束

- 默认数据库：`iterlife_reunion`
- 默认用户表：`reunion_user`
- 默认明细表：`expenses_item`
- 默认类型表：`expenses_type`
- token 使用 JWT，payload 包含 `sub` 与 `user_id`
- 生产环境要求显式设置 `SECRET_KEY`

## 5. 文档与代码的一致性结论

- 当前 API 主入口与 README、Dockerfile、`backend/start.sh` 一致
- 文档已收敛为根 `README.md` 和本架构文档两个仓库内入口
- 部署脚本统一放在后端仓库根目录，UI 仓库不维护独立 `.sh` 运维脚本
- 主要需要注意的复杂点不是路由或部署，而是“运行时配置”和“初始化脚本配置”分属两套模块
