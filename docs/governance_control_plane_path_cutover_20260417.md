# 控制面命名与路径治理切换清单

最后更新：2026-04-17

本文档用于记录第三阶段“控制面命名与路径治理”的依赖项清单、切换范围与验证结果。

## 1. 切换目标

第三阶段目标是将控制面相关引用统一切换到：

- 控制面仓库名：`iterlife-stack`
- 服务器控制面目录：`/apps/iterlife-stack`
- 控制面配置目录：`/apps/config/iterlife-stack`

本阶段不保留旧目录兼容逻辑。所有对原目录或原仓库名的访问，统一切换到新目录和新仓库名。

## 2. 依赖项清单

### 2.1 GitHub Actions 复用工作流依赖

受影响仓库：

- `iterlife-reunion`
- `iterlife-reunion-ui`
- `iterlife-idaas`
- `iterlife-idaas-ui`

依赖项：

- `uses: LuJie0403/iterlife-reunion-stack/.github/workflows/reusable-release-ghcr-webhook.yml@main`

切换目标：

- `uses: LuJie0403/iterlife-stack/.github/workflows/reusable-release-ghcr-webhook.yml@main`

### 2.2 服务器控制面路径依赖

受影响资产：

- `systemd/iterlife-app-deploy-webhook.service`
- `webhook/iterlife-deploy-webhook.env.example`
- `scripts/validate-webhook-config.sh`
- `docs/operations_unified_deployment_and_operations_20260411.md`
- `README.md`

切换目标：

- 工作目录：`/apps/iterlife-stack`
- 真实 env：`/apps/config/iterlife-stack/iterlife-deploy-webhook.env`
- 控制面脚本路径：`/apps/iterlife-stack/scripts/...`

### 2.3 文档与仓库说明依赖

受影响仓库：

- `iterlife-reunion`
- `iterlife-reunion-ui`

依赖项：

- README 中对 `iterlife-reunion-stack` 的说明
- 文档索引中对 `iterlife-reunion-stack/docs/...` 的引用

切换目标：

- 全部改为 `iterlife-stack`
- 部署文档统一引用 `iterlife-stack/docs/operations_unified_deployment_and_operations_20260411.md`

## 3. 实际切换结果

### 3.1 已切换的 GitHub Actions workflow

- `iterlife-reunion/.github/workflows/reunion-release-ghcr-webhook.yml`
- `iterlife-reunion-ui/.github/workflows/reunion-ui-release-ghcr-webhook.yml`
- `iterlife-idaas/.github/workflows/idaas-release-ghcr-webhook.yml`
- `iterlife-idaas-ui/.github/workflows/idaas-ui-release-ghcr-webhook.yml`

### 3.2 已切换的文档与说明

- `iterlife-reunion/README.md`
- `iterlife-reunion-ui/README.md`
- `iterlife-reunion-ui/docs/governance/repository-governance.md`
- `iterlife-reunion-ui/docs/README.md`

### 3.3 控制面仓中的当前事实

当前 `iterlife-stack` 仓库中，控制面路径基线已统一为：

- `/apps/iterlife-stack`
- `/apps/config/iterlife-stack/iterlife-deploy-webhook.env`

## 4. 验证清单与结果

### 4.1 控制面仓旧路径引用检查

检查目标：

- `iterlife-stack` 仓内不再保留 `iterlife-reunion-stack` 服务器路径依赖

结果：

- 通过

### 4.2 应用仓 workflow 旧仓库名引用检查

检查目标：

- `iterlife-reunion`
- `iterlife-reunion-ui`
- `iterlife-idaas`
- `iterlife-idaas-ui`

结果：

- 通过

### 4.3 文档旧仓库名引用检查

检查目标：

- `iterlife-reunion/README.md`
- `iterlife-reunion-ui/README.md`
- `iterlife-reunion-ui/docs/*`

结果：

- 通过

### 4.4 未受影响仓库确认

检查目标：

- `iterlife-expenses`
- `iterlife-expenses-ui`

结果：

- 通过
- 这两个仓库原本已经使用 `iterlife-stack`，本阶段无须调整

## 5. 当前阶段完成定义

第三阶段“控制面命名与路径治理”完成，需要同时满足：

- 所有控制面仓库级路径基线已经切换到 `iterlife-stack`
- 所有应用仓 release workflow 都已指向 `LuJie0403/iterlife-stack`
- 所有面向开发和运维的正式文档引用都不再依赖 `iterlife-reunion-stack`
- 不保留旧目录兼容路径

## 6. 后续人工验证建议

在进入部署前，建议继续执行以下人工核验：

1. 在 GitHub PR diff 中逐项核对 workflow `uses:` 仓库名已全部切换
2. 在服务器正式变更前，核对目标路径是否将同步切到：
   - `/apps/iterlife-stack`
   - `/apps/config/iterlife-stack`
3. 在控制面部署完成后，执行一次标准 release workflow 验证 webhook 回调是否命中新路径
