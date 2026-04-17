# 统一部署与运维

最后更新：2026-04-17

本文档是 IterLife 当前统一部署事实源，覆盖发布路径、Secrets、服务器运行路径、回滚和排障。

制度化基线与新增服务接入模板见：

- `docs/governance_control_plane_operating_baseline_20260417.md`
- `docs/operations_service_onboarding_template_20260417.md`

## 1. 适用范围

当前纳入统一控制面的服务：

- `iterlife-reunion-api`
- `iterlife-reunion-ui`
- `iterlife-expenses-api`
- `iterlife-expenses-ui`
- `iterlife-idaas-api`
- `iterlife-idaas-ui`

## 2. 标准发布路径

生产发布统一经过以下链路：

1. 业务仓库提交 PR。
2. PR 合并到 `main`。
3. GitHub Actions 构建镜像并推送 GHCR。
4. 共享 release workflow 回调部署 webhook。
5. webhook 根据 `service` 命中 `config/deploy-targets.json`。
6. `scripts/deploy-service-from-ghcr.sh` 统一完成镜像拉取、生产运行别名打标、`docker compose up -d`、健康检查和部署状态落盘。

当前不允许：

- 服务器 `git pull` 后源码构建发布。
- 手工触发生产 release workflow。
- 业务仓库自带的生产部署 shell。

## 3. 控制面关键资产

- `config/deploy-targets.json`
- `scripts/deploy-service-from-ghcr.sh`
- `scripts/validate-webhook-config.sh`
- `webhook/iterlife-deploy-webhook-server.py`
- `webhook/iterlife-deploy-webhook.env.example`
- `systemd/iterlife-app-deploy-webhook.service`
- `.github/workflows/reusable-release-ghcr-webhook.yml`

当前只有上述资产属于生产部署控制面事实源。
业务仓中如存在 `WebhookController`、`GITHUB_WEBHOOK_SECRET` 等业务集成入口，不应视为部署控制面的一部分。

## 4. 当前部署矩阵

| Service | Repo Dir | Compose File | Healthcheck |
| --- | --- | --- | --- |
| `iterlife-reunion-api` | `/apps/iterlife-reunion` | `/apps/iterlife-reunion/deploy/compose/reunion-api.yml` | `http://127.0.0.1:18080/api/health` |
| `iterlife-reunion-ui` | `/apps/iterlife-reunion-ui` | `/apps/iterlife-reunion-ui/deploy/compose/reunion-ui.yml` | `http://127.0.0.1:13080` |
| `iterlife-expenses-api` | `/apps/iterlife-expenses` | `/apps/iterlife-expenses/deploy/compose/expenses-api.yml` | `http://127.0.0.1:18180/api/health` |
| `iterlife-expenses-ui` | `/apps/iterlife-expenses-ui` | `/apps/iterlife-expenses-ui/deploy/compose/expenses-ui.yml` | `http://127.0.0.1:13180` |
| `iterlife-idaas-api` | `/apps/iterlife-idaas` | `/apps/iterlife-idaas/deploy/compose/idaas-api.yml` | `http://127.0.0.1:18280/actuator/health` |
| `iterlife-idaas-ui` | `/apps/iterlife-idaas-ui` | `/apps/iterlife-idaas-ui/deploy/compose/idaas-ui.yml` | `http://127.0.0.1:13280` |

以上事实以 `config/deploy-targets.json` 为准。

## 5. GitHub Actions 与 Secrets

### 5.1 `iterlife-stack` 仓库自身 Secrets

当前仅需：

- `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`

用途：

- 发布 `@iterlife/theme-dark-universe`
- 发布 `@iterlife/vue-copy-action`

### 5.2 共享 Release Workflow 所需 Secrets

由业务仓库提供：

- `ALIYUN_DEPLOY_WEBHOOK_URL`
- `ALIYUN_DEPLOY_WEBHOOK_SECRET`

当前消费方：

- `iterlife-reunion`
- `iterlife-reunion-ui`
- `iterlife-expenses`
- `iterlife-expenses-ui`
- `iterlife-idaas`
- `iterlife-idaas-ui`

### 5.3 GitHub 自动提供的 Token

- `GITHUB_TOKEN`

用途：

- 登录 GHCR
- checkout 当前仓库代码

## 6. 服务器运行时路径

- 控制面仓库：`/apps/iterlife-reunion-stack`
- webhook 真实 env：`/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`
- webhook 日志目录：`/apps/logs/webhook`
- 部署状态目录：`/apps/logs/deploy-state`
- systemd unit：`/etc/systemd/system/iterlife-app-deploy-webhook.service`
- systemd drop-in：`/etc/systemd/system/iterlife-app-deploy-webhook.service.d/`
- 宿主机 Nginx 生效目录：`/etc/nginx`
- 宿主机 Nginx 备份与快照目录：`/apps/config/nginx`

## 7. 版本标识基线

当前生产版本治理规则如下：

- GHCR 事实版本使用不可变 `sha-<commit>` 标签
- 服务器运行别名统一使用 `:prod`
- 每次部署都会为目标服务落一份部署状态文件

部署状态文件至少记录：

- release image ref
- image digest
- commit sha
- deployed at
- 容器 configured image
- 容器状态

统一查询入口：

```bash
bash scripts/show-runtime-versions.sh
```

## 8. 新服务器初始化

```bash
cd /apps
git clone git@github.com:LuJie0403/iterlife-stack.git /apps/iterlife-reunion-stack
cd /apps/iterlife-reunion-stack
mkdir -p /apps/config/iterlife-reunion-stack
cp webhook/iterlife-deploy-webhook.env.example \
  /apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env
sudo install -D -m 644 systemd/iterlife-app-deploy-webhook.service \
  /etc/systemd/system/iterlife-app-deploy-webhook.service
sudo install -D -m 644 systemd/iterlife-app-deploy-webhook.service.d/10-log-perms.conf \
  /etc/systemd/system/iterlife-app-deploy-webhook.service.d/10-log-perms.conf
sudo systemctl daemon-reload
sudo systemctl enable --now iterlife-app-deploy-webhook.service
bash scripts/validate-webhook-config.sh \
  /apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env
```

## 9. 日常检查

GitHub Actions 侧：

- release workflow 成功
- `build-and-push-image` 成功
- `callback-aliyun-webhook` 成功

服务器侧：

```bash
sudo systemctl status iterlife-app-deploy-webhook.service --no-pager
tail -n 120 /apps/logs/webhook/iterlife-deploy-webhook-$(date +%F).log
sudo docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}'
bash scripts/show-runtime-versions.sh
```

## 10. 健康检查

```bash
curl -fsS http://127.0.0.1:18080/api/health
curl -fsS http://127.0.0.1:13080
curl -fsS http://127.0.0.1:18180/api/health
curl -fsS http://127.0.0.1:13180
curl -fsS http://127.0.0.1:18280/actuator/health
curl -fsS http://127.0.0.1:13280
```

## 11. 回滚

标准回滚继续走同一套镜像部署链路，不回退到源码部署：

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

- webhook 返回 `202`
- 日志出现 `deploy success`
- 容器启动时间更新
- 健康检查恢复

## 12. 常见问题

- webhook 返回 `401`：通常是 `ALIYUN_DEPLOY_WEBHOOK_SECRET` 与服务器 `WEBHOOK_SECRET` 不一致。
- webhook 返回 `unsupported service`：通常是 `service` 未在 `config/deploy-targets.json` 注册。
- 镜像已推送但容器未更新：优先检查 `compose_file`、`compose_service` 和容器 `Config.Image`。
- 容器显示 `:prod` 但仍看不出具体 commit：优先检查 `bash scripts/show-runtime-versions.sh` 或部署状态文件。
- 健康检查失败：优先检查 webhook 日志、容器日志和本地健康检查地址。

## 13. 服务器治理基线

当前生产服务器治理已经收官，后续运维以以下基线为准：

- 主部署目录：`/apps`
- 宿主机入口：`/etc/nginx`
- 容器运行时：Docker / containerd
- 部署触发服务：`iterlife-app-deploy-webhook.service`
- 主机级核心服务：`mysqld`、`redis`、`squid`

当前运行边界：

- `80/443`：宿主机 Nginx
- `127.0.0.1:19091`：deploy webhook
- `127.0.0.1:18080`：reunion API
- `127.0.0.1:13080`：reunion UI
- `127.0.0.1:18180`：expenses API
- `127.0.0.1:13180`：expenses UI
- `127.0.0.1:18280`：idaas API
- `127.0.0.1:13280`：idaas UI
- `127.0.0.1` 和 `172.17.0.1`：Redis
- `127.0.0.1:3128`：Squid

当前维护结论：

- 服务器整体状态健康，不存在立即需要扩容的磁盘压力。
- 生产流量不再依赖历史 `/www` 运行模型，宿主机 Nginx 以 `/etc/nginx` 为准。
- 运行资产、部署链路与日志目录已经收敛到当前控制面基线。
- 如需继续调整主机级治理策略，应直接更新本文档，不再单独拆分新的根目录运维审计文档。
- 控制面当前服务器路径仍为 `/apps/iterlife-reunion-stack`，如需迁移到 `/apps/iterlife-stack`，应按控制面治理方案分阶段执行。
