-- IterLife 认证表重命名与配置收口脚本
-- 文件：20260420_01_authenticate_tables.sql
-- 适用库：iterlife_reunion
-- 执行方式：管理员在生产或目标环境手动执行
-- 说明：
--   1. 认证相关表统一收敛到 authenticate_* / user_account 命名；
--   2. 若目标表已存在，则按治理规则先删除目标表，再将旧表更名到新表；
--   3. 清理已废弃的旧认证表与 Flyway 历史表；
--   4. 同步补齐 user_account.signup_source 与 authenticate_provider_config 默认数据。

SET @source_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'reunion_user'
);
SET @target_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
);
SET @sql := IF(
    @source_exists > 0 AND @target_exists > 0,
    'DROP TABLE user_account',
    'SELECT ''user_account target not present'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @source_exists > 0,
    'RENAME TABLE reunion_user TO user_account',
    'SELECT ''reunion_user source not present'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @source_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_identity'
);
SET @target_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_identity'
);
SET @sql := IF(
    @source_exists > 0 AND @target_exists > 0,
    'DROP TABLE authenticate_identity',
    'SELECT ''authenticate_identity target not present'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @source_exists > 0,
    'RENAME TABLE user_identity TO authenticate_identity',
    'SELECT ''user_identity source not present'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @source_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_session'
);
SET @target_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
);
SET @sql := IF(
    @source_exists > 0 AND @target_exists > 0,
    'DROP TABLE authenticate_session',
    'SELECT ''authenticate_session target not present'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @source_exists > 0,
    'RENAME TABLE user_session TO authenticate_session',
    'SELECT ''user_session source not present'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @source_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'auth_provider_config'
);
SET @target_exists := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_provider_config'
);
SET @sql := IF(
    @source_exists > 0 AND @target_exists > 0,
    'DROP TABLE authenticate_provider_config',
    'SELECT ''authenticate_provider_config target not present'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @source_exists > 0,
    'RENAME TABLE auth_provider_config TO authenticate_provider_config',
    'SELECT ''auth_provider_config source not present'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

CREATE TABLE IF NOT EXISTS authenticate_provider_config (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    provider_code VARCHAR(32) NOT NULL,
    enabled TINYINT(1) NOT NULL DEFAULT 0,
    visible TINYINT(1) NOT NULL DEFAULT 0,
    display_order INT NOT NULL DEFAULT 100,
    desktop_mode VARCHAR(32) NOT NULL DEFAULT 'oauth_redirect',
    mobile_mode VARCHAR(32) NOT NULL DEFAULT 'oauth_redirect',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_authenticate_provider_config_code (provider_code)
);

SET @has_signup_source := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'signup_source'
);
SET @sql := IF(
    @has_signup_source = 0,
    'ALTER TABLE user_account ADD COLUMN signup_source VARCHAR(32) NULL AFTER password_hash',
    'SELECT ''signup_source already exists'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

INSERT INTO authenticate_provider_config (
    provider_code,
    enabled,
    visible,
    display_order,
    desktop_mode,
    mobile_mode
)
VALUES
    ('password', 1, 1, 10, 'password_form', 'password_form'),
    ('google', 1, 1, 20, 'oauth_redirect', 'oauth_redirect'),
    ('github', 1, 1, 30, 'oauth_redirect', 'oauth_redirect'),
    ('apple', 0, 0, 40, 'oauth_redirect', 'oauth_redirect'),
    ('weixin', 1, 1, 50, 'qr_popup', 'hidden'),
    ('microsoft', 0, 0, 60, 'oauth_redirect', 'oauth_redirect'),
    ('x', 0, 0, 70, 'oauth_redirect', 'oauth_redirect'),
    ('facebook', 0, 0, 80, 'oauth_redirect', 'oauth_redirect'),
    ('alipay', 0, 0, 90, 'qr_popup', 'hidden')
ON DUPLICATE KEY UPDATE
    enabled = VALUES(enabled),
    visible = VALUES(visible),
    display_order = VALUES(display_order),
    desktop_mode = VALUES(desktop_mode),
    mobile_mode = VALUES(mobile_mode),
    updated_at = CURRENT_TIMESTAMP;

UPDATE user_account ua
JOIN (
    SELECT ai.user_id, ai.provider
    FROM authenticate_identity ai
    JOIN (
        SELECT user_id, MIN(id) AS first_identity_id
        FROM authenticate_identity
        GROUP BY user_id
    ) first_identity
        ON first_identity.first_identity_id = ai.id
) first_provider
    ON first_provider.user_id = ua.id
SET ua.signup_source = first_provider.provider
WHERE ua.signup_source IS NULL
  AND first_provider.provider IS NOT NULL;

UPDATE user_account
SET signup_source = 'password'
WHERE signup_source IS NULL
  AND password_hash IS NOT NULL;

UPDATE user_account
SET signup_source = 'password'
WHERE signup_source IS NULL;

DROP TABLE IF EXISTS auth_user_identity;
DROP TABLE IF EXISTS auth_login_session;
DROP TABLE IF EXISTS flyway_schema_history;
