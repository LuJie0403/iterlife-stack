# 服务器控制面运行基线

最后更新：2026-04-17

本文档是服务器控制面治理第六阶段“收口与制度化治理”的正式交付物，用于把已经形成的治理结论沉淀为长期可复用的运行基线、接入标准与变更约束。

## 1. 文档目标

本文档统一回答以下问题：

- 新增服务如何接入统一控制面
- deploy target、镜像命名、运行配置应遵循什么规则
- 每次控制面变更后，必须执行哪些验证
- 哪些操作被视为违反标准 CI/CD 流程
- 值班与交接时，什么信息必须可一眼获得

## 2. 控制面运行基线

当前 IterLife 生产控制面的长期基线如下：

- 控制面仓唯一事实源：`iterlife-stack`
- 控制面服务器主目录：`/apps/iterlife-stack`
- 运行时配置主目录：`/apps/config`
- 统一部署入口：GitHub Actions -> deploy webhook -> deploy script
- 生产部署载体：GHCR 镜像 + 控制面持有的生产 compose
- 生产配置来源：`/apps/config/*`
- 生产日志来源：`/apps/logs/*`
- 生产数据来源：`/apps/data/*`
- 宿主机对外入口：`/etc/nginx`

以下对象不应再被视为生产事实源：

- 业务仓中的历史 webhook 资产
- 依赖业务源码目录的生产 compose
- 手工登录服务器执行的发布动作
- 手工 `git pull`、手工 `docker compose up` 的生产更新方式

## 3. 新增服务接入标准

新增服务接入统一控制面时，必须同时满足以下条件。

### 3.1 服务命名

- 后端服务统一使用 `-api`
- 前端服务统一使用 `-ui`
- deploy target 使用完整服务名，例如：
  - `iterlife-foo-api`
  - `iterlife-foo-ui`

### 3.2 控制面资产

每个服务必须在控制面仓中补齐：

- `deploy/compose/<service>.yml`
- `config/deploy-targets.json` 注册项
- 仓库级 release workflow 对共享 reusable workflow 的引用
- 健康检查地址
- 运行配置目录说明

### 3.3 运行配置

真实运行配置统一放在 `/apps/config/<app>` 或 `/apps/config/iterlife-stack`。

仓库内只允许保留：

- `.env.example`
- `backend.env.example`
- `ui.env.example`

禁止将真实密钥、token、密码、生产 webhook 地址写入代码仓。

### 3.4 生产 compose

生产 compose 必须满足：

- 位于控制面仓 `deploy/compose/`
- 只依赖镜像、env、数据卷、日志卷、静态资源、宿主机端口
- 不包含业务源码构建路径
- 不包含指向业务源码 checkout 的 `build.context`

## 4. deploy target 注册规范

`config/deploy-targets.json` 中每个服务注册项必须包含：

- `compose_file`
- `compose_project_directory`
- `compose_service`
- `release_image_env`
- `local_image_env`
- `local_image_name`
- `healthcheck_url`
- `compose_no_deps`

注册规则：

- `compose_file` 必须指向 `/apps/iterlife-stack/deploy/compose/*.yml`
- `compose_project_directory` 必须为 `/apps/iterlife-stack`
- `compose_service` 必须与 compose 中 service name 一致
- `healthcheck_url` 必须为实际可用的本机校验地址
- `compose_no_deps` 必须显式声明

禁止继续引入：

- `repo_dir`
- 指向业务源码目录的生产 compose 路径
- 仅靠人工记忆补字段的隐式配置

## 5. 镜像命名与版本标识规范

生产镜像标识采用“双轨制”。

### 5.1 不可变版本事实源

必须保留以下至少一项作为事实源：

- GHCR digest
- GHCR sha tag
- Git commit sha

### 5.2 运行时环境别名

允许保留环境语义标签，例如：

- `:prod`

但 `:prod` 只能作为环境别名，不能代替版本事实源。

### 5.3 运行时可追溯信息

每次生产部署后，应可追溯到：

- repository
- branch
- commit sha
- image ref
- image digest
- workflow run
- deployed_at

推荐通过以下方式落地：

- 镜像 label
- 容器 label
- 部署状态文件
- 统一版本查询脚本

实现“一眼知道当前线上版本”的目标。

## 6. 运行配置规范

运行配置必须遵循以下规则：

- 真实配置只在 `/apps/config`
- 示例配置只在代码仓
- 敏感字段不入库
- 同一服务只保留一套现役真实配置文件
- 配置目录命名应与控制面、应用命名保持一致

配置变更必须走：

1. 代码模板更新
2. PR 审核
3. 变更说明
4. 标准 CI/CD 发布或受控环境变更

## 7. 变更验证机制

每次控制面变更后，必须至少完成以下四类验证。

### 7.1 结构验证

检查：

- 路径是否与文档一致
- 新增或变更资产是否落在正确目录
- 是否引入重复事实源

推荐命令：

```bash
find deploy/compose -maxdepth 1 -type f | sort
rg -n 'iterlife-reunion-stack|/apps/iterlife-(reunion|expenses|idaas)' config scripts docs README.md
```

### 7.2 配置校验

检查：

- deploy target 字段完整
- env 示例与实际逻辑一致

推荐命令：

```bash
bash scripts/validate-webhook-config.sh webhook/iterlife-deploy-webhook.env.example config/deploy-targets.json
```

### 7.3 脚本校验

检查：

- shell 脚本语法
- Python webhook 服务可编译

推荐命令：

```bash
bash -n scripts/deploy-service-from-ghcr.sh
python3 -m py_compile webhook/iterlife-deploy-webhook-server.py
```

### 7.4 发布与回滚验证

检查：

- release workflow 是否成功
- webhook 是否接收并记录部署
- 容器是否更新
- 健康检查是否通过
- 回滚 payload 是否仍能生效

## 8. 禁止项

以下行为视为违反标准控制面治理要求：

- 未经审批直接登录服务器修改生产配置
- 未经审批直接在服务器拉代码
- 未经审批直接重启服务或部署容器
- 跳过 PR 审核直接改变生产事实源
- 继续让业务源码目录承载生产 compose 事实源
- 在代码仓中写入真实 secrets
- 让旧控制面资产与新控制面资产同时作为现役事实源

## 9. 新服务接入完成定义

一个新服务要被视为“已接入统一控制面”，至少应满足：

1. 已有独立生产 compose
2. 已注册 deploy target
3. 已配置 release workflow
4. 已有真实运行配置目录
5. 已定义健康检查地址
6. 已纳入运维文档
7. 已完成一次完整的发布验证
8. 已具备回滚验证路径

## 10. 运维值班完成定义

一个值班人员不看源码，只靠文档和标准命令，应能在 10 分钟内回答：

- 当前控制面事实源在哪里
- 当前某个服务配置文件在哪里
- 当前某个服务的生产 compose 在哪里
- 当前某个服务线上版本如何确认
- 当前发布日志看哪里
- 当前回滚从哪里入手

如果做不到，说明制度化基线还不够完整，应继续补文档或补工具。

## 11. 相关文档

- `docs/governance_repository_directory_20260411.md`
- `docs/operations_unified_deployment_and_operations_20260411.md`
- `docs/version_matrix_20260411.md`
