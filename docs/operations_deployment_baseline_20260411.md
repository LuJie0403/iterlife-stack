# 统一部署与运维

最后更新：2026-04-17

本文档是 IterLife 当前统一部署与运维事实源，覆盖服务器基准状态、发布链路、版本基线、配置与 Secrets、服务映射、例行巡检、回滚与排障入口。

## 1. 适用范围

当前纳入统一控制面的服务：

- `iterlife-reunion-api`
- `iterlife-reunion-ui`
- `iterlife-expenses-api`
- `iterlife-expenses-ui`
- `iterlife-idaas-api`
- `iterlife-idaas-ui`

## 2. 服务器基准状态

当前生产服务器以以下边界为准：

- 主部署目录：`/apps`
- 控制面主目录：`/apps/iterlife-stack`
- 控制面真实配置：`/apps/config/iterlife-stack/iterlife-deploy-webhook.env`
- 宿主机对外入口：`/etc/nginx`
- 控制面日志目录：`/apps/logs/webhook`
- 部署状态目录：`/apps/logs/deploy-state`
- 容器运行时：Docker / containerd
- 部署触发服务：`iterlife-app-deploy-webhook.service`
- 主机级核心服务：`mysqld`、`redis`、`squid`

## 3. 标准发布路径

生产发布统一经过以下链路：

1. 业务仓库提交 PR。
2. PR 合并到 `main`。
3. GitHub Actions 构建镜像并推送 GHCR。
4. 共享 release workflow 回调部署 webhook。
5. webhook 根据 `service` 命中 `config/deploy-targets.json`。
6. `scripts/deploy-service-from-ghcr.sh` 统一完成镜像拉取、打标、`docker compose up -d` 和健康检查。

当前不允许：

- 服务器 `git pull` 后源码构建发布。
- 手工触发生产 release workflow。
- 业务仓库自带的生产部署 shell。

## 4. 控制面关键资产

- `config/deploy-targets.json`
- `scripts/deploy-service-from-ghcr.sh`
- `scripts/validate-webhook-config.sh`
- `webhook/iterlife-deploy-webhook-server.py`
- `webhook/iterlife-deploy-webhook.env.example`
- `systemd/iterlife-app-deploy-webhook.service`
- `.github/workflows/reusable-release-ghcr-webhook.yml`

## 5. 当前控制面部署矩阵

| Service | Compose File | 目标运行别名 | 部署状态文件 | Healthcheck |
| --- | --- | --- | --- | --- |
| `iterlife-reunion-api` | `/apps/iterlife-stack/deploy/compose/reunion-api.yml` | `iterlife-reunion-api:prod` | `/apps/logs/deploy-state/iterlife-reunion-api.json` | `http://127.0.0.1:18080/api/health` |
| `iterlife-reunion-ui` | `/apps/iterlife-stack/deploy/compose/reunion-ui.yml` | `iterlife-reunion-ui:prod` | `/apps/logs/deploy-state/iterlife-reunion-ui.json` | `http://127.0.0.1:13080` |
| `iterlife-expenses-api` | `/apps/iterlife-stack/deploy/compose/expenses-api.yml` | `iterlife-expenses-api:prod` | `/apps/logs/deploy-state/iterlife-expenses-api.json` | `http://127.0.0.1:18180/api/health` |
| `iterlife-expenses-ui` | `/apps/iterlife-stack/deploy/compose/expenses-ui.yml` | `iterlife-expenses-ui:prod` | `/apps/logs/deploy-state/iterlife-expenses-ui.json` | `http://127.0.0.1:13180` |
| `iterlife-idaas-api` | `/apps/iterlife-stack/deploy/compose/idaas-api.yml` | `iterlife-idaas-api:prod` | `/apps/logs/deploy-state/iterlife-idaas-api.json` | `http://127.0.0.1:18280/actuator/health` |
| `iterlife-idaas-ui` | `/apps/iterlife-stack/deploy/compose/idaas-ui.yml` | `iterlife-idaas-ui:prod` | `/apps/logs/deploy-state/iterlife-idaas-ui.json` | `http://127.0.0.1:13280` |

以上事实以 `/apps/iterlife-stack/config/deploy-targets.json` 为准。  
运行中的实际镜像版本，以最近一次标准发布生成的部署状态文件和容器 `Config.Image` 为准。

## 6. GitHub Actions 与 Secrets

### 6.1 `iterlife-stack` 仓库自身 Secrets

当前仅需：

- `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`

用途：

- 发布 `@iterlife/theme-dark-universe`
- 发布 `@iterlife/vue-copy-action`

### 6.2 共享 Release Workflow 所需 Secrets

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

### 6.3 GitHub 自动提供的 Token

- `GITHUB_TOKEN`

用途：

- 登录 GHCR
- checkout 当前仓库代码

## 7. 当前版本基线

当前统一版本基线如下：

| 应用 | 仓库 | 当前声明版本 | 当前标签基线 | 发布状态 |
| --- | --- | --- | --- | --- |
| Reunion API | `iterlife-reunion` | `1.1.0` | `release_v1.1.0` | 已正式发布 |
| Reunion UI | `iterlife-reunion-ui` | `1.1.0` | `release_v1.1.0` | 已正式发布 |
| 花多少 API | `iterlife-expenses` | `1.1.0` | `release_v1.1.0` | 已正式发布 |
| 花多少 UI | `iterlife-expenses-ui` | `1.1.0` | `release_v1.1.0` | 已正式发布 |
| IDaaS API | `iterlife-idaas` | `0.1.0-SNAPSHOT` | 无 | 开发中 |
| IDaaS UI | `iterlife-idaas-ui` | `0.1.0-SNAPSHOT` | 无 | 开发中 |

统一规则：

- Java 服务以 `pom.xml` 为版本源。
- Node / Nuxt / Vite 前端以 `package.json` 为版本源。
- 正式发布标签统一使用 `release_vX.Y.Z`。
- 本文档中的版本描述与应用仓库实际声明版本不一致时，以代码声明版本为准，并尽快修正文档。

## 8. 当前服务映射

| Service | 运行配置 | 业务仓库目录 | 主要职责 |
| --- | --- | --- | --- |
| `iterlife-reunion-api` | `/apps/config/iterlife-reunion/backend.env` | `/apps/iterlife-reunion` | 内容查询、发布投影、评论与业务 webhook |
| `iterlife-reunion-ui` | `/apps/config/iterlife-reunion/ui.env` | `/apps/iterlife-reunion-ui` | 阅读、评论和前端交互 |
| `iterlife-expenses-api` | `/apps/config/iterlife-expenses/backend.env` | `/apps/iterlife-expenses` | 支出数据 API 与统计 |
| `iterlife-expenses-ui` | `/apps/config/iterlife-expenses/ui.env` | `/apps/iterlife-expenses-ui` | 看板、图表与交互 |
| `iterlife-idaas-api` | `/apps/config/iterlife-idaas/backend.env` | `/apps/iterlife-idaas` | 统一认证、会话和第三方登录 |
| `iterlife-idaas-ui` | `/apps/config/iterlife-idaas/ui.env` | `/apps/iterlife-idaas-ui` | 登录、回调与会话中心 |

## 9. 服务器运行时路径

- 控制面仓库：`/apps/iterlife-stack`
- webhook 真实 env：`/apps/config/iterlife-stack/iterlife-deploy-webhook.env`
- webhook 日志目录：`/apps/logs/webhook`
- 部署状态目录：`/apps/logs/deploy-state`
- systemd unit：`/etc/systemd/system/iterlife-app-deploy-webhook.service`
- systemd drop-in：`/etc/systemd/system/iterlife-app-deploy-webhook.service.d/`
- 宿主机 Nginx 生效目录：`/etc/nginx`
- 宿主机 Nginx 备份与快照目录：`/apps/config/nginx`

## 10. 新服务器初始化

```bash
cd /apps
git clone git@github.com:LuJie0403/iterlife-stack.git /apps/iterlife-stack
cd /apps/iterlife-stack
mkdir -p /apps/config/iterlife-stack
cp webhook/iterlife-deploy-webhook.env.example \
  /apps/config/iterlife-stack/iterlife-deploy-webhook.env
sudo install -D -m 644 systemd/iterlife-app-deploy-webhook.service \
  /etc/systemd/system/iterlife-app-deploy-webhook.service
sudo install -D -m 644 systemd/iterlife-app-deploy-webhook.service.d/10-log-perms.conf \
  /etc/systemd/system/iterlife-app-deploy-webhook.service.d/10-log-perms.conf
sudo systemctl daemon-reload
sudo systemctl enable --now iterlife-app-deploy-webhook.service
bash scripts/validate-webhook-config.sh \
  /apps/config/iterlife-stack/iterlife-deploy-webhook.env
```

## 11. 日常检查

GitHub Actions 侧：

- release workflow 成功
- `build-and-push-image` 成功
- `callback-aliyun-webhook` 成功

服务器侧：

```bash
sudo systemctl status iterlife-app-deploy-webhook.service --no-pager
tail -n 120 /apps/logs/webhook/iterlife-deploy-webhook-$(date +%F).log
sudo docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}'
find /apps/config -maxdepth 3 -type f | sort
```

## 12. 健康检查

```bash
curl -fsS http://127.0.0.1:18080/api/health
curl -fsS http://127.0.0.1:13080
curl -fsS http://127.0.0.1:18180/api/health
curl -fsS http://127.0.0.1:13180
curl -fsS http://127.0.0.1:18280/actuator/health
curl -fsS http://127.0.0.1:13280
```

## 13. 只读巡检要点

值班与排障时，优先按下面顺序定位：

1. 先确认本文档中的服务器基准状态和服务矩阵。
2. 再核对 `/apps/config`、`deploy-targets.json` 和当前容器状态。
3. 最后查看 webhook 日志和控制面脚本输出。

建议的只读巡检命令：

```bash
ls -ld /apps
find /apps -maxdepth 1 -mindepth 1 -printf '%M %u %g %TY-%Tm-%Td %TH:%TM %p\n' | sort
find /apps/iterlife-stack -maxdepth 3 \
  \( -path '*/scripts/*' -o -path '*/webhook/*' -o -path '*/systemd/*' -o -path '*/.github/workflows/*' \) \
  -type f | sort
sudo systemctl status iterlife-app-deploy-webhook.service --no-pager
sudo docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

通过标准：

- 控制面路径、服务路径和容器状态与本文档一致。
- webhook 服务运行正常。
- 健康检查地址可访问。

## 14. 回滚

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

## 15. 常见问题

- webhook 返回 `401`：通常是 `ALIYUN_DEPLOY_WEBHOOK_SECRET` 与服务器 `WEBHOOK_SECRET` 不一致。
- webhook 返回 `unsupported service`：通常是 `service` 未在 `config/deploy-targets.json` 注册。
- 镜像已推送但容器未更新：优先检查 `compose_file`、`compose_service` 和容器 `Config.Image`。
- 健康检查失败：优先检查 webhook 日志、容器日志和本地健康检查地址。
