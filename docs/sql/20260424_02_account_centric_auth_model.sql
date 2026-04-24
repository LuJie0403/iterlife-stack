-- 统一身份层账号中心模型收口脚本
-- 文件：20260424_02_account_centric_auth_model.sql
-- 适用库：iterlife_reunion
-- 执行方式：管理员在目标环境手动执行
-- 说明：
--   1. 将认证模型从 user-centric 调整为 account-centric；
--   2. 所有业务关联统一切换到 account_id / identity_id / session_id / client_code；
--   3. authorize_role_permission 不再使用内部 id 进行业务关联；
--   4. 本脚本不依赖 Flyway，可重复执行，部分步骤会按现状跳过。

SET @has_table := (
    SELECT COUNT(*)
    FROM information_schema.TABLES
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_client'
);

SET @sql := IF(
    @has_table = 0,
    'CREATE TABLE authenticate_client (
        id BIGINT NOT NULL AUTO_INCREMENT PRIMARY KEY,
        client_code VARCHAR(64) NOT NULL COMMENT ''客户端编码'',
        client_name VARCHAR(128) NOT NULL COMMENT ''客户端名称'',
        client_type VARCHAR(32) NOT NULL COMMENT ''客户端类型'',
        enabled TINYINT(1) NOT NULL DEFAULT 1,
        created_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
        updated_at DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
        UNIQUE KEY uk_authenticate_client_code (client_code)
    ) COMMENT=''认证客户端注册表''',
    'SELECT ''authenticate_client already exists'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

INSERT INTO authenticate_client (
    client_code,
    client_name,
    client_type,
    enabled
)
VALUES
    ('iterlife-idaas', 'IterLife IDaaS', 'WEB', 1),
    ('iterlife-reunion', 'IterLife-Reunion', 'WEB', 1),
    ('iterlife-expenses', 'IterLife-Expenses', 'WEB', 1)
ON DUPLICATE KEY UPDATE
    client_name = VALUES(client_name),
    client_type = VALUES(client_type),
    enabled = VALUES(enabled),
    updated_at = CURRENT_TIMESTAMP;

SET @has_rold_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'rold_id'
);
SET @has_role_code := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'role_code'
);
SET @sql := IF(
    @has_rold_id > 0 AND @has_role_code = 0,
    'ALTER TABLE authorize_role_permission ADD COLUMN role_code VARCHAR(64) NULL COMMENT ''角色编码'' AFTER id',
    'SELECT ''authorize_role_permission.role_code already present or rold_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_authorize_role_code := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role'
      AND COLUMN_NAME = 'role_code'
);
SET @sql := IF(
    @has_rold_id > 0 AND @has_authorize_role_code > 0,
    'UPDATE authorize_role_permission arp
     JOIN authorize_role ar
       ON ar.id = arp.rold_id
     SET arp.role_code = ar.role_code
     WHERE arp.role_code IS NULL',
    'SELECT ''authorize_role_permission.role_code backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_rold_id > 0,
    'ALTER TABLE authorize_role_permission DROP COLUMN rold_id',
    'SELECT ''authorize_role_permission.rold_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_permission_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'permission_id'
);
SET @has_permission_code := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'permission_code'
);
SET @sql := IF(
    @has_permission_id > 0 AND @has_permission_code = 0,
    'ALTER TABLE authorize_role_permission ADD COLUMN permission_code VARCHAR(64) NULL COMMENT ''权限编码'' AFTER role_code',
    'SELECT ''authorize_role_permission.permission_code already present or permission_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_authorize_permission_code := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_permission'
      AND COLUMN_NAME = 'permission_code'
);
SET @sql := IF(
    @has_permission_id > 0 AND @has_authorize_permission_code > 0,
    'UPDATE authorize_role_permission arp
     JOIN authorize_permission ap
       ON ap.id = arp.permission_id
     SET arp.permission_code = ap.permission_code
     WHERE arp.permission_code IS NULL',
    'SELECT ''authorize_role_permission.permission_code backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_permission_id > 0,
    'ALTER TABLE authorize_role_permission DROP COLUMN permission_id',
    'SELECT ''authorize_role_permission.permission_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_account_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'account_id'
);
SET @has_uid := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'uid'
);
SET @sql := IF(
    @has_uid > 0,
    'ALTER TABLE user_account CHANGE COLUMN uid account_id VARCHAR(64) NOT NULL COMMENT ''账号''',
    'SELECT ''user_account.account_id already present or uid absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE user_account
SET account_id = REGEXP_REPLACE(account_id, '^(user_|account_)', '')
WHERE account_id REGEXP '^(user_|account_)';

SET @has_account_name := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'account_name'
);
SET @has_username := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'username'
);
SET @sql := IF(
    @has_username > 0,
    'ALTER TABLE user_account CHANGE COLUMN username account_name VARCHAR(64) NULL COMMENT ''账户名''',
    'SELECT ''user_account.account_name already present or username absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

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
    'ALTER TABLE user_account CHANGE COLUMN signup_source source_identity_id VARCHAR(64) NULL COMMENT ''账户来源''',
    IF(
        @has_source_identity_id = 0,
        'ALTER TABLE user_account ADD COLUMN source_identity_id VARCHAR(64) NULL COMMENT ''账户来源'' AFTER password_hash',
        'SELECT ''user_account.source_identity_id already present'' AS message'
    )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_email := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'email'
);
SET @sql := IF(
    @has_email > 0,
    'ALTER TABLE user_account DROP COLUMN email',
    'SELECT ''user_account.email absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_email_verified := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'user_account'
      AND COLUMN_NAME = 'email_verified'
);
SET @sql := IF(
    @has_email_verified > 0,
    'ALTER TABLE user_account DROP COLUMN email_verified',
    'SELECT ''user_account.email_verified absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_identity_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_identity'
      AND COLUMN_NAME = 'identity_id'
);
SET @has_identity_uid := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_identity'
      AND COLUMN_NAME = 'identity_uid'
);
SET @sql := IF(
    @has_identity_uid > 0,
    'ALTER TABLE authenticate_identity CHANGE COLUMN identity_uid identity_id VARCHAR(64) NOT NULL COMMENT ''身份标识''',
    'SELECT ''authenticate_identity.identity_id already present or identity_uid absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE authenticate_identity
SET identity_id = REGEXP_REPLACE(identity_id, '^identity_', '')
WHERE identity_id REGEXP '^identity_';

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
     SET ai.account_id = ua.account_id
     WHERE ai.account_id IS NULL',
    'SELECT ''authenticate_identity.account_id backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_identity_user_id > 0,
    'ALTER TABLE authenticate_identity DROP COLUMN user_id',
    'SELECT ''authenticate_identity.user_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

INSERT INTO authenticate_identity (
    identity_id,
    account_id,
    provider,
    provider_subject,
    provider_login,
    provider_email,
    profile_json
)
SELECT
    CONCAT('password-', ua.account_id),
    ua.account_id,
    'password',
    ua.account_id,
    ua.account_name,
    NULL,
    JSON_OBJECT('accountId', ua.account_id, 'source', 'password')
FROM user_account ua
LEFT JOIN authenticate_identity ai
    ON ai.account_id = ua.account_id
   AND ai.provider = 'password'
WHERE ua.password_hash IS NOT NULL
  AND ai.id IS NULL;

UPDATE user_account ua
JOIN authenticate_identity ai
    ON ai.account_id = ua.account_id
   AND ua.source_identity_id = ai.provider
SET ua.source_identity_id = ai.identity_id
WHERE ua.source_identity_id IS NOT NULL
  AND ua.source_identity_id = ai.provider;

UPDATE user_account ua
JOIN authenticate_identity ai
    ON ai.account_id = ua.account_id
   AND ai.provider = 'password'
SET ua.source_identity_id = ai.identity_id
WHERE ua.source_identity_id IS NULL;

UPDATE user_account ua
JOIN (
    SELECT account_id, MIN(id) AS first_identity_row_id
    FROM authenticate_identity
    GROUP BY account_id
) first_identity
    ON first_identity.account_id = ua.account_id
JOIN authenticate_identity ai
    ON ai.id = first_identity.first_identity_row_id
SET ua.source_identity_id = ai.identity_id
WHERE ua.source_identity_id IS NULL;

SET @has_session_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'session_id'
);
SET @has_session_uid := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'session_uid'
);
SET @sql := IF(
    @has_session_uid > 0,
    'ALTER TABLE authenticate_session CHANGE COLUMN session_uid session_id VARCHAR(64) NOT NULL COMMENT ''会话标识''',
    'SELECT ''authenticate_session.session_id already present or session_uid absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE authenticate_session
SET session_id = REGEXP_REPLACE(session_id, '^(sess_|session_)', '')
WHERE session_id REGEXP '^(sess_|session_)';

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
     SET session_row.account_id = account_row.account_id
     WHERE session_row.account_id IS NULL',
    'SELECT ''authenticate_session.account_id backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_session_user_id > 0,
    'ALTER TABLE authenticate_session DROP COLUMN user_id',
    'SELECT ''authenticate_session.user_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_authenticate_provider := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'authenticate_provider'
);
SET @has_authenticate_source := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'authenticate_source'
);
SET @sql := IF(
    @has_authenticate_source > 0,
    'ALTER TABLE authenticate_session CHANGE COLUMN authenticate_source authenticate_provider VARCHAR(32) NULL COMMENT ''认证提供方''',
    IF(
        @has_authenticate_provider = 0,
        'ALTER TABLE authenticate_session ADD COLUMN authenticate_provider VARCHAR(32) NULL COMMENT ''认证提供方'' AFTER status',
        'SELECT ''authenticate_session.authenticate_provider already present'' AS message'
    )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_session_client := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'client'
);
SET @sql := IF(
    @has_session_client = 0,
    'ALTER TABLE authenticate_session ADD COLUMN client VARCHAR(64) NULL COMMENT ''认证客户端'' AFTER authenticate_provider',
    'SELECT ''authenticate_session.client already exists'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE authenticate_session
SET client = 'iterlife-idaas'
WHERE client IS NULL;

SET @has_session_client_type := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'client_type'
);
SET @sql := IF(
    @has_session_client_type > 0,
    'UPDATE authenticate_client ac
     JOIN (
         SELECT client, MAX(client_type) AS client_type
         FROM authenticate_session
         WHERE client_type IS NOT NULL
         GROUP BY client
     ) session_type
       ON session_type.client = ac.client_code
     SET ac.client_type = session_type.client_type',
    'SELECT ''authenticate_session.client_type backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_session_client_type > 0,
    'ALTER TABLE authenticate_session DROP COLUMN client_type',
    'SELECT ''authenticate_session.client_type absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

DROP TABLE IF EXISTS auth_user_identity;
DROP TABLE IF EXISTS auth_login_session;
