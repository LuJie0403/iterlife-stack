# IterLife 统一 CI/CD 部署手册（GHCR + Webhook + 阿里云）

最后更新：2026-03-10  
适用范围：
- `iterlife-reunion`（backend）
- `iterlife-reunion-ui`（frontend）
- `iterlife-expenses`（backend）
- `iterlife-expenses-ui`（frontend）
- 后续新增子应用

## 1. CI/CD 背景

在本项目早期，发布流程存在以下问题：
- 服务器本机构建，发布耗时长且不可预测。
- 多应用共用编排资源时，容易发生容器命名冲突。
- 配置与代码耦合，存在敏感信息泄露风险。
- 发布触发条件不统一，导致“代码合并后未自动发布”。

本手册目标是建立一条统一、可审计、可扩展的生产发布链路：
- 开发在本地完成，合并 `main` 后自动触发发布。
- 镜像在 GitHub Actions 构建并存储到 GHCR 私有仓库。
- 阿里云通过一个统一 webhook 回调入口，根据参数路由到不同应用部署脚本。

## 2. 设计总体方案

### 2.1 统一链路

1. 本地分支开发并提交
2. 推送分支并发起 PR
3. PR 校验通过并合并到 `main`
4. GitHub Actions 构建镜像并推送 GHCR
5. GitHub Actions 发送签名回调到统一 webhook
6. webhook 校验签名并按 `service` 路由部署脚本
7. 目标脚本执行 `docker compose up -d --no-build`
8. 执行健康检查并记录日志

### 2.2 架构原则

1. 配置与代码隔离：生产真实配置只存于 `/apps/config/...`
2. 镜像集中托管：GHCR 私有仓库，生产机只拉镜像不构建
3. 接口复用：一个 webhook 支持多个应用
4. 安全优先：HMAC 验签 + 白名单路由 + HTTPS
5. 兼容演进：支持 API 无后缀命名和 `*-api` 兼容映射

## 3. 配置文件与配置方法

### 3.1 仓库内文件（可入库）

1. `webhook/iterlife-deploy-webhook-server.py`  
职责：统一 webhook 服务实现（验签、排队、路由、调用脚本）

2. `webhook/iterlife-deploy-webhook.env.example`  
职责：配置模板（无真实密钥）

3. `systemd/iterlife-app-deploy-webhook.service`  
职责：systemd 主服务定义

4. `systemd/iterlife-app-deploy-webhook.service.d/10-log-perms.conf`  
职责：日志目录与权限预处理

5. `scripts/validate-webhook-config.sh`  
职责：校验 `DEPLOY_TARGETS_JSON` 结构和标准路由键

### 3.2 服务器运行时配置（不入库）

1. `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`
2. `/apps/logs/webhook/iterlife-deploy-webhook.log`

### 3.3 配置步骤

1. 拷贝模板：

```bash
cp /apps/iterlife-reunion-stack/webhook/iterlife-deploy-webhook.env.example \
   /apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env
```

2. 填写真实值（`WEBHOOK_SECRET`、`GHCR_USERNAME`、`GHCR_TOKEN` 等）。

3. 校验配置：

```bash
cd /apps/iterlife-reunion-stack
bash scripts/validate-webhook-config.sh webhook/iterlife-deploy-webhook.env.example
```

4. 重载服务：

```bash
sudo systemctl daemon-reload
sudo systemctl restart iterlife-app-deploy-webhook.service
sudo systemctl status iterlife-app-deploy-webhook.service
```

## 4. 自动化运行流程

### 4.1 GitHub Actions 侧

1. PR CI：仅做测试和构建校验，不做生产部署。
2. Release Workflow（`main` push）：
- 构建镜像并推送 GHCR
- 生成 `image_ref`、`image_digest`
- 用 `WEBHOOK_SECRET` 计算签名
- 回调生产 webhook

### 4.2 Webhook 侧

1. 验签（`X-Hub-Signature-256`）
2. 校验 payload（`service`、`image_ref` 必填）
3. 路由服务键（支持 `-api` 与无后缀兼容）
4. 同服务串行 + “保留最新”排队执行
5. 设置镜像环境变量并调用目标脚本
6. 写入统一日志

### 4.3 部署脚本侧

脚本在各应用仓库中维护，典型职责：
- 登录 GHCR 并拉取目标镜像
- 标记本地镜像标签
- `docker compose up -d --no-build`
- 健康检查
- 失败输出诊断日志

## 5. 路由与命名规范

标准命名（推荐）：
- API：`iterlife-reunion`、`iterlife-expenses`
- UI：`iterlife-reunion-ui`、`iterlife-expenses-ui`

兼容规则：
- 回调传 `iterlife-xxx-api` 时，会尝试映射到无后缀键

`DEPLOY_TARGETS_JSON` 标准示例：

```env
DEPLOY_TARGETS_JSON={"iterlife-reunion":{"deploy_script":"/apps/iterlife-reunion/deploy-reunion-from-ghcr.sh","image_env":"API_IMAGE_REF"},"iterlife-reunion-ui":{"deploy_script":"/apps/iterlife-reunion/deploy-reunion-ui-from-ghcr.sh","image_env":"UI_IMAGE_REF"},"iterlife-expenses":{"deploy_script":"/apps/iterlife-expenses/deploy-expenses-api-from-ghcr.sh","image_env":"API_IMAGE_REF"},"iterlife-expenses-ui":{"deploy_script":"/apps/iterlife-expenses/deploy-expenses-ui-from-ghcr.sh","image_env":"UI_IMAGE_REF"}}
```

## 6. 治理检查清单

1. 目录纳入 Git 管理，且通过 PR 合并
2. 无真实密钥入库（`env.example` 仅占位）
3. 真实运行配置位于 `/apps/config/...`
4. systemd `EnvironmentFile` 指向 `/apps/config/...`
5. webhook 统一日志落盘到 `/apps/logs/webhook/...`
6. webhook 入口统一为 `/hooks/app-deploy`
7. 路由使用对象结构：`service -> {deploy_script, image_env}`
8. 服务命名遵循“API 无后缀、UI 用 -ui”

## 7. 方案落地中的问题与解决方法

1. 问题：`main` 合并后未触发发布  
解决：修复 workflow 触发条件，避免 `paths` 过滤漏掉部署文件变更。

2. 问题：compose 工程名变化导致容器重名冲突  
解决：统一 compose project naming 策略，并在部署脚本显式指定 project 目录。

3. 问题：webhook 服务因日志权限问题重启  
解决：添加 systemd drop-in `ExecStartPre`，启动前自动修正日志目录和文件权限。

4. 问题：`DEPLOY_TARGETS_JSON` 示例与实现不一致  
解决：统一为对象结构，并增加 `scripts/validate-webhook-config.sh` 校验。

5. 问题：运行配置放在仓库目录，存在泄漏风险  
解决：迁移到 `/apps/config/iterlife-reunion-stack/`，仓库仅保留 `env.example`。

6. 问题：历史文档口径不一致（服务命名、路径、部署职责）  
解决：收敛到本手册单一来源，其他仓库只做引用。

## 8. 验收与回归

1. `main` 合并后，目标仓库 Release Workflow 成功
2. webhook 日志有对应 `service` 成功记录
3. 目标服务健康检查通过
4. 域名访问回归通过
5. 四应用互不影响（并发发布无冲突）

## 9. 子应用引用规范

各子应用仓库不复制完整 CI/CD 细节，仅引用本手册，并声明本应用差异项：
- 镜像名
- 路由 service 键
- 部署脚本路径
- 健康检查地址
