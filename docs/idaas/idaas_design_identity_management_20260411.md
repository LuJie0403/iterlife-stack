# 统一身份管理设计

最后更新：2026-04-11

适用范围：`iterlife-reunion`、`iterlife-reunion-ui`、`iterlife-expenses`、`iterlife-expenses-ui`、`iterlife-idaas`、`iterlife-idaas-ui`

## 1. 当前问题

当前系统存在两套独立认证栈：

- `reunion`：GitHub OAuth + 邮箱绑定 + 本地 JWT
- `expenses`：用户名密码 + 本地 JWT

共同问题：

- 没有服务端会话表
- 没有真正意义上的登出
- 用户主档、身份源、权限判断口径不一致
- 子站之间无法形成统一登录和统一退出

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
- 账户绑定页
- 会话管理页

### `iterlife-reunion` / `iterlife-expenses`

改造后只负责：

- 业务 API
- 验证来自 `iterlife-idaas` 的 token
- 基于用户标识和权限做业务授权

## 3. 统一模型

### 3.1 主体原则

- 统一账户主档优先于认证切换。
- 本期继续沿用 `reunion_user` 作为账户主体承载表名。
- `sys_user` 只作为迁移来源，不继续作为目标用户表。

### 3.2 会话原则

- access token 短期有效。
- refresh token 用于续期。
- 会话必须可撤销、可审计、可单端退出和全端退出。
- 业务系统不再本地签发全局身份 token。

### 3.3 认证与授权分层

- Authentication 解决“你是谁”和“当前会话是否有效”。
- Authorization 解决“你能访问什么资源、执行什么操作”。
- 认证先统一，会话先落地；授权按阶段补齐。

## 4. 第一阶段范围

第一阶段固定支持四种登录方式：

- 用户名密码
- Google
- GitHub
- 微信 PC 扫码

第一阶段必须达成：

- 统一账户主档和身份绑定收口
- `iterlife-idaas` 独立认证服务可用
- `iterlife-idaas-ui` 登录与绑定壳层可用
- 两个业务系统改为资源服务
- 单点登录和统一退出具备最小闭环

## 5. 建议的核心表

- `reunion_user`
- `user_identity`
- `user_session`
- `authorize_role`
- `authorize_permission`
- `user_role`
- `authorize_role_permission`

## 6. 推荐实施顺序

1. 先统一账户主数据和身份绑定。
2. 再落地 `iterlife-idaas` 的会话、刷新、登出。
3. 再让 `reunion` / `expenses` 切到统一 token 验证。
4. 最后补齐 RBAC、数据权限和后台管理能力。

## 7. 当前交付判断

- `iterlife-idaas` / `iterlife-idaas-ui` 目前仍处于 `0.1.0-SNAPSHOT`。
- 当前阶段重点不是继续堆更多登录方式，而是先打通统一账户、统一会话和 SSO 最小闭环。
