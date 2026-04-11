# IterLife Expenses UI Deployment Reference

最后更新：2026-03-26

本文件只保留 `iterlife-expenses-ui` 的部署差异项。统一 CI/CD 流程、控制面实现、Webhook 协议、回滚与服务器操作，以 `../../unified-deployment-and-operations.md` 为准。

## Scope

当前仓库只维护以下可部署单元资产：

- `Dockerfile`
- `deploy/compose/expenses-ui.yml`
- `.github/workflows/expenses-ui-pr-ci.yml`
- `.github/workflows/expenses-ui-release-ghcr-webhook.yml`

当前仓库不再维护：

- 生产部署 shell
- 手工 release 入口
- 共享 webhook / systemd 资产
- 部署注册表
- 通用部署执行器

## App-Specific Values

- `service`: `iterlife-expenses-ui`
- `image`: `ghcr.io/<owner>/iterlife-expenses-ui:<tag>`
- `local image`: `iterlife-expenses-ui:local`
- `compose file`: `deploy/compose/expenses-ui.yml`
- `compose service`: `iterlife-expenses-ui`
- `healthcheck`: `http://127.0.0.1:13180`
- `release workflow note`: wrapper workflow passes `use_node_auth_token: true`

## Verification

```bash
docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Image}}'
curl -fsS http://127.0.0.1:13180
```
