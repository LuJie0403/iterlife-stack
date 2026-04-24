-- 认证模型残留字段补救脚本
-- 文件：20260424_05_auth_schema_residual_repair.sql
-- 适用库：iterlife_reunion
-- 执行方式：管理员在目标环境手动执行
-- 说明：
--   1. 用于修复生产环境仍残留 legacy 列的情况；
--   2. 重点清理 authenticate_identity.user_id 与 authenticate_session.user_id；
--   3. 本脚本可重复执行，已完成步骤会按现状跳过。

SET @has_account_identity_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'identity_id'
);
SET @has_source_identity_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'source_identity_id'
);
SET @has_signup_source := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'signup_source'
);
SET @sql := IF(
    @has_signup_source > 0,
    'ALTER TABLE user_account CHANGE COLUMN signup_source identity_id VARCHAR(64) NULL COMMENT ''账户来源''',
    IF(
        @has_source_identity_id > 0,
        'ALTER TABLE user_account CHANGE COLUMN source_identity_id identity_id VARCHAR(64) NULL COMMENT ''账户来源''',
        'SELECT ''user_account.identity_id already aligned'' AS message'
    )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_identity_account_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_identity'
      AND COLUMN_NAME = 'account_id'
);
SET @has_identity_user_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_identity'
      AND COLUMN_NAME = 'user_id'
);
SET @sql := IF(
    @has_identity_user_id > 0 AND @has_identity_account_id = 0,
    'ALTER TABLE authenticate_identity ADD COLUMN account_id VARCHAR(64) NULL COMMENT ''账号'' AFTER identity_id',
    'SELECT ''authenticate_identity.account_id already present or user_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_identity_user_id > 0,
    'UPDATE authenticate_identity ai
     JOIN user_account ua
       ON ua.id = ai.user_id
     SET ai.account_id = COALESCE(ai.account_id, ua.account_id)
     WHERE ai.user_id IS NOT NULL',
    'SELECT ''authenticate_identity.account_id backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_identity_user_id > 0,
    'ALTER TABLE authenticate_identity DROP COLUMN user_id',
    'SELECT ''authenticate_identity.user_id already absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_identity_provider_code := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_identity'
      AND COLUMN_NAME = 'provider_code'
);
SET @has_identity_provider := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_identity'
      AND COLUMN_NAME = 'provider'
);
SET @sql := IF(
    @has_identity_provider > 0,
    'ALTER TABLE authenticate_identity CHANGE COLUMN provider provider_code VARCHAR(32) NOT NULL COMMENT ''认证方式''',
    'SELECT ''authenticate_identity.provider_code already aligned'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_session_account_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'account_id'
);
SET @has_session_user_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'user_id'
);
SET @sql := IF(
    @has_session_user_id > 0 AND @has_session_account_id = 0,
    'ALTER TABLE authenticate_session ADD COLUMN account_id VARCHAR(64) NULL COMMENT ''账号'' AFTER session_id',
    'SELECT ''authenticate_session.account_id already present or user_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_session_user_id > 0,
    'UPDATE authenticate_session session_row
     JOIN user_account account_row
       ON account_row.id = session_row.user_id
     SET session_row.account_id = COALESCE(session_row.account_id, account_row.account_id)
     WHERE session_row.user_id IS NOT NULL',
    'SELECT ''authenticate_session.account_id backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_session_user_id > 0,
    'ALTER TABLE authenticate_session DROP COLUMN user_id',
    'SELECT ''authenticate_session.user_id already absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_session_provider_code := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'provider_code'
);
SET @has_authenticate_source := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'authenticate_source'
);
SET @has_authenticate_provider := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'authenticate_provider'
);
SET @sql := IF(
    @has_authenticate_source > 0,
    'ALTER TABLE authenticate_session CHANGE COLUMN authenticate_source provider_code VARCHAR(32) NULL COMMENT ''认证提供方''',
    IF(
        @has_authenticate_provider > 0,
        'ALTER TABLE authenticate_session CHANGE COLUMN authenticate_provider provider_code VARCHAR(32) NULL COMMENT ''认证提供方''',
        'SELECT ''authenticate_session.provider_code already aligned'' AS message'
    )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_provider_table := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_provider'
);
SET @has_provider_config_table := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_provider_config'
);
SET @sql := IF(
    @has_provider_config_table > 0 AND @has_provider_table = 0,
    'RENAME TABLE authenticate_provider_config TO authenticate_provider',
    'SELECT ''authenticate_provider already aligned'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
