-- 会话有效期、续期次数基线补充
-- 创建日期：2026-04-26
-- 最后更新：2026-04-26
--
-- 目的：
--   1. 为 authenticate_session 增加 renew_count；
--   2. 支持“默认 8 小时、到期前 4 小时内活跃可续期、最多连续续期 10 次”的会话策略；
--   3. 后续具体阈值由应用配置控制。

SET @has_renew_count := (
    SELECT COUNT(*)
    FROM INFORMATION_SCHEMA.COLUMNS
    WHERE TABLE_SCHEMA = DATABASE()
      AND TABLE_NAME = 'authenticate_session'
      AND COLUMN_NAME = 'renew_count'
);
SET @sql := IF(
    @has_renew_count = 0,
    'ALTER TABLE authenticate_session ADD COLUMN renew_count INT NOT NULL DEFAULT 0 COMMENT ''连续续期次数'' AFTER expires_at',
    'SELECT ''authenticate_session.renew_count already exists'' AS message'
);
PREPARE stmt FROM @sql;
EXECUTE stmt;
DEALLOCATE PREPARE stmt;

UPDATE authenticate_session
SET renew_count = 0
WHERE renew_count IS NULL;
