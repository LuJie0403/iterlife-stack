# webhook 目录说明

当前目录只保留 webhook 服务源码和示例环境文件。

## 当前文件

- `iterlife-deploy-webhook-server.py`：接收签名请求、校验 payload、调度统一部署脚本。
- `iterlife-deploy-webhook.env.example`：示例环境文件。

## 运行时位置

- 真实 env：`/apps/config/iterlife-stack/iterlife-deploy-webhook.env`
- 运行日志目录：`/apps/logs/webhook`
- 日志文件格式：`/apps/logs/webhook/iterlife-deploy-webhook-YYYY-MM-DD.log`

## 说明

- 真实运行时配置不放回仓库。
- Python 服务启动时会确保日志目录和当天日志文件存在。
- `systemd` 的 stdout / stderr 进入 `journalctl`，部署和 HTTP 事件写入按天切分的 webhook 日志文件。
- 完整部署和运维说明见 [`docs/unified-deployment-and-operations.md`](../docs/unified-deployment-and-operations.md)。
