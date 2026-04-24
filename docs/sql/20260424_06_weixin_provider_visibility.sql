-- 统一身份层微信扫码入口显隐修复
-- 创建日期：2026-04-24
-- 最后更新：2026-04-24
--
-- 目的：
--   1. 修正微信扫码在登录首页未展示的问题；
--   2. 将微信登录入口收敛为“桌面端展示、移动端隐藏”的正式基线；
--   3. 保持二维码登录在桌面端使用 qr_popup，在移动端继续隐藏。

UPDATE authenticate_provider
SET
    enabled = 1,
    visible = 1,
    display_order = 50,
    desktop_mode = 'qr_popup',
    mobile_mode = 'hidden',
    updated_at = CURRENT_TIMESTAMP
WHERE provider_code = 'weixin';
