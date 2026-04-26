-- IterLife 会话认证来源补充脚本
-- 文件：20260424_01_authenticate_session_source.sql
-- 适用库：iterlife_reunion
-- 执行方式：管理员在生产或目标环境手动执行
-- 说明：
--   1. 为 authenticate_session 增加 authenticate_source 字段；
--   2. 为历史会话按 user_account.signup_source 做一次最佳努力回填；
--   3. 新版本 IDaaS 会在新建会话时写入精确来源（password / google / github / weixin ...）。
--   4. 新版本 IDaaS 会在新登录成功时自动使旧会话失效，并在会话临近到期时按配置执行滚动续期。

SET @has_authenticate_source := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'authenticate_source'
);

SET @sql := IF(
    @has_authenticate_source = 0,
    'ALTER TABLE authenticate_session ADD COLUMN authenticate_source VARCHAR(32) NULL AFTER client_type',
    'SELECT ''authenticate_source already exists'' AS message'
);

PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE authenticate_session session_row
JOIN user_account account_row
    ON account_row.id = session_row.user_id
SET session_row.authenticate_source = COALESCE(account_row.signup_source, 'password')
WHERE session_row.authenticate_source IS NULL;
