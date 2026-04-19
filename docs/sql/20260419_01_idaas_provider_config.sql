-- IterLife IDaaS 数据库变更脚本
-- 文件：20260419_01_idaas_provider_config.sql
-- 适用库：iterlife_reunion
-- 执行方式：管理员在生产或目标环境手动执行
-- 说明：本脚本替代运行时 Flyway 迁移，负责补齐 reunion_user.signup_source
--       以及 auth_provider_config 登录方式配置表。

SET @has_signup_source := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'reunion_user'
      AND COLUMN_NAME = 'signup_source'
);

SET @signup_source_sql := IF(
    @has_signup_source = 0,
    'ALTER TABLE reunion_user ADD COLUMN signup_source VARCHAR(32) NULL AFTER password_hash',
    'SELECT ''signup_source already exists'' AS message'
);

PREPARE signup_source_stmt FROM @signup_source_sql;
EXECUTE signup_source_stmt;
DEALLOCATE PREPARE signup_source_stmt;

CREATE TABLE IF NOT EXISTS auth_provider_config (
    id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
    provider_code VARCHAR(32) NOT NULL,
    enabled TINYINT(1) NOT NULL DEFAULT 0,
    visible TINYINT(1) NOT NULL DEFAULT 0,
    display_order INT NOT NULL DEFAULT 100,
    desktop_mode VARCHAR(32) NOT NULL DEFAULT 'oauth_redirect',
    mobile_mode VARCHAR(32) NOT NULL DEFAULT 'oauth_redirect',
    created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
    UNIQUE KEY uk_auth_provider_config_code (provider_code)
);

INSERT IGNORE INTO auth_provider_config (provider_code, enabled, visible, display_order, desktop_mode, mobile_mode)
VALUES
    ('password', 1, 1, 10, 'password_form', 'password_form'),
    ('google', 1, 1, 20, 'oauth_redirect', 'oauth_redirect'),
    ('github', 1, 1, 30, 'oauth_redirect', 'oauth_redirect'),
    ('apple', 0, 0, 40, 'oauth_redirect', 'oauth_redirect'),
    ('weixin', 1, 0, 50, 'qr_popup', 'hidden'),
    ('microsoft', 0, 0, 60, 'oauth_redirect', 'oauth_redirect'),
    ('x', 0, 0, 70, 'oauth_redirect', 'oauth_redirect'),
    ('facebook', 0, 0, 80, 'oauth_redirect', 'oauth_redirect'),
    ('alipay', 0, 0, 90, 'qr_popup', 'hidden');

UPDATE reunion_user ru
JOIN (
    SELECT ui.user_id, ui.provider
    FROM user_identity ui
    JOIN (
        SELECT user_id, MIN(id) AS first_identity_id
        FROM user_identity
        GROUP BY user_id
    ) first_identity
        ON first_identity.first_identity_id = ui.id
) first_provider
    ON first_provider.user_id = ru.id
SET ru.signup_source = first_provider.provider
WHERE ru.signup_source IS NULL
  AND first_provider.provider IS NOT NULL;

UPDATE reunion_user
SET signup_source = 'password'
WHERE signup_source IS NULL
  AND password_hash IS NOT NULL;

UPDATE reunion_user
SET signup_source = 'password'
WHERE signup_source IS NULL;
