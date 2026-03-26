# 阿里云服务器治理收官摘要

## 文档说明

本文档只记录治理结论、当前状态、明确待定项与后续维护建议，不保留详细操作过程和长日志。

治理时间范围：

1. 启动时间：`2026-03-23`
2. 收官时间：`2026-03-24`
3. 主机名：`Iter-1024`

## 一、总体结论

本轮治理已经完成既定主线目标。服务器已从“历史残留较多、运行面混杂”的状态，收敛为“以 `/apps + /etc/nginx + Docker + systemd + webhook` 为核心的清晰生产基线”。

当前生产运行边界：

1. 应用与部署资产：`/apps`
2. 宿主机入口：`/etc/nginx`
3. 容器运行时：Docker / containerd
4. 部署触发服务：`iterlife-app-deploy-webhook.service`
5. 主机级核心服务：`mysqld`、`redis`、`squid`

当前根分区状态：

1. 总容量：`40G`
2. 已用：约 `9.2G`
3. 可用：约 `29G`
4. 使用率：约 `25%`

当前主要目录体量：

1. `/usr`：约 `5.9G`
2. `/var`：约 `1.1G`
3. `/apps`：约 `9.9M`
4. `/home`：约 `240K`
5. `/tmp`：约 `40K`

结论：

1. 当前服务器整体状态健康
2. 不存在立即需要扩容的磁盘压力
3. 不存在必须继续执行的高优先级清理项

## 二、已完成治理事项

### 1. 账号、权限与凭据

已完成：

1. `iterlife-reunion` 的 sudo 权限已从高危的广泛提权收缩为受控只读能力
2. `iterlife-reunion` 已移出 `wheel`
3. 重复留存的 SSH 私钥、授权材料和迁移残留密钥已清理
4. `iterlife-reunion` 当前实际登录方式已确认以 SSH 公钥为主

当前状态：

1. `iterlife-reunion` 仍保留为部署与 webhook 服务账号
2. 当前活跃交互登录账号主要是 `lujie`
3. 后续协作约束：如需由 AI 登录服务器，只使用 `iterlife-reunion`

### 2. 宿主机暴露面

已完成：

1. Redis 已收敛到 `127.0.0.1` 与 `172.17.0.1`，并恢复 `protected-mode yes`
2. Squid 已收敛到 `127.0.0.1:3128`
3. `rpcbind` 已停用，公网 `111` 端口已移除
4. `firewalld` 已统一为 `disabled + inactive`
5. ECS 安全组已作为当前外层访问控制基线

当前主要监听面：

1. `80/443`：宿主机 Nginx
2. `127.0.0.1:19091`：deploy webhook
3. `127.0.0.1:18080`：reunion API
4. `127.0.0.1:13080`：reunion UI
5. `127.0.0.1:18180`：expenses API
6. `127.0.0.1:13180`：expenses UI
7. `127.0.0.1` 和 `172.17.0.1`：Redis
8. `127.0.0.1:3128`：Squid

### 3. 宝塔及旧 `/www` 运行面退役

已完成：

1. BT/宝塔运行面、启动项、文件树与系统入口已彻底删除
2. `www` 用户与 `/home/www` 已删除
3. 旧 `/www/server/nginx`、`/www/server/site_total` 已删除
4. 历史 `/www` 整棵目录已删除
5. 对应旧的 `/etc` 元数据与启动钩子已清理

当前状态：

1. `/www` 不再存在
2. 当前生产流量完全不依赖旧宝塔式 `/www` 运行模型
3. 宿主机 Nginx 已完全以 `/etc/nginx` 为准

### 4. `/home`、历史资产与系统残留

已完成：

1. `/home/iterlife-reunion` 下迁移残留、手工备份、重复 SSH 材料和影子目录已清理
2. `/home/go` 已删除
3. `/home/linuxbrew` 已删除
4. `/etc/profile.d/homebrew.sh` 已删除
5. `/root` 历史安装包、缓存、源码残留已大幅清理
6. `/root/iterlife_backup.sql` 已删除
7. `/home/www` 已删除

当前状态：

1. `/home/iterlife-reunion` 已收敛为最小登录环境
2. `/home` 不再是主要历史残留承载区

### 5. 生产仓库与部署链路

已完成：

1. `iterlife-reunion` 的部署加固改动已上游并回归主线
2. `iterlife-expenses` 与 `iterlife-expenses-ui` 的 Compose 项目名已标准化为 `iterlife-expenses`
3. `expenses` 运行态已从通用 `deploy` 命名切换到业务语义清晰的 `iterlife-expenses`
4. 相关生产仓库已回归 `main`
5. webhook 路径已与当前仓库布局重新对齐

当前状态：

1. 生产机相关仓库不再处于本轮治理引入的临时漂移状态
2. 当前部署链路可用，webhook 正常监听并运行

### 6. Docker 与磁盘占用

已完成：

1. dangling 镜像已清理
2. 未使用的 MySQL 镜像已删除
3. 历史 GHCR 镜像已收敛为“当前版本 + 上一个版本”
4. Docker build cache 已清空
5. `/var/log/journal` 已从约 `3.8G` 收敛到约 `472M`
6. `dnf/yum` 缓存已清理
7. `/tmp`、`/var/tmp` 历史临时残留已清理

量化结果：

1. 根分区使用率已降至约 `25%`
2. Docker 镜像总量约 `1.036G`
3. 当前镜像总数为 `10`
4. 当前活动镜像数为 `5`
5. Docker build cache 已从约 `1.251G` 清零到 `0B`

### 7. `/var` 与 `/tmp` 运行时卫生

已完成：

1. 为 `journald` 新增显式保留策略
2. 清理 `dnf/yum` 缓存
3. 清理 `/var/tmp` 下历史 `dnf-*` 临时目录
4. 清理 `/tmp` 下历史源码、Node 编译缓存、旧项目临时目录和旧面板残留
5. 清理 `/var/tmp` 下历史临时目录：
   - `springboot`
   - `gopids`
   - `other_project`

治理前后关键数据：

1. `/var/log/journal`：由约 `3.8G` 收敛到约 `472M`
2. `/var/cache`：由约 `542M` 收敛到约 `269M`
3. `/var/tmp`：由存在多组 `dnf-*` 和历史目录，收敛为仅保留活动 `systemd-private-*` 和少量当前运行相关对象
4. `/tmp`：由存在 `Python-3.9.18`、`node-compile-cache`、`jiti`、`v8-compile-cache-1001`、`clawdbot*`、`iterlife-articles-inspect`、`aap_locks`、`filetransfer`、`flow_task`、`panel_daily.pid` 等历史残留，收敛为仅保留活动 socket、标准系统临时目录和 `systemd-private-*`

当前状态：

1. `/var` 已不再以日志和缓存膨胀为主要风险源
2. `/tmp` 已回到轻量临时目录状态
3. `/var/tmp` 已回到少量活动临时目录状态

### 8. `/apps` 与 `/etc` 基线整理

已完成：

1. `/apps/config/iterlife-reunion` 已收紧到 `750`
2. 敏感 env 文件保持 `600`
3. 选定部署脚本已收紧到 `755`
4. `/apps/config` 根目录已收紧到 `755`
5. `/apps` 下主要仓库根目录已收紧到 `755`

`/etc` 侧已完成：

1. 删除旧 sudo 高危备份文件
2. 清理 `.rpmnew`、`.rpmsave`、`.bak` 等历史残留
3. `/etc/profile` 已恢复为系统级配置，不再全局 source 用户 `nvm`
4. `firewalld` 残留 `*.old` 已清理
5. `/etc/yum.repos.d/backup` 已删除
6. 明显无效残留已清理：
   - `/etc/bt_lib.lock`
   - `/etc/shadowsocks.json`
   - `/etc/httpd`
   - `/etc/pip2`
7. 并行旧时间同步链路已退役：
   - `ntpd.service`
   - `ntpdate.service`
   - `/etc/ntp`
   - `/etc/ntp.conf`
8. 未使用的 `svnserve.service` 已禁用
9. `openclaw-expenses-backend.service` 已清理

## 三、当前运行状态摘要

### 1. 关键服务

当前处于生产意义上的主要服务包括：

1. `nginx.service`
2. `docker.service`
3. `containerd.service`
4. `mysqld.service`
5. `redis.service`
6. `squid.service`
7. `iterlife-app-deploy-webhook.service`
8. `chronyd.service`

### 2. 自动启动能力

当前系统重启后可自动恢复的核心能力包括：

1. MySQL
2. 宿主机 Nginx
3. Docker
4. `iterlife-app-deploy-webhook.service`
5. `iterlife-reunion` 前后端容器
6. `iterlife-expenses` 前后端容器
7. `meilisearch` 容器

说明：

1. `mysqld`、`nginx`、`docker`、`iterlife-app-deploy-webhook.service` 当前均为 `enabled`
2. 关键容器的 Docker 重启策略均为 `unless-stopped`

### 3. 定时任务

当前系统级定时任务主要有：

1. `sysstat-collect.timer`
2. `systemd-tmpfiles-clean.timer`
3. `dnf-makecache.timer`
4. `iterlife-acme-renew.timer`
5. `unbound-anchor.timer`
6. `sysstat-summary.timer`

当前 `cron` 侧较轻：

1. `root`、`lujie`、`iterlife-reunion` 均无独立用户 crontab
2. `/etc/cron.d` 仅保留默认 `0hourly`
3. `/etc/cron.daily` 主要内容为 `logrotate`

## 四、SSH 公钥与登录基线

### 1. `iterlife-reunion` 当前实际登录公钥

最近实际命中的公钥为：

1. 指纹：`SHA256:iBIeTGOsns8+wNhxkwTlLyj+0e3SSjgoJpnHb0/pITc`
2. 注释：`iter_1024@macbook-pro-13`
3. 类型：`RSA 3072`

### 2. `iterlife-reunion` 当前授权公钥现状

`/home/iterlife-reunion/.ssh/authorized_keys` 中当前仍保留 3 把授权公钥：

1. `iter_1024@macbook-pro-13`
2. `ecs-i-bp1i5zno8v9ryytfiytw@aliyun`
3. `ec2-i-02ad40bb4c18d1573@aws`

其中近期明确命中的只有第一把。

### 3. 当前 SSH 基线判断

当前状态：

1. `iterlife-reunion` 仍可 SSH 登录
2. 实际使用方式为 SSH 公钥登录
3. SSH 配置仍保留：
   - `PasswordAuthentication yes`
   - `PermitRootLogin yes`

说明：

1. 这两项属于后续可继续优化的 SSH 安全基线问题
2. 本轮未纳入落地治理范围

## 五、明确暂缓的治理项

以下事项仍属于治理议题，但按当前决策，暂不执行：

1. MySQL 暴露面收敛
2. 严格意义上的 `deploy-only` 改造
3. 更深层的 `/apps` 递归权限收紧
4. `postfix.service` 最终处置

## 六、后续维护建议

建议后续以“巡检和小步维护”为主，不再进行大规模清理。

推荐做法：

1. 定期复查根分区使用率与 Docker 镜像体量
2. 观察 `/var/log/journal` 是否稳定在当前保留策略下
3. 定期复查 `/var/cache`、`/tmp`、`/var/tmp` 是否再次积累明显历史残留
4. 继续保持 `/etc` 只保留现行有效配置，不再积累历史备份残留
5. 如后续处理 MySQL、SSH 或 `postfix`，应单独作为独立治理项推进

## 七、最终评价

本轮治理已经完成收官。

最终成果可以概括为：

1. 历史控制面和旧运行面已基本退出系统
2. 权限、暴露面、磁盘占用与目录结构都已明显改善
3. 当前生产运行边界清晰、可解释、可维护
4. 系统已进入“稳定运行 + 小步治理”的阶段，而不是“继续大规模清理”的阶段

当前服务器质量结论：

1. 结构清晰度：良好
2. 运行稳定性：良好
3. 空间健康度：良好
4. 可维护性：显著优于治理开始前
