# 统一身份管理设计

创建日期：2026-04-19
最后更新：2026-04-19

本文档统一描述 IterLife 当前统一身份层的定位、能力边界、核心模型，以及登录页的目标交互设计。

适用范围：`iterlife-reunion`、`iterlife-reunion-ui`、`iterlife-expenses`、`iterlife-expenses-ui`、`iterlife-idaas`、`iterlife-idaas-ui`

## 1. 当前定位

`iterlife-idaas` / `iterlife-idaas-ui` 是 IterLife 的统一身份层，负责承载用户、认证（含第三方登录认证及会话）、权限（功能权限及数据权限）管理等。

## 2. 目标边界

### `iterlife-idaas`

负责：
- 用户管理
- 统一认证（含账号管理、本地及第三方认证、会话管理等）
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

当前隐藏但已具备实现基础的认证方式：

- 微信 PC 扫码

本轮设计目标支持的认证方式：

- 用户名密码
- Google
- GitHub
- X
- Apple
- Microsoft
- Facebook（实现，但是隐藏入口）
- 微信扫码
- 支付宝扫码

当前会话能力：

- access token / refresh token
- 当前用户信息查询
- 会话列表
- 会话登出（一次登出，全局失效）

当前前端能力：

- 登录入口
- OAuth 回调承接
- 会话中心
- 统一登出与跨应用跳转

本轮设计目标前端能力：

- 更简洁的单页登录入口
- 图标化第三方登录入口
- 微信扫码弹层承接
- 桌面与移动端统一的轻量登录视觉
- 基于配置的登录方式显隐

## 4. 登录页设计基线

### 4.1 设计目标

- 参考附件中的轻量登录卡片，整体从“控制台页面”收敛为“单一登录动作页面”。
- 保留统一身份层的完整能力，但首屏只突出“登录”这一件事。
- 页面必须对真实能力保持诚实，不展示尚未落地的注册链接、忘记密码流程或不可用的第三方按钮。
- 优先兼容移动端视觉，同时保持桌面端居中窄栏体验。

### 4.2 页面结构

- 页面主体改为单列居中卡片，宽度收敛到适合移动端截图比例的窄卡。
- 卡片顶部保留可选返回入口：
  - 当存在 `redirect_uri` 或明确来自业务系统时，显示返回箭头。
  - 独立访问 IDaaS 时，不强制显示返回箭头。
- 标题使用 `Sign in`。
- 副标题不再默认展示“Create an account”。
  - 当前 IterLife 没有开放自助注册时，副标题改为更真实的说明文案，例如“Use your IterLife account to continue.”
  - 当未来确实开放自助注册后，再切换为注册入口文案。
- 表单区只保留两个输入项：
  - `Email or username`
  - `Password`
- 表单下方只在真实能力存在时展示辅助入口：
  - 若已上线找回密码，则展示 `Forgot password?`
  - 若未上线，则不展示死链接
- 主按钮为整行圆角按钮，文案统一为 `Login` 或 `Sign in`。
- 主按钮下方使用一条分割线和 `or`，把密码登录与第三方登录明确分层。
- 第三方登录区采用图标化入口，不再使用当前的大块 provider card。
- 卡片底部保留简短的条款说明和隐私政策链接。

### 4.3 第三方登录区布局

- 登录方式使用圆形图标按钮，风格参考附件中的轻量社交图标行。
- 为兼顾简洁和完整支持，首选两行布局：
  - 第一行：Google、GitHub、Apple、微信扫码
  - 第二行：Microsoft、X、Facebook、支付宝扫码
- 若配置中未启用某一 provider，则该 provider 不占位、不显示 disabled 按钮。
- 当实际启用的 provider 不超过 4 个时，第三方登录区自动收敛为单行。
- 图标区标题建议改为简短版本，例如：
  - `Continue with`
  - 或 `Use another sign-in method`

### 4.4 各登录方式的交互约束

- 用户名密码：
  - 仍然作为首屏默认路径
  - 输入框使用内嵌图标和弱边框，弱化后台系统感
- GitHub / Google / Apple / Microsoft / X / Facebook：
  - 统一采用点击图标后发起 OAuth 跳转
  - callback 仍由 `iterlife-idaas-ui` 承接
  - provider 不可用时，按钮不展示，而不是展示后报错
- 支付宝扫码：
  - 作为国内主流扫码登录方式，与微信扫码并列
  - 桌面端点击后优先打开支付宝二维码弹层，由用户使用支付宝 App 扫码
  - 移动端若在支付宝内打开，可切到支付宝内授权路径
  - 移动端若不在支付宝内，默认不展示二维码弹层，避免无效扫码交互
- 微信扫码：
  - 当前微信扫码能力已经实现，但登录页默认继续隐藏，直到本轮简化登录页一并正式开放。
  - 设计上不建议直接等同为普通 OAuth 跳转按钮
  - 桌面端点击后应优先打开二维码弹层，由用户使用微信扫码
  - 移动端若在微信内打开，可切到微信内授权路径
  - 移动端若不在微信内，默认不展示二维码弹层，避免“自己扫自己”的无效交互

### 4.5 视觉基线

- 背景从当前偏“深色控制台”风格，收敛为更轻的浅底或柔和浅灰底，突出登录卡片本身。
- 卡片使用白色或近白色表面，圆角更大，阴影更轻，接近移动端原生登录面板。
- 输入框改为浅底、浅边框和内嵌图标，不再使用当前厚重的深色输入框。
- 主按钮改为纯黑或高对比深色填充，保持视觉上只有一个主动作。
- 第三方登录按钮统一为圆形边框图标，不再混用文字按钮和卡片按钮。
- 页面上方品牌信息缩小，避免与登录动作竞争。

### 4.6 文案与真实性要求

- 当前不展示“Create an account”，除非自助注册真实可用。
- 当前不展示“Forgot password?”，除非密码找回真实可用。
- provider 标题、成功态、失败态文案统一简化，避免后台错误细节直接暴露在登录主页面。
- 登录页面只描述当前真实支持的能力，不透出未接入 provider 的占位文案。

### 4.7 配置与显隐原则

- 登录页面必须以“后端 provider 可用性 + 前端 feature flag”双重结果决定是否展示某个第三方入口。
- 推荐前端按 provider 维护独立开关：
  - `enableGithubLogin`
  - `enableGoogleLogin`
  - `enableAppleLogin`
  - `enableMicrosoftLogin`
  - `enableXLogin`
  - `enableFacebookLogin`
  - `enableAlipayLogin`
  - `enableWeixinLogin`
- 最终展示顺序固定，不因显隐变化改变主次逻辑，只在缺项时自动收缩布局。

### 4.8 登录方式配置来源

- 每种登录方式是否“可用”与是否“在页面显示”，都必须由数据库配置决定，而不是只靠前端写死或环境变量写死。
- 对应的数据库结构与初始化数据变更，统一通过 `iterlife-stack/docs/sql/*.sql` 人工执行脚本管理，不通过 Flyway 等运行时迁移框架自动执行。
- 当前阶段暂不实现管理界面，直接通过数据库维护配置即可。
- 推荐把 provider 配置拆成两层语义：
  - `enabled`：后端是否允许发起该 provider 的登录流程
  - `visible`：前端登录页是否展示该 provider 的入口
- 登录页是否显示某个 provider，必须同时满足：
  - 数据库配置 `enabled = true`
  - 数据库配置 `visible = true`
  - 对应 provider 的后端配置完整可用
- 即使某个 provider 已实现，如果数据库配置要求隐藏，登录页也不得展示入口。
- 国内扫码类 provider 如微信、支付宝，必须同样遵循数据库配置显隐规则。

### 4.9 响应式规则

- 桌面端：单卡片居中，第三方入口最多两行。
- 平板端：维持单卡片，留白适度增加。
- 手机端：卡片宽度接近屏幕宽度，第三方图标自动换行，主按钮保持整行。
- 微信扫码在手机端默认不走桌面二维码方案。
- 支付宝扫码在手机端默认不走桌面二维码方案。

### 4.10 页脚复用约束

- 登录页页脚必须与 `iterlife-reunion-ui` 当前页脚在结构、文案、链接和样式层面保持完全一致。
- `iterlife-idaas-ui` 不再维护独立变体页脚，不允许继续以 `APP_NAME` 等独立文案生成另一套底部信息。
- 优先复用 `iterlife-reunion-ui` 的既有页脚实现或抽出共享组件，避免未来升级时出现两套页脚漂移。
- 登录页简化只作用于登录卡片与登录区，不单独改写页脚品牌口径。

## 5. 统一模型

### 5.1 主体原则

- 统一账户主档优先于认证切换。
- 统一身份层负责账户主档、身份绑定和会话状态。
- 业务系统不再承担全局身份 token 签发职责。

### 5.2 会话原则

- access token 短期有效。
- refresh token 用于续期。
- 会话必须可撤销、可审计、可单端退出和全端退出。

### 5.3 认证与授权分层

- Authentication 解决“你是谁”和“当前会话是否有效”。
- Authorization 解决“你能访问什么资源、执行什么操作”。
- 当前优先完成统一认证和统一会话，授权模型继续按业务演进。

### 5.4 首次登录建档原则

- 每一种登录方式在首次成功认证后，都必须创建对应的 `reunion_user` 主档。
- 不允许只创建 `user_identity` 而没有主账户主档。
- 用户名密码注册用户与第三方登录用户，最终都必须归一到 `reunion_user`。
- 若后续存在账户绑定，则是在已有 `reunion_user` 上追加新的 `user_identity`，而不是跳过主档。

## 6. 第三方身份模型扩展原则

- `user_identity` 继续作为所有第三方登录方式的统一绑定表。
- 新 provider 按统一命名纳入：
  - `github`
  - `google`
  - `apple`
  - `microsoft`
  - `x`
  - `facebook`
  - `alipay`
  - `weixin`
- 每个 provider 至少统一收敛以下字段：
  - `provider`
  - `provider_subject`
  - `provider_login`
  - `provider_email`
  - `profile_json`
- 微信扫码虽然交互不同，但落库模型仍与其他第三方身份保持一致。

### 6.1 账号来源标注要求

- 每个新建的 `reunion_user` 都必须标注其首个来源。
- 首个来源至少覆盖：
  - `password`
  - `github`
  - `google`
  - `apple`
  - `microsoft`
  - `x`
  - `facebook`
  - `alipay`
  - `weixin`
- 该“来源”用于识别该账号最初是通过哪种方式进入系统，而不是当前最后一次登录方式。
- 推荐在 `reunion_user` 主档中增加稳定字段，例如 `signup_source` / `origin_provider`，而不是只把来源埋在 `profile_json`。
- `user_identity` 继续承载多 provider 绑定关系；`reunion_user` 承载首个来源事实。
- 若后续用户再绑定其他 provider，不应覆盖主档的首个来源字段。

## 7. 核心数据对象

- `reunion_user`
- `user_identity`
- `user_session`
- `authorize_role`
- `authorize_permission`
- `user_role`
- `authorize_role_permission`

推荐新增配置对象：

- `auth_provider_config`

建议至少包含：

- `provider_code`
- `enabled`
- `visible`
- `display_order`
- `desktop_mode`
- `mobile_mode`
- `updated_at`

其中：

- `desktop_mode` 可用于区分 `oauth_redirect` / `qr_popup`
- `mobile_mode` 可用于区分 `oauth_redirect` / `in_app_auth` / `hidden`

### 7.1 数据库脚本交付约束

- `auth_provider_config` 与 `reunion_user.signup_source` 的数据库变更脚本统一放在 `../sql/20260419_01_idaas_provider_config.sql`。
- 该类数据库脚本由管理员按 PR 说明手动执行，业务应用运行时不自动改库。

## 8. 当前接入状态

- `reunion` 已具备统一登录入口、会话中心入口和统一登出接口。
- `expenses` 当前主线仍保留本地 JWT 登录实现，后续继续向统一身份收敛。
- 版本、发布与运维基线统一收敛在 `../operations_deployment_baseline.md`。

## 9. 本轮设计结论

- 登录页整体改为轻量、单卡片、移动优先风格。
- 密码登录保留，但视觉上与第三方登录彻底分层。
- 第三方登录从大按钮改为图标化入口。
- 新增设计支持 Apple、Microsoft、X、Facebook、支付宝扫码和微信扫码。
- 微信扫码当前已实现但默认隐藏，本轮设计确认后再随简化登录页一起开放。
- 支付宝扫码作为国内主流扫码登录方式，与微信扫码并列纳入设计。
- 每种登录方式的启用状态与页面显隐，都由数据库配置控制，当前阶段直接改数据库，不先做管理界面。
- 微信扫码采用桌面二维码弹层优先的交互，不与普通 OAuth 图标跳转完全等同。
- 每种登录方式首次成功后都必须创建 `reunion_user`，并标注该账号的首个来源。
- 登录页页脚必须与 `iterlife-reunion-ui` 完全一致，并优先通过复用实现保持升级一致性。
- 未真实可用的注册、忘记密码或 provider 入口，不在页面展示。
