# IterLife 标准 CI/CD 手册（PR -> main -> GHCR -> Webhook -> Aliyun）

最后更新：2026-03-25

适用范围：
- `iterlife-reunion-api`
- `iterlife-reunion-ui`
- `iterlife-expenses-api`
- `iterlife-expenses-ui`
- 后续新增子应用

## 1. 目标

IterLife 生产发布只保留一条标准链路：

1. 本地分支开发
2. 推送远端分支
3. 发起到 `main` 的 PR
4. 人工代码评审与审批
5. 合并到 `main`
6. GitHub Actions 构建并推送 GHCR 私有镜像
7. GitHub Actions 回调阿里云统一 webhook
8. webhook 按 `service` 路由部署
9. 目标服务执行 `docker compose up -d --no-build`
10. 健康检查与统一日志记录

除上述流程外，不再保留源码拉取后本机构建发布、手工触发 release workflow、兼容包装脚本长期保留等其他 CI/CD 路线。

## 2. 仓库职责

### 2.1 CI/CD 控制面仓库

`iterlife-reunion-stack` 是唯一的 CI/CD 控制面仓库，统一负责：
- webhook 服务
- systemd 运行资产
- 统一部署文档
- 部署目标注册表
- 通用部署执行器
- GitHub Actions 可复用模板

### 2.2 可部署单元仓库

业务仓库只负责各自应用的可部署单元资产：
- 应用源码
- Dockerfile
- 单服务 compose 文件
- PR 校验 workflow
- 指向统一 release 模板的轻量 wrapper workflow
- 应用特有运行时配置约束

业务仓库不再承担跨应用部署控制职责，也不再保留服务器 `git pull` 后源码构建发布的生产流程。

## 3. 命名规范

为消除历史兼容逻辑，统一采用以下命名规则：

- API service key 必须使用 `-api` 后缀
- UI service key 必须使用 `-ui` 后缀
- GHCR 镜像名与 webhook `service` 字段保持一致
- compose service 名与 webhook `service` 字段保持一致
- 部署注册表 key 与 webhook `service` 字段保持一致

标准示例：
- `iterlife-reunion-api`
- `iterlife-reunion-ui`
- `iterlife-expenses-api`
- `iterlife-expenses-ui`

不再保留“API 无后缀 service key”或 `*-api` / 无后缀自动映射兼容逻辑。

## 4. 标准链路分层

### 4.1 GitHub PR 校验层

- 只在 `pull_request -> main` 触发
- 只做测试、编译、lint、typecheck、镜像构建验证等质量门禁
- 不允许生产部署

### 4.2 GitHub Release 层

- 只在 `push -> main` 触发
- 不保留 `workflow_dispatch`
- 标准输出：
  - `image_ref`
  - `image_digest`
  - `commit_sha`
- 回调 payload 必填：
  - `service`
  - `environment`
  - `repository`
  - `commit_sha`
  - `image_ref`
  - `image_digest`

### 4.3 Webhook 控制层

- 统一入口：`/hooks/app-deploy`
- 统一 HMAC 签名校验
- 统一按 `service` 路由
- 同服务串行执行，队列只保留最新任务
- 统一部署日志落盘

### 4.4 部署执行层

部署执行只做镜像部署，不做源码构建：
- 可选 `docker login`
- `docker pull`
- 本地 `docker tag`
- `docker compose up -d --no-build`
- 健康检查
- 失败时输出诊断日志

## 5. 标准资产归属

### 5.1 `iterlife-reunion-stack` 必须保留

- `webhook/iterlife-deploy-webhook-server.py`
- `webhook/iterlife-deploy-webhook.env.example`
- `systemd/iterlife-app-deploy-webhook.service`
- `systemd/iterlife-app-deploy-webhook.service.d/*`
- `scripts/validate-webhook-config.sh`
- `docs/deployment-manual-unified-cicd-ghcr-webhook-aliyun.md`
- `docs/cicd-standardization-blueprint.md`

### 5.2 `iterlife-reunion-stack` 应新增或收敛

- `config/deploy-targets.json`
  - 版本化部署目标注册表
  - 由仓库管理，不放进运行时私密 env
- `scripts/deploy-service-from-ghcr.sh`
  - 通用部署执行器
- `.github/workflows/reusable-release-ghcr-webhook.yml`
  - 可复用 release workflow 模板

### 5.3 业务仓库必须保留

- `Dockerfile`
- `deploy/compose/<service>.yml`
- `.github/workflows/<app>-pr-ci.yml`
- `.github/workflows/<app>-release.yml`
  - 最终应为调用统一 reusable workflow 的 wrapper
- 应用 README / 差异化部署说明

### 5.4 业务仓库不应再保留

- 生产用源码部署脚本
- 服务器 `git pull` 同步发布脚本
- 跨仓库编排脚本
- 与统一手册重复的完整 CI/CD 长文档
- service key 兼容命名逻辑

## 6. 部署注册表标准

部署目标注册表是 webhook 路由和部署执行的唯一事实源，推荐结构如下：

```json
{
  "iterlife-reunion-api": {
    "repo_dir": "/apps/iterlife-reunion",
    "compose_file": "/apps/iterlife-reunion/deploy/compose/reunion-api.yml",
    "compose_project_directory": "/apps/iterlife-reunion",
    "compose_service": "iterlife-reunion-api",
    "release_image_env": "API_IMAGE_REF",
    "local_image_env": "LOCAL_API_IMAGE_NAME",
    "local_image_name": "iterlife-reunion-api:local",
    "healthcheck_url": "http://127.0.0.1:18080/api/health",
    "compose_no_deps": false
  },
  "iterlife-reunion-ui": {
    "repo_dir": "/apps/iterlife-reunion-ui",
    "compose_file": "/apps/iterlife-reunion-ui/deploy/compose/reunion-ui.yml",
    "compose_project_directory": "/apps/iterlife-reunion-ui",
    "compose_service": "iterlife-reunion-ui",
    "release_image_env": "UI_IMAGE_REF",
    "local_image_env": "LOCAL_UI_IMAGE_NAME",
    "local_image_name": "iterlife-reunion-ui:local",
    "healthcheck_url": "http://127.0.0.1:13080",
    "compose_no_deps": true
  }
}
```

运行时 env 只保留私密和环境相关参数，例如：
- `WEBHOOK_SECRET`
- `GHCR_USERNAME`
- `GHCR_TOKEN`
- `DEPLOY_TIMEOUT_SECONDS`
- `WEBHOOK_BIND_HOST`
- `WEBHOOK_BIND_PORT`

应用路由信息不应长期塞在运行时 env，而应放在版本化的 `config/deploy-targets.json` 中。

## 7. 统一 workflow 模型

最终每个业务仓库的 release workflow 只应传入这些差异项：
- `service`
- `image_name`
- `docker_context`
- `dockerfile`
- `build_args`（可选）

其它逻辑全部由统一模板提供：
- GHCR 登录
- buildx 初始化
- 镜像 tag 规则
- 输出 `image_ref` / `image_digest`
- webhook 签名和回调
- 生产环境 secrets 校验

相关 GitHub Actions secrets 清单见 `docs/github-actions-secrets-reference.md`。

## 8. 治理约束

- `main` 只允许通过 PR 合并
- PR 必须通过人工 review / 审批
- PR CI 必须是 required check
- release workflow 只在 `main` merge 后自动触发
- merge 和生产发布过程不应依赖服务器手工 git 操作

## 9. 新增应用接入标准

新增应用时只允许按这套最小清单接入：

1. 新建业务仓库，作为独立可部署单元
2. 提供 Dockerfile
3. 提供单服务 compose 文件
4. 提供 PR CI workflow
5. 提供 release wrapper workflow
6. 在 `iterlife-reunion-stack` 部署注册表新增一项
7. 在服务器 `/apps/config/<app>/` 放置运行时配置
8. 回归验证 webhook、镜像拉取、compose 启动和健康检查

不允许新增“从 GitHub 拉源码后在服务器构建”的特殊流程。

## 10. 立即清理方向

以下历史资产已经纳入清理目标并应保持不存在：
- `iterlife-expenses/deploy-expenses-from-github.sh`
- `iterlife-expenses/deploy-expenses-stack.sh`
- `iterlife-reunion-stack/scripts/deploy-all-apps-from-github.sh`
- 所有 release workflow 中的 `workflow_dispatch`
- 所有“API 无后缀 service key”兼容逻辑
- 所有仅为兼容旧调用保留的 GHCR 包装脚本

## 11. 验收标准

完成标准化后，应满足：
- 任一应用的生产发布都只能通过 `PR -> main -> GHCR -> webhook -> compose` 完成
- webhook 路由键、镜像名、compose service 名完全一致
- 控制面资产只在 `iterlife-reunion-stack` 维护
- 业务仓库不再保留源码部署生产链路
- 新应用接入不需要复制整套 workflow 和 shell，只需填应用差异配置
