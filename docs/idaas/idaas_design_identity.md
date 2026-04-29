# IterLife IDaaS 最新设计基线

创建日期：2026-04-27
最后更新：2026-04-29

本文档是 IterLife 统一身份体系的唯一正式设计事实源。

适用范围：`iterlife-idaas`、`iterlife-idaas-ui`、`iterlife-reunion`、`iterlife-expenses`

数据库统一执行说明见：[idaas_db_change_execution.md](/Users/iter_1024/repository/iterlife-stack/docs/idaas/idaas_db_change_execution.md:1)

## 1. 系统定位

`iterlife-idaas` / `iterlife-idaas-ui` 是 IterLife 的统一身份层，负责：

- 账号登录
- 第三方认证接入
- 账号维度会话管理
- 用户上下文查询
- 用户中心聚合视图

## 2. 核心概念

### 2.1 用户

- 用户是主体对象。
- 一个用户可以关联多个账号。
- 用户资料包括：
  - `user_id`
  - `user_name`
  - `email`
  - `phone`
  - `status`

### 2.2 账号

- 账号是登录载体。
- 一个账号只能属于一个用户。
- `account_id` 是账号内部稳定标识，用于会话、内部关联和系统上下文。
- `account_name` 是账号对外业务标识，默认初始化为第三方账号的 `provider_login`。
- 对外唯一键收敛为：`provider_code + account_name`。

### 2.3 认证来源

- 第三方认证来源直接并入 `user_account`。
- 每个账号只保留一种认证来源。
- 账号表直接存储：
  - `provider_code`
  - `provider_subject`
  - `provider_login`
  - `provider_email`
  - `profile_json`
- 认证稳定唯一键仍为 `provider_code + provider_subject`。

### 2.4 会话

- 会话按账号建立。
- 会话与客户端类型一起组成有效控制维度。
- 当前版本使用不透明 `X-Token`，服务端持久化 `x_token_hash`。

## 3. 核心业务规则

### 3.1 用户与账号

- 登录对外永远暴露为“账号登录”。
- 一个用户可以关联多个账号。
- 一个账号只能属于一个用户。
- 已存在账号不允许在不同用户之间迁移、归并或转移归属。

### 3.2 账号来源

- 系统不提供“注册账号”功能。
- 用户不能通过本地表单主动创建账号。
- 账号只能在第三方登录首次成功时自动创建。
- 用户中心绑定第三方账号时，本质上是在当前用户下新建一个账号并绑定该第三方身份。

### 3.3 用户名

- `user_name` 属于用户维度。
- 首次第三方登录创建用户时，初始化用户名默认使用第三方账号名。
- 初始化用户名必须全局唯一。
- 若冲突，则在原始名称后追加随机后缀，格式为 `_xxxx`，总长度 5 位以内，后缀字符仅允许字母和数字。
- 用户主动修改用户名时，必须满足：
  - 总长度不超过 12
  - 仅允许字母、数字、点、下划线、中划线
  - 全局唯一

### 3.4 密码体系

- 系统保留密码体系，为未来本地注册预留能力。
- 第三方首次创建账号时，会生成随机初始化密码，但该密码默认不可用于登录。
- 只有用户后续主动修改过密码后，才可进入“密码已激活”状态。
- 仅当以下条件同时满足时，才允许密码登录：
  - `password_activated = true`
  - `password_login_enabled = true`

### 3.5 会话规则

- 登录、登出、会话全部按账号维度管理。
- 同一账号允许多端同时在线。
- 客户端类型至少包括：
  - `PC`
  - `IOS`
  - `ANDROID`
  - `MINI_PROGRAM`
- 同一账号同一端类型发生新登录时，仅撤销该端历史有效会话。
- 不影响同一账号其他端的有效会话。
- 会话默认有效期 12 小时。
- 剩余有效期不超过 4 小时时，若仍有活跃使用，可自动续期 12 小时。
- 最长连续续期次数不超过 100 次。

## 4. 核心流程

### 4.1 密码登录

1. 用户输入账号 ID，或满足密码登录条件的用户名 / 邮箱 / 手机号。
2. 系统解析到唯一账号。
3. 校验密码是否匹配且该账号已启用密码登录。
4. 创建当前账号当前端的新会话，并撤销该账号该端旧会话。

### 4.2 第三方首次登录

1. 第三方回调返回 `provider_code + provider_subject`。
2. 若该身份不存在，则事务性创建：
   - `User`
   - `Account`
   - `Session`
3. 返回不透明 `X-Token`。

### 4.3 第三方再次登录

1. 根据 `provider_code + provider_subject` 找到已绑定账号。
2. 创建该账号当前端的新会话。
3. 撤销该账号该端旧会话。

### 4.4 用户中心绑定第三方账号

1. 当前用户已登录。
2. 用户在用户中心发起第三方绑定。
3. 若该第三方身份尚未被占用，则：
   - 在当前用户下新建一个账号
   - 在该账号记录中直接写入第三方来源信息
4. 若该第三方身份已存在绑定关系，则绑定失败。

## 5. 用户中心范围

用户中心是独立访问 IDaaS 时的默认落点，展示：

- 用户资料
- 当前账号资料
- 已关联第三方账号

用户中心不展示内部账号列表模型或内部身份列表模型。

## 6. 当前实现基线

截至当前版本，`iterlife-idaas` 与 `iterlife-idaas-ui` 的正式实现基线为：

- 后端统一使用 `X-Token`
- 后端会话按 `account_id + client_type` 管理
- 后端 `user_account.account_id` 表示内部稳定账号键
- 后端 `user_account.account_name` 表示业务账号名
- 前端 OAuth 回调直接完成登录或绑定结果承接
- 前端用户中心直接展示已关联第三方账号
- 前端会话页只操作当前账号及当前端会话

数据库最终迁移脚本已从控制面仓移出，当前正式脚本位于：

- `iterlife-idaas/database/20260427_01_account_auth_baseline.sql`

## 7. 跨系统接入基线

`iterlife-reunion`、`iterlife-expenses` 等业务系统不自行解析登录令牌含义，统一采用：

1. 前端透传 `X-Token`
2. 业务系统调用 IDaaS 上下文接口
3. IDaaS 返回当前用户与当前账号上下文

当前没有统一网关，因此业务系统直接调用 IDaaS API。

## 8. 正式文档规则

- 本文档是 IDaaS 的唯一正式设计文档。
- 历史方案、过程设计、迁移草稿、补丁说明不再保留在正式文档目录。
- 代码与数据库迁移的最终事实源分别保留在业务仓：
  - `iterlife-idaas`
  - `iterlife-idaas-ui`

## 9. Apple / Microsoft / X 接入实施清单

当前版本中，`apple`、`microsoft`、`x` 仅完成了配置占位与前端图标展示，尚未完成完整后端接入。正式改造必须按以下顺序推进。

### 9.1 后端代码改造点清单

#### 9.1.1 配置层

- 在 `iterlife-idaas` 的 `IdaasProperties` 中保留并稳定以下配置：
  - `apple.clientId`
  - `apple.clientSecret`
  - `apple.redirectUri`
  - `apple.authorizeUrl`
  - `apple.tokenUrl`
  - `apple.userInfoUrl`
  - `apple.scope`
  - `microsoft.clientId`
  - `microsoft.clientSecret`
  - `microsoft.redirectUri`
  - `microsoft.authorizeUrl`
  - `microsoft.tokenUrl`
  - `microsoft.userInfoUrl`
  - `microsoft.scope`
  - `x.clientId`
  - `x.clientSecret`
  - `x.redirectUri`
  - `x.authorizeUrl`
  - `x.tokenUrl`
  - `x.userInfoUrl`
  - `x.scope`
- `application.yml` 必须继续保留对应环境变量映射。
- Apple 若采用动态 `client_secret`，则后续需扩展：
  - `teamId`
  - `keyId`
  - `privateKey`
  - `audience`

#### 9.1.2 Provider 可用性判定

- 改造 `AuthService.isProviderConfigured(...)`。
- `apple`、`microsoft`、`x` 只有在核心配置完整时才返回 `available = true`。
- `listProviders()` 返回值中的：
  - `visible` 只表示“是否展示”
  - `enabled` 表示“是否允许使用”
  - `available` 表示“后端配置是否完整且实现是否可调用”

#### 9.1.3 OAuth 服务实现

- 新增 `AppleOAuthService`
- 新增 `MicrosoftOAuthService`
- 新增 `XOAuthService`

每个服务都必须统一提供：

- `buildAuthorizeUrl(state)`
- `authenticate(code)`

并统一返回 `ExternalIdentityProfile`，至少包含：

- `subject`
- `login`
- `email`
- `preferredUserName`

#### 9.1.4 AuthService 接入点

- 在 `providerAuthorizeUrl(...)` 中增加：
  - `apple -> appleOAuthService.buildAuthorizeUrl(state)`
  - `microsoft -> microsoftOAuthService.buildAuthorizeUrl(state)`
  - `x -> xOAuthService.buildAuthorizeUrl(state)`
- 在 `authenticateProvider(...)` 中增加：
  - `apple -> appleOAuthService.authenticate(code)`
  - `microsoft -> microsoftOAuthService.authenticate(code)`
  - `x -> xOAuthService.authenticate(code)`
- 不允许为登录和绑定分别维护两套 provider 分支逻辑。
- 登录与绑定必须继续复用当前统一链路：
  - 首次登录：自动创建 `User + Account + Identity + Session`
  - 再次登录：按 identity 找账号并创建会话
  - 绑定：在当前用户下新建账号并绑定该 identity

#### 9.1.5 平台差异处理要求

##### Apple

- `provider_subject` 使用 Apple `sub`
- `provider_login` 优先使用邮箱前缀
- 如首次授权未返回邮箱，则回退为 `apple_<短码>`
- Apple 返回姓名和邮箱可能只有首次授权可见，必须允许后续回调数据不完整
- 如采用动态 `client_secret`，必须在服务端生成签名 JWT，不直接依赖静态常量

##### Microsoft

- 建议先按 `common` 或单租户模式实现
- `provider_subject` 使用 OIDC `sub` 或稳定用户 ID
- `provider_login` 优先使用 `userPrincipalName`
- `provider_email` 允许从 `mail` 或 `userPrincipalName` 回退

##### X

- `provider_subject` 使用 X 用户 ID
- `provider_login` 使用 X username
- `provider_email` 允许为空
- 必须接受“X 平台无法稳定返回邮箱”的业务现实

#### 9.1.6 出网与代理

- 若生产继续通过 AWS HTTP 代理出网，必须补齐以下域名访问能力：
  - Apple 授权与 token 域名
  - Microsoft 登录与 Graph 域名
  - X 授权、token、userinfo 域名
- `ApacheOAuthHttpClient` 的域名匹配规则必须覆盖这些域名及其子域。
- 联调前必须先验证代理链路，否则会出现“授权页可打开，但 token exchange 超时”的问题。

#### 9.1.7 错误处理与日志

- 每个 provider 失败时必须区分以下错误类型：
  - provider 未启用
  - provider 不可见但被直接调用
  - provider 配置不完整
  - token exchange 失败
  - userinfo 获取失败
  - third-party account already linked
- 错误日志中必须带上 provider 名称，便于生产定位。

#### 9.1.8 测试要求

- `listProviders()` 的 `visible / enabled / available` 组合测试
- 三个平台授权地址生成测试
- 三个平台 token exchange / userinfo 解析测试
- 首次登录自动建档测试
- 已存在 identity 再次登录测试
- 绑定当前用户时新建账号测试
- 重复绑定失败测试

## 10. 数据库配置 SQL 草案

以下 SQL 用于初始化或修正 `authenticate_provider` 中的 `apple`、`microsoft`、`x` 配置。正式执行前，应根据生产环境实际 `display_order` 与展示策略调整。

```sql
INSERT INTO authenticate_provider (
    provider_code,
    enabled,
    visible,
    display_order,
    desktop_mode,
    mobile_mode,
    status,
    created_at,
    updated_at
) VALUES
    ('apple',     0, 0, 50, 'oauth_redirect', 'oauth_redirect', 'ACTIVE', NOW(), NOW()),
    ('microsoft', 0, 0, 60, 'oauth_redirect', 'oauth_redirect', 'ACTIVE', NOW(), NOW()),
    ('x',         0, 0, 70, 'oauth_redirect', 'oauth_redirect', 'ACTIVE', NOW(), NOW())
ON DUPLICATE KEY UPDATE
    enabled      = VALUES(enabled),
    visible      = VALUES(visible),
    display_order = VALUES(display_order),
    desktop_mode = VALUES(desktop_mode),
    mobile_mode  = VALUES(mobile_mode),
    status       = VALUES(status),
    updated_at   = NOW();
```

建议的投产策略：

- 初次落库时：
  - `enabled = 0`
  - `visible = 0`
- 单个平台联调完成后：
  - 先改 `enabled = 1`
  - 完成预发或生产联调后，再改 `visible = 1`
- 若只想灰度隐藏但保留能力：
  - `enabled = 1`
  - `visible = 0`

单个平台开启示例：

```sql
UPDATE authenticate_provider
SET enabled = 1,
    visible = 1,
    updated_at = NOW()
WHERE provider_code = 'apple';
```

排序约束：

- 登录首页与用户中心绑定入口的排序必须统一使用 `display_order`
- `password` 固定由独立逻辑优先展示
- 其余 provider 按 `authenticate_provider.display_order` 升序排列

## 11. 前端显示规则修改清单

### 11.1 登录首页

- 数据来源统一为 `/api/auth/providers`
- 展示条件改为：
  - `visible = true` 时才展示
- 可点击条件改为：
  - `enabled = true`
  - `available = true`
- 如 `visible = true` 但 `available = false`：
  - 允许展示为禁用态，文案提示“暂不可用”
  - 或由前端继续过滤；但必须与产品口径保持一致
- 排序规则：
  - `password` 单独处理
  - 其余 provider 统一按 `display_order`

### 11.2 用户中心绑定入口

- `Associated Account` 中未绑定的 provider，来源也统一为 `/api/auth/providers`
- 是否展示必须由 `authenticate_provider.visible` 决定
- 不允许前端单独硬编码 `apple / microsoft / x` 的展示开关
- 可点击条件必须与登录首页一致：
  - `enabled = true`
  - `available = true`
- 排序必须与登录首页一致

### 11.3 已绑定账号展示

- 已绑定 provider 继续来自 `/api/auth/user-center`
- 若 provider 已绑定，则显示已绑定条目
- 若 provider 未绑定但 `visible = true`，则显示可绑定入口
- 若 provider `visible = false`，则登录页与用户中心绑定入口都不展示
- 用户中心中的密码账号继续固定显示在第一位

### 11.4 前端交互约束

- 点击未绑定 provider 图标，即进入绑定流程
- 点击已绑定 provider 不进入绑定流程
- 若 provider 被展示但不可点击，必须有明确禁用态
- 登录页与用户中心不得出现同一 provider 在一个页面显示、另一个页面不显示的规则漂移

## 12. 推荐实施顺序

1. 完成 `IdaasProperties` 与 `isProviderConfigured(...)` 收口
2. 完成 `AppleOAuthService`
3. 完成 `MicrosoftOAuthService`
4. 完成 `XOAuthService`
5. 接入 `AuthService` 的授权地址与回调认证分支
6. 补齐 `authenticate_provider` 初始化数据
7. 调整前端为“按 visible 展示，按 available / enabled 控制可点击”
8. 联调代理与生产出网
9. 单个平台逐步打开 `visible`

## 13. 生产配置清单与执行顺序

以下内容是 `apple`、`microsoft`、`x` 上线前必须满足的生产基线。

### 13.1 后端环境变量清单

#### Apple

- `APPLE_CLIENT_ID`
- `APPLE_CLIENT_SECRET`
- `APPLE_REDIRECT_URI`
- `APPLE_AUTHORIZE_URL`
- `APPLE_TOKEN_URL`
- `APPLE_SCOPE`

当前实现中：

- `APPLE_AUTHORIZE_URL` 默认值：`https://appleid.apple.com/auth/authorize`
- `APPLE_TOKEN_URL` 默认值：`https://appleid.apple.com/auth/token`
- `APPLE_SCOPE` 建议先保持为空，避免当前前端回调页与 Apple `form_post` 模式冲突

#### Microsoft

- `MICROSOFT_CLIENT_ID`
- `MICROSOFT_CLIENT_SECRET`
- `MICROSOFT_REDIRECT_URI`
- `MICROSOFT_AUTHORIZE_URL`
- `MICROSOFT_TOKEN_URL`
- `MICROSOFT_USER_INFO_URL`
- `MICROSOFT_SCOPE`

默认推荐：

- `MICROSOFT_AUTHORIZE_URL=https://login.microsoftonline.com/common/oauth2/v2.0/authorize`
- `MICROSOFT_TOKEN_URL=https://login.microsoftonline.com/common/oauth2/v2.0/token`
- `MICROSOFT_USER_INFO_URL=https://graph.microsoft.com/oidc/userinfo`
- `MICROSOFT_SCOPE=openid profile email User.Read`

#### X

- `X_CLIENT_ID`
- `X_CLIENT_SECRET`
- `X_REDIRECT_URI`
- `X_AUTHORIZE_URL`
- `X_TOKEN_URL`
- `X_USER_INFO_URL`
- `X_SCOPE`

默认推荐：

- `X_AUTHORIZE_URL=https://x.com/i/oauth2/authorize`
- `X_TOKEN_URL=https://api.x.com/2/oauth2/token`
- `X_USER_INFO_URL=https://api.x.com/2/users/me`
- `X_SCOPE=users.read tweet.read offline.access`

### 13.2 代理域名清单

若生产环境继续通过 AWS HTTP 代理访问外网，则代理放行域名必须至少包含：

- `appleid.apple.com`
- `login.microsoftonline.com`
- `graph.microsoft.com`
- `x.com`
- `api.x.com`

若代理域名未放行，即使登录页已显示 provider，也会在回调 token exchange 阶段失败。

### 13.3 authenticate_provider 数据初始化顺序

#### 第一步：初始化或重置 provider 基线

执行：

- `iterlife-idaas/database/20260429_01_provider_visibility_baseline.sql`

执行结果应为：

- `apple.enabled = 0`
- `apple.visible = 0`
- `microsoft.enabled = 0`
- `microsoft.visible = 0`
- `x.enabled = 0`
- `x.visible = 0`

#### 第二步：完成单个平台联调

单个平台只有在以下条件同时满足后，才允许开启：

- 后端环境变量已配置完整
- 代理域名已放行
- `/api/auth/providers` 返回 `available = true`
- 授权地址可正常生成
- 回调 token exchange 成功
- userinfo 拉取成功

#### 第三步：开启 provider

执行：

- `iterlife-idaas/database/20260429_02_provider_go_live.sql`

按其中的单平台 SQL 逐个开启，不允许三家一次性全开。

### 13.4 推荐上线顺序

1. 先上线 `microsoft` 或 `apple`
2. 验证生产日志与回调链路
3. 再开启另一家
4. `x` 最后上线

原因：

- `x` 的邮箱字段不稳定
- `apple` 的返回字段天然较少
- `microsoft` 最接近标准 OIDC，通常联调成本最低
