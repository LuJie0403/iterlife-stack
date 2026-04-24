-- 统一身份层 provider / identity 列名收口脚本
-- 文件：20260424_03_provider_identity_alignment.sql
-- 适用库：iterlife_reunion
-- 执行方式：管理员在目标环境手动执行
-- 说明：
--   1. 将 user_account.source_identity_id 收口为 identity_id；
--   2. 将 authenticate_session.authenticate_provider 收口为 provider_code；
--   3. 将 authenticate_provider_config 表更名为 authenticate_provider；
--   4. 本脚本不依赖 Flyway，可重复执行，部分步骤会按现状跳过。

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
SET @sql := IF(
    @has_source_identity_id > 0,
    'ALTER TABLE user_account CHANGE COLUMN source_identity_id identity_id VARCHAR(64) NULL COMMENT ''账户来源''',
    IF(
        @has_account_identity_id = 0,
        'ALTER TABLE user_account ADD COLUMN identity_id VARCHAR(64) NULL COMMENT ''账户来源'' AFTER password_hash',
        'SELECT ''user_account.identity_id already present'' AS message'
    )
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
SET @has_authenticate_provider := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'authenticate_provider'
);
SET @sql := IF(
    @has_authenticate_provider > 0,
    'ALTER TABLE authenticate_session CHANGE COLUMN authenticate_provider provider_code VARCHAR(32) NULL COMMENT ''认证提供方''',
    IF(
        @has_session_provider_code = 0,
        'ALTER TABLE authenticate_session ADD COLUMN provider_code VARCHAR(32) NULL COMMENT ''认证提供方'' AFTER status',
        'SELECT ''authenticate_session.provider_code already present'' AS message'
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
    'SELECT ''authenticate_provider already present or authenticate_provider_config absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;
