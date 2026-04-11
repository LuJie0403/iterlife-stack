# IterLife Expenses API Deployment Reference

最后更新：2026-03-26

本文件只保留 `iterlife-expenses-api` 的部署差异项。统一 CI/CD 流程、控制面实现、Webhook 协议、回滚与服务器操作，以 `../../unified-deployment-and-operations.md` 为准。

## Scope

当前仓库只维护以下可部署单元资产：

- `Dockerfile`
- `deploy/compose/expenses-api.yml`
- `.github/workflows/expenses-pr-ci.yml`
- `.github/workflows/expenses-release-ghcr-webhook.yml`

当前仓库不再维护：

- 生产源码部署脚本
- 服务器 `git pull` 发布脚本
- GHCR 部署包装脚本
- 跨仓库编排脚本
- 手工 release 入口

## App-Specific Values

- `service`: `iterlife-expenses-api`
- `image`: `ghcr.io/<owner>/iterlife-expenses-api:<tag>`
- `local image`: `iterlife-expenses-api:local`
- `compose file`: `deploy/compose/expenses-api.yml`
- `compose service`: `iterlife-expenses-api`
- `healthcheck`: `http://127.0.0.1:18180/api/health`

## Verification

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
curl -fsS http://127.0.0.1:18180/api/health
```
