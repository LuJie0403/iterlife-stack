# 统一身份管理设计

最后更新：2026-04-11

适用范围：`iterlife-reunion`、`iterlife-reunion-ui`、`iterlife-expenses`、`iterlife-expenses-ui`、`iterlife-idaas`、`iterlife-idaas-ui`

## 1. 当前定位

`iterlife-idaas` / `iterlife-idaas-ui` 是 IterLife 的统一身份层，负责承载认证、会话、第三方登录和跨应用身份跳转。

## 2. 目标边界

### `iterlife-idaas`

负责：

- 统一认证
- 统一会话管理
- access token / refresh token 签发与刷新
- 账户主档与身份绑定
- 角色与权限基础模型

### `iterlife-idaas-ui`

负责：

- 登录页
- 第三方登录回调页
- 会话管理页
- 跨应用跳转承接页

### `iterlife-reunion` / `iterlife-expenses`

作为业务应用，只负责：

- 业务 API
- 验证来自 `iterlife-idaas` 的 token
- 基于用户标识和权限做业务授权

## 3. 当前能力边界

当前认证方式：

- 用户名密码
- GitHub
- Google
- 微信 PC 扫码

当前会话能力：

- access token / refresh token
- 当前用户信息查询
- 会话列表
- 当前会话登出
- 全部会话登出

当前前端能力：

- 登录入口
- OAuth 回调承接
- 会话中心
- 统一登出与跨应用跳转

## 4. 统一模型

### 4.1 主体原则

- 统一账户主档优先于认证切换。
- 统一身份层负责账户主档、身份绑定和会话状态。
- 业务系统不再承担全局身份 token 签发职责。

### 4.2 会话原则

- access token 短期有效。
- refresh token 用于续期。
- 会话必须可撤销、可审计、可单端退出和全端退出。

### 4.3 认证与授权分层

- Authentication 解决“你是谁”和“当前会话是否有效”。
- Authorization 解决“你能访问什么资源、执行什么操作”。
- 当前优先完成统一认证和统一会话，授权模型继续按业务演进。

## 5. 核心数据对象

- `reunion_user`
- `user_identity`
- `user_session`
- `authorize_role`
- `authorize_permission`
- `user_role`
- `authorize_role_permission`

## 6. 当前接入状态

- `iterlife-idaas` / `iterlife-idaas-ui` 当前版本为 `0.1.0-SNAPSHOT`。
- `reunion` 已具备统一登录入口、会话中心入口和统一登出接口。
- `expenses` 当前主线仍保留本地 JWT 登录实现，后续继续向统一身份收敛。
- 正式发布与运维事实源统一收敛在 `iterlife-stack/docs/operations_deployment_baseline_20260411.md`。
