# 部署与运维手册

最后更新：2026-03-26

本文档描述 `iterlife-reunion-stack` 当前统一部署链路的真实结构、运行资产和日常操作方式。

## 1. 适用范围

当前统一纳入控制面的服务包括：

- `iterlife-reunion-api`
- `iterlife-reunion-ui`
- `iterlife-expenses-api`
- `iterlife-expenses-ui`

## 2. 标准发布路径

生产发布统一经过以下链路：

1. 业务仓库提交 PR。
2. PR 合并到 `main`。
3. GitHub Actions 构建镜像并推送 GHCR。
4. 共享 release workflow 回调部署 webhook。
5. webhook 按 `service` 命中 `config/deploy-targets.json`。
6. `scripts/deploy-service-from-ghcr.sh` 执行镜像拉取、打标、`docker compose up -d` 和健康检查。

## 3. 仓库职责边界

### 3.1 控制面仓库

本仓库负责：

- 统一 webhook 服务。
- 统一部署执行脚本。
- 部署目标注册表。
- systemd 运行资产。
- 统一运维文档。
- 共享 release workflow。

### 3.2 业务仓库

业务仓库负责：

- 应用源码。
- `Dockerfile`。
- 单服务 compose 文件。
- PR 校验 workflow。
- 调用共享 release workflow 的 wrapper workflow。

## 4. 命名规则

当前部署链路使用统一 service key：

- API 服务使用 `-api` 后缀。
- UI 服务使用 `-ui` 后缀。
- GHCR image name、compose service name、部署注册表 key 与 service key 保持一致。

## 5. 当前部署矩阵

| Service | Repo Dir | Compose File | Compose Service | Healthcheck |
| --- | --- | --- | --- | --- |
| `iterlife-reunion-api` | `/apps/iterlife-reunion` | `/apps/iterlife-reunion/deploy/compose/reunion-api.yml` | `iterlife-reunion-api` | `http://127.0.0.1:18080/api/health` |
| `iterlife-reunion-ui` | `/apps/iterlife-reunion-ui` | `/apps/iterlife-reunion-ui/deploy/compose/reunion-ui.yml` | `iterlife-reunion-ui` | `http://127.0.0.1:13080` |
| `iterlife-expenses-api` | `/apps/iterlife-expenses` | `/apps/iterlife-expenses/deploy/compose/expenses-api.yml` | `iterlife-expenses-api` | `http://127.0.0.1:18180/api/health` |
| `iterlife-expenses-ui` | `/apps/iterlife-expenses-ui` | `/apps/iterlife-expenses-ui/deploy/compose/expenses-ui.yml` | `iterlife-expenses-ui` | `http://127.0.0.1:13180` |

以上事实源以 `config/deploy-targets.json` 为准。

## 6. 仓库内关键资产

| 路径 | 用途 |
| --- | --- |
| `config/deploy-targets.json` | 服务到 compose 目标的注册表 |
| `scripts/deploy-service-from-ghcr.sh` | 统一部署执行器 |
| `scripts/validate-webhook-config.sh` | 示例 env 和目标注册表校验脚本 |
| `webhook/iterlife-deploy-webhook-server.py` | webhook 接收与调度服务 |
| `webhook/iterlife-deploy-webhook.env.example` | webhook 示例环境文件 |
| `systemd/iterlife-app-deploy-webhook.service` | webhook 服务 unit |
| `systemd/iterlife-app-deploy-webhook.service.d/10-log-perms.conf` | webhook 日志权限 drop-in |
| `.github/workflows/reusable-release-ghcr-webhook.yml` | 共享镜像发布与 webhook 回调 workflow |

## 7. 服务器运行时路径

当前服务器运行时路径如下：

- 控制面仓库：`/apps/iterlife-reunion-stack`
- webhook 真实 env：`/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`
- webhook 日志目录：`/apps/logs/webhook`
- systemd unit：`/etc/systemd/system/iterlife-app-deploy-webhook.service`
- systemd drop-in：`/etc/systemd/system/iterlife-app-deploy-webhook.service.d/`

## 8. GitHub Actions 与 Secrets

Secrets 事实清单见 [github-actions-secrets-inventory.md](./github-actions-secrets-inventory.md)。

当前链路中：

- 业务仓库 release wrapper 必须提供 `ALIYUN_DEPLOY_WEBHOOK_URL` 和 `ALIYUN_DEPLOY_WEBHOOK_SECRET`。
- `iterlife-reunion-stack` 自身用于 npm 发布的 secret 是 `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`。

## 9. 新服务器初始化

### 9.1 拉取控制面仓库

```bash
cd /apps
git clone git@github.com:LuJie0403/iterlife-reunion-stack.git
cd /apps/iterlife-reunion-stack
git switch main
```

### 9.2 配置 webhook 环境文件

```bash
mkdir -p /apps/config/iterlife-reunion-stack
cp webhook/iterlife-deploy-webhook.env.example \
  /apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env
```

然后填写真实 secret 和运行参数。

### 9.3 安装 systemd 资产

```bash
sudo install -D -m 644 systemd/iterlife-app-deploy-webhook.service \
  /etc/systemd/system/iterlife-app-deploy-webhook.service

sudo install -D -m 644 systemd/iterlife-app-deploy-webhook.service.d/10-log-perms.conf \
  /etc/systemd/system/iterlife-app-deploy-webhook.service.d/10-log-perms.conf

sudo systemctl daemon-reload
sudo systemctl enable --now iterlife-app-deploy-webhook.service
```

### 9.4 启动前校验

```bash
cd /apps/iterlife-reunion-stack
bash scripts/validate-webhook-config.sh \
  /apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env
```

## 10. 日常发布检查

正常发布不需要登录服务器执行部署脚本。日常检查只看以下两侧。

### 10.1 GitHub Actions 侧

- release workflow 成功。
- `build-and-push-image` 成功。
- `callback-aliyun-webhook` 成功。
- `image_ref` 指向 `ghcr.io/<owner>/<service>:sha-<commit>`。

### 10.2 服务器侧

```bash
sudo systemctl status iterlife-app-deploy-webhook.service --no-pager
tail -n 120 /apps/logs/webhook/iterlife-deploy-webhook-$(date +%F).log
sudo docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}'
```

## 11. 健康检查

发布后可直接验证：

```bash
curl -fsS http://127.0.0.1:18080/api/health
curl -fsS http://127.0.0.1:13080
curl -fsS http://127.0.0.1:18180/api/health
curl -fsS http://127.0.0.1:13180
```

## 12. 常用运维命令

### 12.1 webhook 服务

```bash
sudo systemctl restart iterlife-app-deploy-webhook.service
sudo systemctl status iterlife-app-deploy-webhook.service --no-pager
sudo journalctl -u iterlife-app-deploy-webhook.service -n 200 --no-pager
```

### 12.2 webhook 业务日志

```bash
tail -n 200 /apps/logs/webhook/iterlife-deploy-webhook-$(date +%F).log
grep -n "deploy failed" /apps/logs/webhook/iterlife-deploy-webhook-$(date +%F).log
```

### 12.3 容器状态

```bash
sudo docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}'
sudo docker inspect --format 'table {{.Id}}\t{{.Name}}\t{{.State.Status}}\t{{.State.StartedAt}}\t{{.Config.Image}}' $(sudo docker ps -q)
```

### 12.4 同步控制面代码

```bash
cd /apps/iterlife-reunion-stack
git fetch origin
git switch main
git pull --ff-only origin main
```

## 13. webhook dry-run

```bash
WEBHOOK_URL="http://127.0.0.1:19091/hooks/app-deploy"
WEBHOOK_SECRET="..."

payload='{
  "service": "iterlife-reunion-api",
  "environment": "production",
  "repository": "LuJie0403/iterlife-reunion",
  "commit_sha": "dry-run-verify",
  "image_ref": "ghcr.io/lujie0403/iterlife-reunion-api:dry-run",
  "image_digest": "sha256:dryrun",
  "dry_run": true
}'

signature="sha256=$(printf '%s' "$payload" | openssl dgst -sha256 -hmac "$WEBHOOK_SECRET" -hex | sed 's/^.* //')"

curl -fsS -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -H "X-Signature-256: $signature" \
  --data "$payload"
```

## 14. 回滚

标准回滚继续走同一套镜像部署链路，不回退到源码部署。

```bash
payload='{
  "service": "iterlife-expenses-api",
  "environment": "production",
  "repository": "LuJie0403/iterlife-expenses",
  "commit_sha": "manual-rollback",
  "image_ref": "ghcr.io/lujie0403/iterlife-expenses-api:sha-<old_commit>",
  "image_digest": "sha256:<old_digest>"
}'
```

签名方式与 dry-run 相同。回滚后检查：

- webhook 返回 `202`。
- 日志出现 `deploy success`。
- 容器启动时间更新。
- 健康检查恢复。

## 15. 常见问题

### 15.1 webhook 返回 `401`

通常表示 `ALIYUN_DEPLOY_WEBHOOK_SECRET` 与服务器 `WEBHOOK_SECRET` 不一致。

### 15.2 webhook 返回 `unsupported service`

通常表示业务仓库传入的 `service` 未在 `config/deploy-targets.json` 注册，或命名未遵守 `-api` / `-ui` 规则。

### 15.3 镜像已推送但容器未更新

优先检查：

- webhook 日志中的 `compose_service`。
- `config/deploy-targets.json` 的 `compose_file` 和 `compose_service`。
- 容器 `Config.Image` 是否已经指向预期镜像。

### 15.4 健康检查失败

优先检查：

- webhook 日志末尾输出。
- 容器运行日志。
- 本地健康检查地址是否可直接访问。

## 16. 变更检查清单

涉及部署链路的变更，至少同步检查：

- `config/deploy-targets.json`
- `scripts/deploy-service-from-ghcr.sh`
- `webhook/iterlife-deploy-webhook-server.py`
- `.github/workflows/reusable-release-ghcr-webhook.yml`
- [github-actions-secrets-inventory.md](./github-actions-secrets-inventory.md)

如有目录边界变化，再同步更新 [repository-directory-governance.md](./repository-directory-governance.md)。
