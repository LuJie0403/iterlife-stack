# 生产服务运行映射清单

最后更新：2026-04-17

本文档用于固化第一阶段“基线固化与现状可观测化”的服务映射结果，帮助值班、发布、排障和后续治理快速定位生产事实源。

## 1. 使用说明

本文档聚焦四类映射关系：

- 服务名与源码仓目录
- 服务名与容器名
- 服务名与运行配置目录
- 服务名与健康检查、静态资源、日志入口

如运行时与本文档不一致，应先视为环境漂移并回到服务器实际巡检结果核对。

## 2. 控制面与宿主机关键组件

| 资产 | 当前事实源 | 作用 |
| --- | --- | --- |
| 控制面源码仓 | `/apps/iterlife-reunion-stack` | 统一 release workflow、deploy target、webhook、systemd 资产 |
| webhook 真实配置 | `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env` | webhook 服务真实运行配置 |
| webhook 日志 | `/apps/logs/webhook` | 发布、签名、路由、部署结果日志 |
| systemd unit | `/etc/systemd/system/iterlife-app-deploy-webhook.service` | webhook 服务宿主机入口 |
| Nginx 生效目录 | `/etc/nginx` | 宿主机对外入口 |
| Nginx 备份与快照目录 | `/apps/config/nginx` | 历史备份、迁移前快照 |

## 3. 业务服务运行映射

| Service | Repo Dir | Container Name | Runtime Config | Compose File | Healthcheck |
| --- | --- | --- | --- | --- | --- |
| `iterlife-reunion-api` | `/apps/iterlife-reunion` | `iterlife-reunion-api` | `/apps/config/iterlife-reunion/backend.env` | `/apps/iterlife-reunion/deploy/compose/reunion-api.yml` | `http://127.0.0.1:18080/api/health` |
| `iterlife-reunion-ui` | `/apps/iterlife-reunion-ui` | `iterlife-reunion-ui` | `/apps/config/iterlife-reunion/ui.env` | `/apps/iterlife-reunion-ui/deploy/compose/reunion-ui.yml` | `http://127.0.0.1:13080` |
| `iterlife-expenses-api` | `/apps/iterlife-expenses` | `iterlife-expenses-api` | `/apps/config/iterlife-expenses/backend.env` | `/apps/iterlife-expenses/deploy/compose/expenses-api.yml` | `http://127.0.0.1:18180/api/health` |
| `iterlife-expenses-ui` | `/apps/iterlife-expenses-ui` | `iterlife-expenses-ui` | `/apps/config/iterlife-expenses/ui.env` | `/apps/iterlife-expenses-ui/deploy/compose/expenses-ui.yml` | `http://127.0.0.1:13180` |
| `iterlife-idaas-api` | `/apps/iterlife-idaas` | `iterlife-idaas-api` | `/apps/config/iterlife-idaas/backend.env` | `/apps/iterlife-idaas/deploy/compose/idaas-api.yml` | `http://127.0.0.1:18280/actuator/health` |
| `iterlife-idaas-ui` | `/apps/iterlife-idaas-ui` | `iterlife-idaas-ui` | `/apps/config/iterlife-idaas/ui.env` | `/apps/iterlife-idaas-ui/deploy/compose/idaas-ui.yml` | `http://127.0.0.1:13280` |

## 4. 当前运行中的辅助服务

| 服务 | 容器名或 unit | 作用 |
| --- | --- | --- |
| Meilisearch | `iterlife-reunion-meili` | Reunion 搜索与索引能力 |
| Deploy webhook | `iterlife-app-deploy-webhook.service` | GitHub Actions 到阿里云部署回调入口 |
| ACME renew | `iterlife-acme-renew.service` / `iterlife-acme-renew.timer` | 证书续期 |

## 5. 静态资源与共享目录

| 目录 | 作用 |
| --- | --- |
| `/apps/static/reunion` | Reunion 静态资源目录 |
| `/apps/static/expenses` | Expenses 静态资源目录 |
| `/apps/static/shared` | 共享静态资源目录 |

## 6. 日志与数据目录

| 目录 | 作用 |
| --- | --- |
| `/apps/logs/webhook` | 部署 webhook 日志目录 |
| `/apps/data/iterlife-reunion` | 当前已观测到的 Reunion 持久化数据目录 |

## 7. 当前可观测性缺口

当前第一阶段固化后，仍存在以下缺口，供下一阶段继续治理：

- 容器镜像使用 `:local`，无法直接表达生产版本
- 业务应用源码目录仍驻留生产机
- 控制面服务器路径仍为 `/apps/iterlife-reunion-stack`，与仓库语义不一致
- 旧资产与新控制面资产仍有并存现象

## 8. 推荐使用方式

值班与排障时，优先按以下顺序定位：

1. 先看本文档确定服务映射
2. 再看 `docs/operations_unified_deployment_and_operations_20260411.md`
3. 最后进入控制面脚本与 webhook 日志定位细节

## 9. 相关文档

- `docs/operations_unified_deployment_and_operations_20260411.md`
- `docs/governance_server_control_plane_20260417.md`
