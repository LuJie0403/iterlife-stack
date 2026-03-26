# iterlife-reunion-stack

IterLife 公共平台资产仓（当前以部署栈与共享前端资产为主）。

包含内容：
- `webhook/iterlife-deploy-webhook-server.py`：统一部署回调服务
- `systemd/`：systemd 服务与 drop-in 资产
- `docs/`：CI/CD 与运维说明
- `packages/themes/`：跨前端共享主题安装包

CI/CD 角色定位：
- 本仓库是 IterLife 唯一的 CI/CD 控制面仓库
- 业务仓库是独立可部署单元，不再承担跨应用部署控制职责
- 生产发布标准流程见 `docs/deployment-manual-unified-cicd-ghcr-webhook-aliyun.md`
- 标准化清理与迁移蓝图见 `docs/cicd-standardization-blueprint.md`

安全约束：
- 真实配置文件 `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env` 不入库
- 仅提交 `webhook/iterlife-deploy-webhook.env.example`
- 不在仓库中存放任何真实 token/secret/password

恢复流程（简版）：
1. 拉取仓库到 `/apps/iterlife-reunion-stack`
2. 用 `webhook/iterlife-deploy-webhook.env.example` 生成真实配置文件：`/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`
3. 将 `systemd/iterlife-app-deploy-webhook.service*` 同步到 `/etc/systemd/system/`
4. `sudo systemctl daemon-reload && sudo systemctl enable --now iterlife-app-deploy-webhook.service`

校验建议：
- 变更路由配置后执行：`bash scripts/validate-webhook-config.sh webhook/iterlife-deploy-webhook.env.example`
- 变更共享主题包后执行对应包目录下的构建与打包校验

说明：
- 历史源码部署入口已从标准链路中移除，不再作为任何应用的生产发布方式
