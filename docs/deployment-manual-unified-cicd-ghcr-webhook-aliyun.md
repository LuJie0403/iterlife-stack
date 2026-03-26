# IterLife 标准部署与运维手册

最后更新：2026-03-26

适用范围：
- `iterlife-reunion-api`
- `iterlife-reunion-ui`
- `iterlife-expenses-api`
- `iterlife-expenses-ui`
- 后续新增 IterLife 子应用

本手册是 IterLife 唯一的生产部署与运维基线。

从当前版本开始：

- 四个业务仓库不再保留独立部署文档
- 业务仓库只保留可部署资产本身，例如 `Dockerfile`、`deploy/compose/*.yml`、PR CI workflow、release wrapper workflow
- 差异化部署需求统一记录在本手册

## 1. 标准发布路径

IterLife 生产发布只允许经过以下链路：

1. 本地功能分支开发
2. 推送远端分支
3. 发起到 `main` 的 PR
4. 人工 review / 审批
5. 合并到 `main`
6. GitHub Actions 构建并推送 GHCR 镜像
7. GitHub Actions 回调阿里云统一 webhook
8. webhook 根据 `service` 路由到统一部署执行器
9. 目标服务执行 `docker compose up -d --no-build`
10. 健康检查、日志落盘和运行验证

不允许保留或重新引入以下旁路：

- 服务器 `git pull` 后源码构建发布
- 手工触发生产 release workflow
- 按应用分散维护的生产部署 shell
- API 无后缀 service key 的兼容路由

## 2. 仓库职责边界

### 2.1 控制面仓库

`iterlife-reunion-stack` 是唯一 CI/CD 控制面仓库，统一负责：

- webhook 服务
- systemd 运行资产
- 统一部署与运维文档
- 部署目标注册表
- 通用部署执行器
- 可复用 GitHub Actions release 模板
- 共享前端主题包发布

### 2.2 业务仓库

业务仓库只维护本应用的可部署单元：

- 应用源码
- `Dockerfile`
- 单服务 compose 文件
- PR 校验 workflow
- 调用统一模板的 release wrapper workflow
- 仓库自身运行时配置模板

业务仓库不再维护：

- 部署文档
- 生产部署 shell
- systemd / webhook 资产
- 跨应用部署控制逻辑

## 3. 标准命名规范

为消除历史兼容逻辑，统一采用以下命名：

- API service key：必须使用 `-api`
- UI service key：必须使用 `-ui`
- GHCR image name：与 service key 一致
- compose service name：与 service key 一致
- 部署注册表 key：与 service key 一致

当前标准 service key：

- `iterlife-reunion-api`
- `iterlife-reunion-ui`
- `iterlife-expenses-api`
- `iterlife-expenses-ui`

本地镜像名统一使用 `:local` 结尾：

- `iterlife-reunion-api:local`
- `iterlife-reunion-ui:local`
- `iterlife-expenses-api:local`
- `iterlife-expenses-ui:local`

## 4. 当前应用部署矩阵

| Service | Repo Dir | Compose File | Compose Service | Healthcheck | Public Entry |
|---|---|---|---|---|---|
| `iterlife-reunion-api` | `/apps/iterlife-reunion` | `/apps/iterlife-reunion/deploy/compose/reunion-api.yml` | `iterlife-reunion-api` | `http://127.0.0.1:18080/api/health` | `https://iterlife.com/api/` |
| `iterlife-reunion-ui` | `/apps/iterlife-reunion-ui` | `/apps/iterlife-reunion-ui/deploy/compose/reunion-ui.yml` | `iterlife-reunion-ui` | `http://127.0.0.1:13080` | `https://iterlife.com/` |
| `iterlife-expenses-api` | `/apps/iterlife-expenses` | `/apps/iterlife-expenses/deploy/compose/expenses-api.yml` | `iterlife-expenses-api` | `http://127.0.0.1:18180/api/health` | `https://expenses.iterlife.com/api/` |
| `iterlife-expenses-ui` | `/apps/iterlife-expenses-ui` | `/apps/iterlife-expenses-ui/deploy/compose/expenses-ui.yml` | `iterlife-expenses-ui` | `http://127.0.0.1:13180` | `https://expenses.iterlife.com/` |

额外运行组件：

| Service | Purpose | Health |
|---|---|---|
| `iterlife-reunion-meili` | Reunion 搜索服务 | 容器运行状态为准 |

## 5. 控制面关键资产

### 5.1 仓库内关键文件

- `config/deploy-targets.json`
- `scripts/deploy-service-from-ghcr.sh`
- `scripts/validate-webhook-config.sh`
- `webhook/iterlife-deploy-webhook-server.py`
- `webhook/iterlife-deploy-webhook.env.example`
- `systemd/iterlife-app-deploy-webhook.service`
- `systemd/iterlife-app-deploy-webhook.service.d/10-log-perms.conf`
- `.github/workflows/reusable-release-ghcr-webhook.yml`

### 5.2 服务器运行时关键路径

- 控制面仓库：`/apps/iterlife-reunion-stack`
- webhook 真实 env：`/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`
- webhook 日志目录：`/apps/logs/webhook`
- systemd unit：`/etc/systemd/system/iterlife-app-deploy-webhook.service`
- systemd drop-in：`/etc/systemd/system/iterlife-app-deploy-webhook.service.d/`

## 6. GitHub Actions 与 Secrets

### 6.1 业务仓库 release wrapper 必需 secrets

每个业务仓库都必须提供：

- `ALIYUN_DEPLOY_WEBHOOK_URL`
- `ALIYUN_DEPLOY_WEBHOOK_SECRET`

说明：

- 这两个 secret 配置在业务仓库，不配置在 `iterlife-reunion-stack`
- `ALIYUN_DEPLOY_WEBHOOK_SECRET` 必须与服务器 `WEBHOOK_SECRET` 完全一致

### 6.2 stack 仓库自身 secret

`iterlife-reunion-stack` 当前自身只需要：

- `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`

用途：

- 发布 `@iterlife/theme-dark-universe` 到 npm 官方 registry

更完整的 secrets 清单见：

- `docs/github-actions-secrets-reference.md`

## 7. 服务器运行时配置

真实 webhook env 文件路径：

- `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`

最小关键项：

```env
WEBHOOK_BIND_HOST=127.0.0.1
WEBHOOK_BIND_PORT=19091
WEBHOOK_PATH=/hooks/app-deploy
WEBHOOK_SECRET=...
DEPLOY_TARGETS_FILE=/apps/iterlife-reunion-stack/config/deploy-targets.json
DEPLOY_EXECUTOR_SCRIPT=/apps/iterlife-reunion-stack/scripts/deploy-service-from-ghcr.sh
DEPLOY_TIMEOUT_SECONDS=1800
WEBHOOK_LOG_DIR=/apps/logs/webhook
WEBHOOK_LOG_FILE_PREFIX=iterlife-deploy-webhook
GHCR_REGISTRY=ghcr.io
```

原则：

- 私密信息只放外部 env，不入库
- 服务路由信息只放 `config/deploy-targets.json`
- 不在 env 中维护长 JSON 字符串路由表

## 8. 新服务器初始化步骤

### 8.1 同步控制面仓库

```bash
cd /apps
git clone git@github.com:LuJie0403/iterlife-reunion-stack.git
cd /apps/iterlife-reunion-stack
git switch main
```

<<<<<<< HEAD
相关 GitHub Actions secrets 清单见 `docs/github-actions-secrets-reference.md`。

## 8. 治理约束
=======
### 8.2 配置 webhook 运行时 env
>>>>>>> main

```bash
mkdir -p /apps/config/iterlife-reunion-stack
cp webhook/iterlife-deploy-webhook.env.example \
  /apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env
```

然后填入真实值。

### 8.3 安装 systemd

```bash
sudo install -D -m 644 systemd/iterlife-app-deploy-webhook.service \
  /etc/systemd/system/iterlife-app-deploy-webhook.service

sudo install -D -m 644 systemd/iterlife-app-deploy-webhook.service.d/10-log-perms.conf \
  /etc/systemd/system/iterlife-app-deploy-webhook.service.d/10-log-perms.conf

sudo systemctl daemon-reload
sudo systemctl enable --now iterlife-app-deploy-webhook.service
```

### 8.4 启动前配置校验

```bash
cd /apps/iterlife-reunion-stack
bash scripts/validate-webhook-config.sh \
  /apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env
```

## 9. 日常发布操作

正常发布不需要登录服务器手工执行部署脚本。

标准动作只有：

1. 业务仓库发 PR
2. 审批通过后 merge `main`
3. 等待 GitHub Actions 构建并回调 webhook
4. 检查 webhook 日志、容器状态与健康检查

### 9.1 GitHub 侧检查项

- release workflow run 成功
- `build-and-push-image` 成功
- `callback-aliyun-webhook` 成功
- `image_ref` 指向 `ghcr.io/<owner>/<service>:sha-<commit>`

### 9.2 服务器侧检查项

```bash
sudo systemctl status iterlife-app-deploy-webhook.service --no-pager
tail -n 120 /apps/logs/webhook/iterlife-deploy-webhook-$(date +%F).log
sudo docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}'
```

## 10. 统一验证清单

### 10.1 发布前检查

- 目标仓库 PR 已审批
- merge 目标为 `main`
- release wrapper 未引入 `workflow_dispatch`
- 业务仓库 `ALIYUN_DEPLOY_WEBHOOK_URL` 已配置
- 业务仓库 `ALIYUN_DEPLOY_WEBHOOK_SECRET` 已配置且与服务器一致
- 服务器 webhook 服务运行正常
- `config/deploy-targets.json` 已包含目标服务

### 10.2 发布后检查

Reunion API:

```bash
curl -fsS http://127.0.0.1:18080/api/health
```

Reunion UI:

```bash
curl -fsS http://127.0.0.1:13080
```

Expenses API:

```bash
curl -fsS http://127.0.0.1:18180/api/health
```

Expenses UI:

```bash
curl -fsS http://127.0.0.1:13180
```

统一日志应出现：

- `deploy success: service=<service> resolved_service=<service>`

## 11. 常用运维命令

### 11.1 webhook 服务

```bash
sudo systemctl restart iterlife-app-deploy-webhook.service
sudo systemctl status iterlife-app-deploy-webhook.service --no-pager
sudo journalctl -u iterlife-app-deploy-webhook.service -n 200 --no-pager
```

### 11.2 webhook 业务日志

```bash
tail -n 200 /apps/logs/webhook/iterlife-deploy-webhook-$(date +%F).log
grep -n "deploy failed" /apps/logs/webhook/iterlife-deploy-webhook-$(date +%F).log
```

### 11.3 容器状态

```bash
sudo docker ps --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.RunningFor}}\t{{.Image}}'
sudo docker inspect --format 'table {{.Id}}\t{{.Name}}\t{{.State.Status}}\t{{.State.StartedAt}}\t{{.Config.Image}}' $(sudo docker ps -q)
```

### 11.4 手工拉取控制面最新代码

```bash
cd /apps/iterlife-reunion-stack
git fetch origin
git switch main
git pull --ff-only origin main
```

### 11.5 webhook dry-run

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

## 12. 回滚手册

标准回滚仍通过同一套镜像发布路径完成，不回退到源码部署。

### 12.1 轻量回滚

前提：

- 已知旧 `image_ref`
- 旧镜像仍保留在 GHCR

手工回调 webhook：

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

签名方式与 dry-run 相同。

### 12.2 回滚后验证

- webhook 返回 `202`
- 日志出现 `deploy success`
- 容器启动时间更新
- 健康检查恢复

## 13. 常见问题

### 13.1 GitHub Actions 回调 webhook 返回 `401`

原因：

- `ALIYUN_DEPLOY_WEBHOOK_SECRET` 与服务器 `WEBHOOK_SECRET` 不一致

处理：

1. 检查业务仓库 secret
2. 检查 `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`
3. 重启 webhook 服务

### 13.2 GitHub Actions run `jobs=0`

原因：

- workflow YAML 解析失败
- reusable workflow 输入不合法

处理：

1. 先检查 wrapper workflow
2. 再检查 `iterlife-reunion-stack` 中的 reusable workflow
3. 用 `gh run view <id> --json jobs` 确认是否根本没生成 job

### 13.3 webhook 收到请求但返回 `unsupported service`

原因：

- `config/deploy-targets.json` 未注册对应 service
- service key 命名不符合 `*-api` / `*-ui`

处理：

1. 检查业务仓库 wrapper 传入的 `service`
2. 检查 `config/deploy-targets.json`

### 13.4 构建成功但容器未更新

原因：

- compose service 名与注册表不一致
- 本地镜像 tag 未切换
- 部署命中的不是预期 compose 文件

处理：

1. 检查 webhook 日志中的 `compose_service`
2. 检查 `deploy-targets.json` 的 `compose_file` / `compose_service`
3. 检查 `docker inspect` 的 `Config.Image`

### 13.5 健康检查失败

原因：

- 容器虽然启动，但应用未就绪
- 运行时 env 错误
- 后端数据库或外部依赖异常

处理：

1. 查看 webhook 日志末尾诊断输出
2. 查看容器日志
3. 直接 curl 本地健康检查地址

## 14. Nginx / HTTPS 运维基线

当前公网入口应满足：

- Reunion 主域：`https://iterlife.com`
- Reunion 兼容域：`https://www.iterlife.com`
- Reunion 子域：`https://reunion.iterlife.com`
- Expenses 子域：`https://expenses.iterlife.com`
- 历史兼容域：`https://1024.iterlife.com`，301 到主域

硬性要求：

- 仅授权域名允许访问
- 未授权域名和 IP 访问应被拒绝
- 授权域名的 `http://` 必须 301 到 `https://`
- 对外只保留标准入口，不暴露应用回环端口

说明：

- 旧的“域名白名单 + HTTPS 升级”分散手册已经收口到本手册
- 真实 Nginx 变更前必须先备份配置，并在窗口期内验证 reload

## 15. 业务仓库差异化需求记录方式

如果后续某个应用确实存在差异化部署需求，不再在业务仓库单独新建部署文档。

统一做法：

1. 在本手册新增一节说明差异
2. 必要时更新 `deploy-targets.json`
3. 必要时更新 reusable workflow 输入
4. 在对应业务仓库 README 只保留到本手册的链接

## 16. 变更治理

涉及部署链路的变更，至少应同步检查：

1. `iterlife-reunion-stack/docs/deployment-manual-unified-cicd-ghcr-webhook-aliyun.md`
2. `iterlife-reunion-stack/config/deploy-targets.json`
3. `iterlife-reunion-stack/.github/workflows/reusable-release-ghcr-webhook.yml`
4. 各业务仓库 release wrapper workflow
5. 服务器真实 env 与 systemd 状态

最终验收标准：

- 任何应用都只能通过 `PR -> main -> GHCR -> webhook -> compose` 发布
- 统一控制面资产只在 `iterlife-reunion-stack` 维护
- 业务仓库不再保留部署文档与生产部署 shell
- 验证、回滚、故障排查和运维命令都可在本手册直接执行
