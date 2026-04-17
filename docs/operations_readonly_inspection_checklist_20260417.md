# 生产环境只读巡检与阶段验证清单

最后更新：2026-04-17

本文档用于执行第一阶段“基线固化与现状可观测化”的只读巡检、值班验证与阶段完成验收。

## 1. 使用边界

本清单仅包含只读命令与验证项，不执行服务器变更，不触发部署，不修改配置。

## 2. 结构巡检

目标：

- 确认 `/apps` 当前目录结构与文档一致
- 确认配置中心、控制面、业务源码、日志、数据、静态资源边界清晰

建议检查项：

```bash
ls -ld /apps
find /apps -maxdepth 1 -mindepth 1 -printf '%M %u %g %TY-%Tm-%Td %TH:%TM %p\n' | sort
du -sh /apps/* 2>/dev/null | sort -h
find /apps -maxdepth 2 -type d | sort
```

通过标准：

- 顶层目录与文档一致
- 控制面、配置、日志、数据、静态资源目录都可识别

## 3. 服务映射巡检

目标：

- 确认服务名、配置文件、compose 文件、容器名和健康检查地址可一一映射

建议检查项：

```bash
find /apps -maxdepth 3 -type d -name .git | sed 's#/.git$##' | sort
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
```

通过标准：

- 文档中列出的服务都能找到对应容器
- 文档中列出的源码目录都存在
- 文档中列出的 compose 路径都存在

## 4. 配置中心巡检

目标：

- 确认服务器真实运行配置已收敛到 `/apps/config`

建议检查项：

```bash
find /apps/config -maxdepth 4 -type f | sort
```

重点核对：

- `/apps/config/iterlife-reunion/backend.env`
- `/apps/config/iterlife-reunion/ui.env`
- `/apps/config/iterlife-expenses/backend.env`
- `/apps/config/iterlife-expenses/ui.env`
- `/apps/config/iterlife-idaas/backend.env`
- `/apps/config/iterlife-idaas/ui.env`
- `/apps/config/iterlife-reunion-stack/iterlife-deploy-webhook.env`

通过标准：

- 各服务运行配置路径明确
- webhook 真实 env 存在且路径唯一

## 5. 控制面巡检

目标：

- 确认统一部署控制面路径、脚本、服务入口清晰

建议检查项：

```bash
find /apps/iterlife-reunion-stack -maxdepth 3 \
  \( -path '*/scripts/*' -o -path '*/webhook/*' -o -path '*/systemd/*' -o -path '*/.github/workflows/*' \) \
  -type f | sort
systemctl list-unit-files | grep -Ei 'iterlife|webhook'
```

通过标准：

- 控制面脚本存在
- webhook 服务 unit 存在
- release workflow 模板存在

## 6. Nginx 路径巡检

目标：

- 区分宿主机 Nginx 生效路径与备份路径

建议检查项：

```bash
ls -ld /etc/nginx
find /apps/config/nginx -maxdepth 3 | sort
```

通过标准：

- 能区分 `/etc/nginx` 为生效路径
- 能区分 `/apps/config/nginx` 为备份与快照目录

## 7. webhook 链路巡检

目标：

- 确认 GitHub Actions 到 webhook 的服务器入口清晰

建议检查项：

```bash
sudo systemctl status iterlife-app-deploy-webhook.service --no-pager
tail -n 120 /apps/logs/webhook/iterlife-deploy-webhook-$(date +%F).log
```

通过标准：

- webhook 服务运行正常
- 日志路径存在且可读
- 值班人员可从日志中判断最近发布状态

## 8. 健康检查巡检

目标：

- 确认所有纳入统一控制面的服务都可只读验证健康状态

建议检查项：

```bash
curl -fsS http://127.0.0.1:18080/api/health
curl -fsS http://127.0.0.1:13080
curl -fsS http://127.0.0.1:18180/api/health
curl -fsS http://127.0.0.1:13180
curl -fsS http://127.0.0.1:18280/actuator/health
curl -fsS http://127.0.0.1:13280
```

通过标准：

- Reunion、Expenses、IDaaS 三组 API/UI 健康地址均可访问

## 9. 第一阶段完成定义

第一阶段“基线固化与现状可观测化”完成，需要同时满足：

- `/apps` 目录结构已有正式文档
- 服务运行映射已有正式清单
- 只读巡检清单可执行
- 值班人员无需读代码即可定位：
  - webhook 服务
  - webhook 真实 env
  - 指定服务配置文件
  - 指定服务日志目录
  - 指定服务健康检查地址

## 10. 相关文档

- `docs/governance_server_control_plane_20260417.md`
- `docs/operations_service_runtime_inventory_20260417.md`
- `docs/operations_unified_deployment_and_operations_20260411.md`
