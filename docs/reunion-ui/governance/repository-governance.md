# IterLife Reunion UI 仓库治理

这份文档记录 `iterlife-reunion-ui` 当前生效的仓库结构、命名与维护规则。

## 1. 文档定位

- 适用范围：`iterlife-reunion-ui`
- 当前 `docs/governance/` 目录以本文件为唯一治理入口
- 过时的分析草稿不再留在根目录或 README

## 2. 当前结构结论

### 2.1 当前已形成的健康结构

- 顶层目录仍然符合 Nuxt 约定：`pages/`、`components/`、`composables/`、`config/`、`public/`、`types/`
- `components/articles/` 已经形成文章域组件聚合
- `components/home/` 已形成首页框架域聚合
- 双首页已经完成“公共壳 + 内容槽位”重构：
  - `components/home/index.vue`
  - `components/home/AiHero.vue`
  - `components/home/CoderHero.vue`
- 首页共享能力已经下沉为公共模块：
  - `components/home/ModeSwitch.vue`
  - `components/home/EntryNav.vue`
- 页面层已经明显变薄：
  - `pages/ai.vue`
  - `pages/coder.vue`

### 2.2 当前主要结构风险

按照文件体量、职责聚合度和后续扩张风险，当前优先关注点如下：

#### P0 热点文件

- `assets/css/main.css`：`1728` 行
- `components/home/AiHero.vue`：`475` 行
- `composables/useArticleSidebar.ts`：`308` 行
- `composables/useMarkdownRenderer.ts`：`269` 行
- `components/articles/ArticleShareDialog.vue`：`250` 行

#### P1 中等风险文件

- `components/home/CoderHero.vue`：`168` 行
- `components/articles/ArticleSidebar.vue`：`155` 行
- `components/articles/ArticleUtilityDialog.vue`：`155` 行
- `components/articles/SocialIcon.vue`：`151` 行
- `config/articleProfile.ts`：`140` 行
- `components/articles/ArticleSupportDialog.vue`：`130` 行
- `components/home/index.vue`：`119` 行

### 2.3 与旧治理文档相比，现状已发生的关键变化

- 旧文档中的 `pages/index.vue` 已不再是首页内容页，这项判断已过时
- 首页域已经从“建议拆到 `components/home/`”变成“已经拆分完成”
- 首页共享壳、共享导航、共享切换入口已经落地，不应再把首页视为单文件页面
- 当前治理重点已经不再是“是否创建 `home/`”，而是“如何继续把 home 和 article 两个功能域做深治理”

## 3. 当前治理原则

### 3.1 目录原则

- `pages/`：只承载路由入口与页面级装配
- `components/`：只承载 UI 组件，必须按功能域分目录
- `composables/`：只承载组合式逻辑，按领域前缀命名
- `config/`：只承载版本内受控配置，不继续堆叠内容型大对象
- `public/`：只承载运行时直出资源
- `docs/`：只承载规则、说明、部署、治理类文档

### 3.2 命名原则

- 目录内命名统一小写文件名
- `components/home/` 下保持：
  - `index.vue`
  - `aihero.vue`
  - `coderhero.vue`
  - `entrynav.vue`
  - `modeswitch.vue`
- `components/articles/` 继续保留 `Article*` 前缀，避免文章域组件互相混淆
- composable 继续保留 `useArticle*`、`use*Api` 命名风格

### 3.3 拆分阈值

- `pages/*.vue` 超过 `120` 行必须评估下沉
- `components/**/*.vue` 超过 `180` 行必须评估拆分
- `composables/*.ts` 超过 `200` 行必须评估拆分
- `config/*.ts` 超过 `120` 行且同时承载两种以上主题数据，必须评估拆分
- `assets/css/*.css` 超过 `400` 行必须评估按主题拆分

## 4. 最新可落地治理计划

### Phase 0：冻结规则和索引

优先级：`最高`

目标：

- 让当前结构共识固定下来，避免后续新增文件再次偏离

执行项：

- 将本文件作为当前唯一结构治理入口
- 在 `docs/reunion-ui/README.md` 中显式索引本文件
- 后续 PR 评审统一增加“目录与命名检查”项

完成标准：

- 新增文件有明确落位依据
- 后续讨论默认引用这份文档，而不是旧的 `v1.0.2` 基线文档

### Phase 1：首页域继续收口

优先级：`高`

目标：

- 让 `home` 域从“已拆分”进入“可维护”状态

执行项：

1. 拆 `components/home/AiHero.vue`
   - `Gemini` 卡片
   - `ChatGPT` 卡片
   - `Claude` 卡片
   - 统一卡片基类样式
2. 评估 `components/home/index.vue`
   - 是否继续下沉 subtitle / title / tagline 为更小的 shell section
3. 评估 `components/home/CoderHero.vue`
   - 是否拆出语言切换器和编辑器区域

完成标准：

- `components/home/AiHero.vue` 降到 `220` 行以内
- 首页域文件职责清晰，修改一张卡片不需要通读整文件

### Phase 2：文章域热点治理

优先级：`高`

目标：

- 处理当前最容易继续膨胀的文章逻辑热点

执行项：

1. 拆 `composables/useArticleSidebar.ts`
   - 标签与筛选状态
   - 仓库读取逻辑
   - utility/support 交互状态
2. 拆 `composables/useMarkdownRenderer.ts`
   - frontmatter
   - markdown 渲染
   - mermaid / highlight 接入
3. 评估 `components/articles/ArticleShareDialog.vue`
   - 平台分享动作
   - UI 渲染
   - 复制逻辑

完成标准：

- `useArticleSidebar.ts` 降到 `160` 行以内
- `useMarkdownRenderer.ts` 降到 `160` 行以内
- 文章域大文件不再继续横向增长

### Phase 3：样式分层治理

优先级：`高`

目标：

- 解决 `assets/css/main.css` 过大问题

执行项：

1. 将 `assets/css/main.css` 拆分为：
   - `assets/css/base.css`
   - `assets/css/article.css`
   - `assets/css/home.css`
2. 在 `nuxt.config.ts` 或 `app.vue` 保持统一引入顺序
3. 清理遗留的页面局部重复样式

完成标准：

- `main.css` 不再承担所有主题样式
- 样式修改可以明确判断属于 `base / article / home`

### Phase 4：配置与内容治理

优先级：`中`

目标：

- 让 `config/articleProfile.ts` 从大一统对象演进为兼容出口

执行项：

1. 新建 `config/content/`
2. 将 `articleProfile.ts` 内部拆成：
   - `profile.ts`
   - `applications.ts`
   - `support.ts`
   - `repositories.ts`
3. 保留 `articleProfile.ts` 作为聚合出口

完成标准：

- 业务侧引用不需要一次性大改
- 配置修改路径清楚，不再继续向单文件堆内容

### Phase 5：测试与文档镜像治理

优先级：`中`

目标：

- 建立功能域与测试域的镜像关系

执行项：

1. 规范 `tests/`
   - `tests/unit/`
   - `tests/smoke/`
2. 首页域新增测试时优先放：
   - `tests/unit/home-*`
3. 文档索引同步治理：
   - 新增治理文档必须同步更新 `docs/reunion-ui/README.md`

完成标准：

- 测试文件位置更可预测
- 文档新增后不再缺索引

## 5. 不建议立即做的事

- 不建议把 Nuxt 页面路由改造成自定义复杂路由层
- 不建议把文章域一次性改成深层 DDD 目录
- 不建议现在引入新的 `utils/` 目录，除非已经出现明显的跨域纯函数复用
- 不建议把 `home` 和 `articles` 混成更大的 “feature” 根目录，当前规模还不需要

## 6. 推荐执行顺序

### 一周内

1. 固化本治理文档和文档索引
2. 拆 `components/home/AiHero.vue`
3. 拆 `assets/css/main.css`

### 下一个迭代

1. 拆 `useArticleSidebar.ts`
2. 拆 `useMarkdownRenderer.ts`
3. 评估 `ArticleShareDialog.vue`

### 再下一个迭代

1. 拆 `config/articleProfile.ts`
2. 建立 `tests/unit/` / `tests/smoke/`
3. 清理 `public/` 未被引用资源和命名噪音

## 7. 本轮执行检查清单

- 新文件是否进入正确功能目录
- 首页域是否继续沿用小写文件命名
- 页面文件是否保持“路由装配而非重逻辑”
- 是否继续向 `assets/css/main.css` 堆新样式
- 是否继续向 `config/articleProfile.ts` 堆新内容
- 新增文档是否同步更新 `docs/reunion-ui/README.md`

## 8. 非代码资产与生成物治理

### 8.1 目标

- 保持非代码资产与线上运行时一致
- 减少仓库噪音和失效资源滞留
- 让资源、配置、部署资料各自有稳定落位

### 8.2 放置规则

- CI/CD 与部署参考资料统一收口到 `iterlife-reunion-stack/docs/`
- 仓库治理与结构规则放在 `docs/governance/`
- 运行时需要直出的静态资源放在 `public/`
- 受版本控制的内容配置放在 `config/`
- 活跃的头像、二维码、支持类资源必须与对应配置文件保持引用一致

### 8.3 生成物规则

- `.nuxt/`、`.output/`、`node_modules/` 等生成目录不进入 code review
- 本地构建、预览、调试产物不应作为仓库资产提交
- 运行时资源应优先从受版本控制的源码目录生成，而不是在服务器上手工维护副本

### 8.4 工具链规则

- `pnpm` 是唯一包管理器基线
- CI、本地开发、Docker 构建都应以 `pnpm-lock.yaml` 为准

### 8.5 资产卫生规则

- 删除 `.DS_Store` 等操作系统噪音文件
- 已废弃但仍保留的资源应明确归档或删除，不长期伪装成“仍在使用”
- 同一用途不应长期保留多份“都像在线版本”的二维码、头像或海报素材，除非有明确状态说明
- `public/` 下资源若不再被配置或页面引用，应在相关 PR 中一起清理

## 9. 一句话结论

当前仓库已经从“需要决定目录方向”进入“沿着既有功能域做深治理”的阶段。  
最新治理重点不再是是否建立 `home/`，而是：

1. 把 `home` 域真正拆细
2. 把文章域热点逻辑拆开
3. 把全站样式和内容配置从大文件里释放出来
