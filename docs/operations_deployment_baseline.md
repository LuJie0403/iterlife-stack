# 统一部署与运维

创建日期：2026-04-17
最后更新：2026-04-19

本文档是 IterLife 当前统一部署与运维事实源，覆盖服务器基准状态、发布链路、版本基线、配置与 Secrets、服务映射、服务接入、例行巡检、回滚与排障入口。此前分散在多份 `operations_*` 根目录文档中的稳定结论，已经统一收敛到本文件。

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
- 应用运行日志根目录：`/apps/logs`
- 容器运行时：Docker / containerd
- webhook Python 运行时：`/usr/local/bin/python3.11`
- 部署触发服务：`iterlife-app-deploy-webhook.service`
- 主机级核心服务：`mysqld`、`redis`、`squid`

补充约束：

- `iterlife-stack` 本身是宿主机上的控制面仓库与正式文档事实源，不作为独立业务容器部署。
- 当前统一 Docker 部署矩阵仅覆盖业务应用前后端服务，不包含 `iterlife-stack` 自身。

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
- 业务应用在启动时通过 Flyway 等运行时迁移框架自动改库。

## 4. 控制面关键资产

- `config/deploy-targets.json`
- `scripts/deploy-service-from-ghcr.sh`
- `scripts/validate-webhook-config.sh`
- `webhook/iterlife-deploy-webhook-server.py`
- `webhook/iterlife-deploy-webhook.env.example`
- `systemd/iterlife-app-deploy-webhook.service`
- `.github/workflows/reusable-release-ghcr-webhook.yml`
- `docs/sql/*.sql`

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
`config/deploy-targets.json` 中同一 `service` 不允许重复定义，避免保留被历史条目覆盖的伪基线。

`iterlife-stack` 不在上表中，是因为它承担宿主机控制面仓库职责，而不是对外提供 HTTP 业务能力的独立容器服务。

### 5.1 应用日志标准

- 应用运行日志统一落在 `/apps/logs/<app>/<component>/`。
- 前后端日志必须分离，不共用同一个目录或文件。
- 日志文件必须按日期切分，命名统一为 `<service>-YYYY-MM-DD.log`。
- 该标准同时适用于 `iterlife-reunion`、`iterlife-expenses`、`iterlife-idaas` 的前后端，以及后续新增项目。
- 当前已落地的服务日志目录：
  - `iterlife-reunion-api` -> `/apps/logs/iterlife-reunion/api/iterlife-reunion-api-YYYY-MM-DD.log`
  - `iterlife-reunion-ui` -> `/apps/logs/iterlife-reunion/ui/iterlife-reunion-ui-YYYY-MM-DD.log`
  - `iterlife-expenses-api` -> `/apps/logs/iterlife-expenses/api/iterlife-expenses-api-YYYY-MM-DD.log`
  - `iterlife-expenses-ui` -> `/apps/logs/iterlife-expenses/ui/iterlife-expenses-ui-YYYY-MM-DD.log`
  - `iterlife-idaas-api` -> `/apps/logs/iterlife-idaas/api/iterlife-idaas-api-YYYY-MM-DD.log`
  - `iterlife-idaas-ui` -> `/apps/logs/iterlife-idaas/ui/iterlife-idaas-ui-YYYY-MM-DD.log`
- Java 服务优先使用应用内 rolling file 策略；Node / Nuxt 服务优先使用容器内启动包装器将 stdout/stderr 汇总到按日文件。
- Python API 与 Nginx 静态前端优先使用容器内日志包装器将 stdout/stderr 汇总到按日文件。
- 默认保留期为 30 天；Java 服务默认总量上限为 `2GB`。
- 新服务接入统一控制面时，必须同时补齐日志目录挂载、日志环境变量和本文档条目。
- 若宿主机 `/apps/logs/<app>/<component>/` 为空，但 `docker logs <container>` 持续有输出，优先检查运行中容器是否实际带有 `APP_LOG_DIR`、`APP_LOG_FILE_PREFIX` 和对应 bind mount。
- 对 Java 服务，若未注入 `APP_LOG_DIR`，logback 会回退到容器工作目录下的 `./logs/<service>-YYYY-MM-DD.log`；这属于控制面编排未生效，不属于应用本身未产生日志。

### 5.2 数据库变更管理标准

- 数据库结构变更、初始化数据变更和登录方式配置初始化，不再通过 Flyway 等运行时迁移框架自动执行。
- 每次数据库变更都必须生成一份独立 SQL 文件，放在 `iterlife-stack/docs/sql/` 目录下。
- SQL 文件命名统一使用下划线，固定形态为 `yyyymmdd_NNN_topic.sql`。
- 其中 `NNN` 表示当天脚本批次内的执行顺序，每个日期都从 `000` 开始递增。
- 提交 PR 时必须明确提示管理员手动执行对应 SQL 文件，并说明目标数据库与执行顺序。
- 业务应用仓库中的运行时配置、依赖和启动链路，不应再包含自动改库机制。
- 当前与 IDaaS 登录方式配置对应的人工执行脚本为：
  - `docs/sql/20260419_000_idaas_provider_config.sql`

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

## 7. 当前版本与发布基线

版本号的代码事实源仍在各业务仓库内维护，本文件只保留 IterLife 当前统一运维所需的发布基线口径：

- Java 服务以 `pom.xml` 为代码版本源。
- Node / Nuxt / Vite 前端以 `package.json` 为代码版本源。
- Python 服务在补齐统一版本文件之前，以应用内单一显式版本声明为准。
- 正式发布标签统一使用 `release_vX.Y.Z`。
- 尚未形成正式发布基线的服务保持 `-SNAPSHOT`，且不发布正式 tag。

### 7.1 当前发布矩阵

| 应用 | 仓库 | 当前声明版本 | 当前标签基线 | 发布状态 |
| --- | --- | --- | --- | --- |
| Reunion API | `iterlife-reunion` | `1.1.0` | `release_v1.1.0` | 已正式发布 |
| Reunion UI | `iterlife-reunion-ui` | `1.1.0` | `release_v1.1.0` | 已正式发布 |
| 花多少 API | `iterlife-expenses` | `1.1.0` | `release_v1.1.0` | 已正式发布 |
| 花多少 UI | `iterlife-expenses-ui` | `1.1.0` | `release_v1.1.0` | 已正式发布 |
| IDaaS API | `iterlife-idaas` | `0.1.0-SNAPSHOT` | 无 | 开发中 |
| IDaaS UI | `iterlife-idaas-ui` | `0.1.0-SNAPSHOT` | 无 | 开发中 |

### 7.2 当前版本线说明

- `iterlife-reunion` 与 `iterlife-reunion-ui` 当前稳定在线为 `1.1.x`。
- `iterlife-expenses` 与 `iterlife-expenses-ui` 当前正式版本线统一为 `1.1.0`。
- `iterlife-idaas` 与 `iterlife-idaas-ui` 当前仍处于 `0.1.0-SNAPSHOT` 开发阶段。
- 历史 `openclaw-expenses_v*` 标签仅保留追溯价值，不再作为当前标准版本线。

### 7.3 发布治理规则

- 任一应用变更版本号、发布标签或发布状态时，优先更新代码声明，再同步更新本文档。
- 文档与代码声明不一致时，以业务仓库中的代码版本声明为准。
- 不再单独维护平行的版本矩阵文档，避免重复事实源。

## 8. 当前服务映射

| Service | 运行配置 | 关联仓库 | 主要职责 |
| --- | --- | --- | --- |
| `iterlife-reunion-api` | `/apps/config/iterlife-reunion/backend.env` | `iterlife-reunion` | 内容查询、发布投影、评论与业务 webhook |
| `iterlife-reunion-ui` | `/apps/config/iterlife-reunion/ui.env` | `iterlife-reunion-ui` | 阅读、评论和前端交互 |
| `iterlife-expenses-api` | `/apps/config/iterlife-expenses/backend.env` | `iterlife-expenses` | 支出数据 API 与统计 |
| `iterlife-expenses-ui` | `/apps/config/iterlife-expenses/ui.env` | `iterlife-expenses-ui` | 看板、图表与交互 |
| `iterlife-idaas-api` | `/apps/config/iterlife-idaas/backend.env` | `iterlife-idaas` | 统一认证、会话和第三方登录 |
| `iterlife-idaas-ui` | `/apps/config/iterlife-idaas/ui.env` | `iterlife-idaas-ui` | 登录、回调与会话中心 |

## 9. 服务器运行时路径

- 控制面仓库：`/apps/iterlife-stack`
- webhook 真实 env：`/apps/config/iterlife-stack/iterlife-deploy-webhook.env`
- webhook 日志目录：`/apps/logs/webhook`
- 部署状态目录：`/apps/logs/deploy-state`
- Reunion API 运行日志目录：`/apps/logs/iterlife-reunion/api`
- Reunion UI 运行日志目录：`/apps/logs/iterlife-reunion/ui`
- 花多少 API 运行日志目录：`/apps/logs/iterlife-expenses/api`
- 花多少 UI 运行日志目录：`/apps/logs/iterlife-expenses/ui`
- IDaaS API 运行日志目录：`/apps/logs/iterlife-idaas/api`
- IDaaS UI 运行日志目录：`/apps/logs/iterlife-idaas/ui`
- systemd unit：`/etc/systemd/system/iterlife-app-deploy-webhook.service`
- systemd drop-in：`/etc/systemd/system/iterlife-app-deploy-webhook.service.d/`
- 宿主机 Nginx 生效目录：`/etc/nginx`
- 宿主机 Nginx 备份与快照目录：`/apps/config/nginx`

## 10. 新服务器初始化

```bash
cd /apps
git clone git@github.com:LuJie0403/iterlife-stack.git /apps/iterlife-stack
cd /apps/iterlife-stack
test -x /usr/local/bin/python3.11
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
tail -n 120 /apps/logs/iterlife-reunion/api/iterlife-reunion-api-$(date +%F).log
tail -n 120 /apps/logs/iterlife-reunion/ui/iterlife-reunion-ui-$(date +%F).log
tail -n 120 /apps/logs/iterlife-expenses/api/iterlife-expenses-api-$(date +%F).log
tail -n 120 /apps/logs/iterlife-expenses/ui/iterlife-expenses-ui-$(date +%F).log
tail -n 120 /apps/logs/iterlife-idaas/api/iterlife-idaas-api-$(date +%F).log
tail -n 120 /apps/logs/iterlife-idaas/ui/iterlife-idaas-ui-$(date +%F).log
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

关于控制面仓库写权限：

- 生产控制面仓库不应被当作日常可写工作区，这仍是治理方向。
- 但当前阶段不对 `/apps/iterlife-stack` 额外施加 Git push 限制或只读机制，避免在尚未完成控制面收敛前引入新的运维风险。
- 相关权限硬化属于低优先级治理项，后续如需执行，应通过独立方案评估后再落地。

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
- 镜像已推送但容器未更新：优先检查 `compose_file`、`compose_service`、`runtime_image_env` 和容器 `Config.Image`。
- 健康检查失败：优先检查 webhook 日志、容器日志和本地健康检查地址。

## 16. 新服务接入模板

新增服务接入统一控制面时，至少补齐以下信息：

- 服务名称
- 服务类型：`API / UI / Worker / Other`
- 所属仓库
- GHCR 镜像名
- 运行配置目录
- 健康检查地址

### 16.1 必备控制面资产

- `deploy/compose/<service>.yml`
- `config/deploy-targets.json` 注册项
- 对共享 reusable workflow 的引用
- `.env.example` 或 `backend.env.example / ui.env.example`
- 运行配置目录说明
- 本文档中的服务矩阵与运行口径

### 16.2 deploy target 模板

```json
{
  "<service-name>": {
    "compose_file": "/apps/iterlife-stack/deploy/compose/<service-file>.yml",
    "compose_project_directory": "/apps/iterlife-stack",
    "compose_service": "<service-name>",
    "release_image_env": "API_IMAGE_REF",
    "runtime_image_env": "RUNTIME_API_IMAGE_NAME",
    "runtime_image_name": "<service-name>:prod",
    "deployment_state_file": "/apps/logs/deploy-state/<service-name>.json",
    "healthcheck_url": "http://127.0.0.1:<port>/<health-path>",
    "compose_no_deps": true
  }
}
```

说明：

- UI 服务可将 `release_image_env` / `runtime_image_env` 切换为 `UI_*`
- `runtime_image_name` 应表达运行环境语义，不继续沿用 `:local`
- 新注册项不再使用 `repo_dir` 一类业务源码目录依赖字段

### 16.3 生产 compose 要求

生产 compose 必须满足：

- 使用镜像，不使用源码构建
- 真实配置来自 `/apps/config/*`
- 端口绑定明确
- 健康检查可执行
- 若有数据卷，路径必须明确

### 16.4 接入完成定义

只有当以下条件全部满足时，才可视为接入完成：

- 文档完成
- 控制面资产完成
- 配置模板完成
- 发布验证完成
- 回滚验证完成
