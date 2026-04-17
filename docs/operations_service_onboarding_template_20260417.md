# 新服务接入统一控制面模板

最后更新：2026-04-17

本文档是新服务接入 IterLife 统一控制面的执行模板，用于保证新增服务能够按统一制度落地。

## 1. 基本信息

- 服务名称：
- 服务类型：`API / UI / Worker / Other`
- 所属仓库：
- GHCR 镜像名：
- 运行配置目录：
- 健康检查地址：

## 2. 必备控制面资产

勾选以下项目：

- [ ] 已新增 `deploy/compose/<service>.yml`
- [ ] 已新增 `config/deploy-targets.json` 注册项
- [ ] 已补 release workflow
- [ ] 已补 `.env.example` 或 `backend.env.example / ui.env.example`
- [ ] 已补运行配置目录说明
- [ ] 已补 README 或运维文档入口

## 3. deploy target 模板

```json
{
  "<service-name>": {
    "compose_file": "/apps/iterlife-stack/deploy/compose/<service-file>.yml",
    "compose_project_directory": "/apps/iterlife-stack",
    "compose_service": "<service-name>",
    "release_image_env": "API_IMAGE_REF",
    "local_image_env": "LOCAL_API_IMAGE_NAME",
    "local_image_name": "<service-name>:prod",
    "healthcheck_url": "http://127.0.0.1:<port>/<health-path>",
    "compose_no_deps": true
  }
}
```

说明：

- UI 服务可将 `release_image_env` / `local_image_env` 切换为 `UI_*`
- `local_image_name` 应表达环境语义，不应继续使用 `:local`

## 4. 生产 compose 模板要求

生产 compose 必须满足：

- 使用镜像，不使用源码构建
- 真实配置来自 `/apps/config/*`
- 端口绑定明确
- 健康检查可执行
- 若有数据卷，路径必须明确

## 5. 必做验证

### 5.1 结构验证

```bash
find deploy/compose -maxdepth 1 -type f | sort
```

### 5.2 配置校验

```bash
bash scripts/validate-webhook-config.sh webhook/iterlife-deploy-webhook.env.example config/deploy-targets.json
```

### 5.3 脚本校验

```bash
bash -n scripts/deploy-service-from-ghcr.sh
python3 -m py_compile webhook/iterlife-deploy-webhook-server.py
```

### 5.4 发布验证

- [ ] release workflow 成功
- [ ] webhook 接收成功
- [ ] 容器更新成功
- [ ] 健康检查通过

### 5.5 回滚验证

- [ ] 已记录上一个稳定镜像版本
- [ ] 已确认 rollback payload 可构造
- [ ] 已确认回滚后健康检查地址不变

## 6. 交付完成定义

只有当以下条件全部满足时，才可视为接入完成：

- [ ] 文档完成
- [ ] 控制面资产完成
- [ ] 配置模板完成
- [ ] 发布验证完成
- [ ] 回滚验证完成
