-- 统一身份层账号模型字段二次收口脚本
-- 文件：20260424_04_account_schema_alignment.sql
-- 适用库：iterlife_reunion
-- 执行方式：管理员在目标环境手动执行
-- 说明：
--   1. 将 user_account.signup_source / source_identity_id 统一收口为 identity_id；
--   2. 将 authenticate_session.authenticate_source / authenticate_provider 统一收口为 provider_code；
--   3. 将 authenticate_identity.user_id 收口为 account_id，并将 provider 收口为 provider_code；
--   4. 将 authorize_role_permission.role_id / rold_id / role_code 收口为 rold_code，permission_id 收口为 permission_code；
--   5. 将 authenticate_provider_config 表更名为 authenticate_provider；
--   6. 本脚本可重复执行，已完成步骤会按现状跳过。

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
        IF(
            @has_account_identity_id = 0,
            'ALTER TABLE user_account ADD COLUMN identity_id VARCHAR(64) NULL COMMENT ''账户来源'' AFTER password_hash',
            'SELECT ''user_account.identity_id already present'' AS message'
        )
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
    IF(
        @has_identity_provider_code = 0,
        'ALTER TABLE authenticate_identity ADD COLUMN provider_code VARCHAR(32) NULL COMMENT ''认证方式'' AFTER account_id',
        'SELECT ''authenticate_identity.provider_code already present'' AS message'
    )
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
        IF(
            @has_session_provider_code = 0,
            'ALTER TABLE authenticate_session ADD COLUMN provider_code VARCHAR(32) NULL COMMENT ''认证提供方'' AFTER status',
            'SELECT ''authenticate_session.provider_code already present'' AS message'
        )
    )
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_arp_rold_code := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'rold_code'
);
SET @has_arp_role_code := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'role_code'
);
SET @has_arp_role_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'role_id'
);
SET @has_arp_rold_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'rold_id'
);
SET @sql := IF(
    @has_arp_role_code > 0 AND @has_arp_rold_code = 0,
    'ALTER TABLE authorize_role_permission CHANGE COLUMN role_code rold_code VARCHAR(64) NULL COMMENT ''角色编码''',
    IF(
        (@has_arp_role_id > 0 OR @has_arp_rold_id > 0) AND @has_arp_rold_code = 0,
        'ALTER TABLE authorize_role_permission ADD COLUMN rold_code VARCHAR(64) NULL COMMENT ''角色编码'' AFTER id',
        'SELECT ''authorize_role_permission.rold_code already present'' AS message'
    )
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
    @has_arp_role_id > 0 AND @has_authorize_role_code > 0,
    'UPDATE authorize_role_permission arp
     JOIN authorize_role ar
       ON ar.id = arp.role_id
     SET arp.rold_code = ar.role_code
     WHERE arp.rold_code IS NULL',
    'SELECT ''authorize_role_permission.role_id backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_arp_rold_id > 0 AND @has_authorize_role_code > 0,
    'UPDATE authorize_role_permission arp
     JOIN authorize_role ar
       ON ar.id = arp.rold_id
     SET arp.rold_code = ar.role_code
     WHERE arp.rold_code IS NULL',
    'SELECT ''authorize_role_permission.rold_id backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_arp_role_id > 0,
    'ALTER TABLE authorize_role_permission DROP COLUMN role_id',
    'SELECT ''authorize_role_permission.role_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_arp_rold_id > 0,
    'ALTER TABLE authorize_role_permission DROP COLUMN rold_id',
    'SELECT ''authorize_role_permission.rold_id absent'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @has_arp_permission_code := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'permission_code'
);
SET @has_arp_permission_id := (
    SELECT COUNT(*)
    FROM information_schema.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authorize_role_permission'
      AND COLUMN_NAME = 'permission_id'
);
SET @sql := IF(
    @has_arp_permission_id > 0 AND @has_arp_permission_code = 0,
    'ALTER TABLE authorize_role_permission ADD COLUMN permission_code VARCHAR(64) NULL COMMENT ''权限编码'' AFTER rold_code',
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
    @has_arp_permission_id > 0 AND @has_authorize_permission_code > 0,
    'UPDATE authorize_role_permission arp
     JOIN authorize_permission ap
       ON ap.id = arp.permission_id
     SET arp.permission_code = ap.permission_code
     WHERE arp.permission_code IS NULL',
    'SELECT ''authorize_role_permission.permission_id backfill skipped'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

SET @sql := IF(
    @has_arp_permission_id > 0,
    'ALTER TABLE authorize_role_permission DROP COLUMN permission_id',
    'SELECT ''authorize_role_permission.permission_id absent'' AS message'
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
