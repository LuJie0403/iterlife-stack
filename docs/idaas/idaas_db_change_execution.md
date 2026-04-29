# IterLife IDaaS 数据库变更执行说明

创建日期：2026-04-29
适用版本：`iterlife-idaas` 单表账号模型改造
数据库版本：MySQL `8.0.35`

本文档用于统一执行本轮 IDaaS 数据库改造，目标是：

- 仅保留 `user_account` 作为账号与认证来源的事实表
- 不再保留 `authenticate_identity`
- 为内部关联补齐 `account_uid`
- 会话表 `authenticate_session` 改为通过 `account_uid` 关联账号
- 对外业务唯一键收敛为 `provider_code + account_id`

## 1. 变更范围

本轮变更涉及以下数据库对象：

- `user_account`
- `user_profile`
- `authenticate_session`
- `authenticate_provider`
- `authenticate_identity`

变更结果：

- `user_account` 增加：
  - `account_uid`
  - `provider_code`
  - `provider_subject`
  - `provider_login`
  - `provider_display_name`
  - `provider_email`
  - `profile_json`
  - `bound_at`
- `authenticate_session` 增加：
  - `account_uid`
- `authenticate_identity` 数据回填进 `user_account` 后删除

## 2. 脚本清单

数据库脚本目录：

- `/Users/iter_1024/repository/iterlife-idaas/database`

本轮相关脚本：

1. [20260427_01_account_auth_baseline.sql](/Users/iter_1024/repository/iterlife-idaas/database/20260427_01_account_auth_baseline.sql:1)
用途：
完成本轮核心结构改造、历史数据回填、索引重建、`authenticate_identity` 下线。

2. [20260429_01_provider_visibility_baseline.sql](/Users/iter_1024/repository/iterlife-idaas/database/20260429_01_provider_visibility_baseline.sql:1)
用途：
初始化 / 校正 provider 的 `visible`、`enabled`、`display_order` 基线。

3. [20260429_02_provider_go_live.sql](/Users/iter_1024/repository/iterlife-idaas/database/20260429_02_provider_go_live.sql:1)
用途：
联调完成后按需开启 `apple / microsoft / x` 等 provider。

4. [20260429_03_account_identity_merge.sql](/Users/iter_1024/repository/iterlife-idaas/database/20260429_03_account_identity_merge.sql:1)
用途：
便捷入口脚本，内部仅 `SOURCE 20260427_01_account_auth_baseline.sql`。

注意：

- `20260429_03_account_identity_merge.sql` 和 `20260427_01_account_auth_baseline.sql` 是二选一关系，不要重复执行两次核心迁移。
- `20260429_01` 与 `20260429_02` 是核心迁移后的补充脚本。

## 3. 推荐执行路径

### 路径 A：推荐

适用于使用 MySQL 客户端并能在脚本目录下执行 `SOURCE` 的场景。

执行顺序：

1. 执行 `20260429_03_account_identity_merge.sql`
2. 执行 `20260429_01_provider_visibility_baseline.sql`
3. 按需执行 `20260429_02_provider_go_live.sql`

### 路径 B：直接执行

适用于不使用 `SOURCE` 包装脚本的场景。

执行顺序：

1. 执行 `20260427_01_account_auth_baseline.sql`
2. 执行 `20260429_01_provider_visibility_baseline.sql`
3. 按需执行 `20260429_02_provider_go_live.sql`

## 4. 执行前检查

执行前必须完成：

1. 对目标库做完整备份。
2. 确认当前应用已停止自动发布数据库变更。
3. 确认当前数据库为 MySQL `8.0.35`。
4. 确认本轮变更窗口内不执行手工修数。

建议先执行以下检查 SQL：

```sql
SELECT VERSION();

SHOW TABLES LIKE 'user_account';
SHOW TABLES LIKE 'authenticate_identity';
SHOW TABLES LIKE 'authenticate_session';

SELECT COUNT(*) AS identity_rows FROM authenticate_identity;
SELECT COUNT(*) AS account_rows FROM user_account;
SELECT COUNT(*) AS session_rows FROM authenticate_session;
```

建议重点巡检以下异常：

```sql
SELECT account_id, COUNT(*) AS active_identity_count
FROM authenticate_identity
WHERE COALESCE(NULLIF(status, ''), 'ACTIVE') = 'ACTIVE'
GROUP BY account_id
HAVING COUNT(*) > 1;

SELECT provider_code, provider_subject, COUNT(*) AS duplicate_count
FROM authenticate_identity
WHERE COALESCE(NULLIF(status, ''), 'ACTIVE') = 'ACTIVE'
GROUP BY provider_code, provider_subject
HAVING COUNT(*) > 1;

SELECT id, user_id, account_id
FROM user_account
WHERE account_id IS NULL OR account_id = '';
```

说明：

- 如果一个 `account_id` 对应多条有效 `authenticate_identity`，核心迁移脚本会按 `bound_at / created_at` 最新一条回填。
- 如果你不接受“最新一条优先”的收敛规则，应先人工清理再执行。

## 5. 执行命令示例

### 5.1 路径 A：使用包装脚本

先进入脚本目录：

```bash
cd /Users/iter_1024/repository/iterlife-idaas/database
mysql -h <HOST> -u <USER> -p <DB_NAME>
```

在 MySQL 客户端内执行：

```sql
SOURCE 20260429_03_account_identity_merge.sql;
SOURCE 20260429_01_provider_visibility_baseline.sql;
```

如需开启新 provider，再执行：

```sql
SOURCE 20260429_02_provider_go_live.sql;
```

### 5.2 路径 B：直接执行核心脚本

```bash
mysql -h <HOST> -u <USER> -p <DB_NAME> < /Users/iter_1024/repository/iterlife-idaas/database/20260427_01_account_auth_baseline.sql
mysql -h <HOST> -u <USER> -p <DB_NAME> < /Users/iter_1024/repository/iterlife-idaas/database/20260429_01_provider_visibility_baseline.sql
```

如需开启新 provider：

```bash
mysql -h <HOST> -u <USER> -p <DB_NAME> < /Users/iter_1024/repository/iterlife-idaas/database/20260429_02_provider_go_live.sql
```

## 6. 执行后校验

### 6.1 表结构校验

```sql
SHOW COLUMNS FROM user_account;
SHOW COLUMNS FROM authenticate_session;
SHOW TABLES LIKE 'authenticate_identity';
```

预期：

- `user_account` 存在以下关键列：
  - `account_uid`
  - `provider_code`
  - `account_id`
  - `provider_subject`
  - `provider_login`
- `authenticate_session` 存在 `account_uid`
- `authenticate_identity` 不再存在

### 6.2 关键数据校验

```sql
SELECT COUNT(*) AS missing_account_uid
FROM user_account
WHERE account_uid IS NULL OR account_uid = '';

SELECT COUNT(*) AS missing_provider_code
FROM user_account
WHERE provider_code IS NULL OR provider_code = '';

SELECT COUNT(*) AS missing_provider_subject
FROM user_account
WHERE provider_subject IS NULL OR provider_subject = '';

SELECT COUNT(*) AS missing_session_account_uid
FROM authenticate_session
WHERE account_uid IS NULL OR account_uid = '';
```

预期：

- 上述结果都应为 `0`

### 6.3 唯一约束校验

```sql
SHOW INDEX FROM user_account;
SHOW INDEX FROM authenticate_session;
```

预期存在：

- `uk_user_account_account_uid`
- `uk_user_account_provider_account`
- `uk_user_account_provider_subject`
- `uk_authenticate_session_session_id`
- `uk_authenticate_session_x_token_hash`
- `idx_authenticate_session_account_uid_client_status`

## 7. 应用侧联动检查

数据库执行完成后，需要再验证：

1. `iterlife-idaas-api` 能正常启动
2. `/actuator/health` 返回 `UP`
3. `/api/auth/providers` 返回 `200`
4. 密码登录正常
5. Google / GitHub 登录正常
6. 用户中心可正常显示 `Associated Account`
7. `Sessions` 页面或合并后的用户中心会话区能正常读取当前账号会话

## 8. 风险说明

本轮最大的迁移风险有 3 个：

1. 历史一个账号对应多条有效 `authenticate_identity`
当前脚本采用“按 `bound_at / created_at` 最新一条回填”的策略。

2. 历史第三方账号的 `account_id`
当前脚本不会强制把已有第三方账号的历史 `account_id` 改写成 `provider_login`，以避免影响旧会话和外部引用。
仅对新建账号执行“默认取 `provider_login`”规则。

3. 历史会话回填 `account_uid`
脚本会优先通过 `user_id + account_id + provider_code` 回填。如果历史数据本身已不一致，需人工核对。

## 9. 回滚建议

本轮不建议依赖“反向 SQL 回滚”，建议采用：

1. 执行前完整备份数据库
2. 如核心迁移失败，直接恢复备份
3. 若已执行成功但应用异常，优先保留数据库现状，回滚应用版本前先评估兼容性

原因：

- 本轮会删除 `authenticate_identity`
- 会重建索引与唯一约束
- 会给 `authenticate_session` 回填 `account_uid`

因此更适合“备份恢复式回滚”，不适合临时手写反向 DDL。
