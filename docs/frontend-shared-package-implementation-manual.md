# IterLife Frontend Shared Package Implementation Manual

最后更新：2026-03-24

适用范围：
- `iterlife-reunion-ui`
- `iterlife-expenses-ui`
- 后续新增前端应用

## 1. 背景

`iterlife-reunion-ui` 已实现一套黑色星空主题，当前主题核心样式位于 `public/theme/reunion-background.css`。`iterlife-expenses-ui` 已开始复用该主题，但复用方式仍依赖静态路径引用，而不是标准安装包。

当前方案存在以下问题：

1. 主题资源没有独立的共享资产边界。
2. 主题复用依赖跨仓库静态文件路径，链路不稳定。
3. 主题缺少版本管理、发布手册、安装手册和升级治理。
4. 背景层与应用层样式尚未形成清晰分层。

本手册用于定义共享主题包的最终实施方案，并作为后续落地、发布和接入的统一依据。

## 2. 实施目标

本期实施目标为构建一个公共 npm 主题包，统一承载 IterLife 前端的黑色宇宙主题基础能力。

目标包括：

1. 将现有背景主题抽离为独立共享包。
2. 将共享范围限定为主题基础层，而非完整业务组件层。
3. 统一安装、发布、版本管理和消费方式。
4. 完成 `iterlife-reunion-ui` 与 `iterlife-expenses-ui` 的接入改造。
5. 为未来新增主题和新增前端预留统一扩展结构。

## 3. 已确定决策

本方案已确认以下实施约束：

1. 共享源码放在 `iterlife-reunion-stack` 维护。
2. 主发布渠道采用 npm 官方公共 registry。
3. npm 已获得 `iterlife` scope。
4. 包名采用 `@iterlife/theme-dark-universe`。
5. 许可证采用 `Apache-2.0`。
6. 主题启用方式统一采用 `data-theme="dark-universe"`。
7. 首期只共享“背景 + 最小 token”，不包含业务组件视觉样式。
8. 消费方采用人工升级版本并验收，不自动跟随最新版本。

## 4. 共享边界

### 4.1 共享内容

共享包仅承担主题基础层能力，包括：

1. 页面底色。
2. 星空背景图层。
3. 上下罩层和基础发光效果。
4. 全局主文字色和弱文字色。
5. 基础边框色。
6. 基础半透明面板底色。
7. 基础链接色。
8. 基础阴影。
9. 移动端背景降级规则。

### 4.2 非共享内容

以下内容不进入本期共享包，继续保留在各自业务仓库：

1. 登录页、首页、仪表盘等具体页面布局。
2. 业务卡片样式。
3. Ant Design Vue 组件逐项定制样式。
4. 图表配色和图表主题。
5. 表格 hover、按钮态、表单状态色等业务交互色。
6. 各应用独有的页头、页脚、导航、动效和品牌组件。

### 4.3 边界影响

该边界将共享包定位为“主题基座包”而非“完整组件库”，其收益和影响如下：

1. 共享包边界清晰，稳定性更高。
2. 后续新应用接入成本更低。
3. 多主题扩展时可复用同一结构。
4. `reunion-ui` 与 `expenses-ui` 仍需保留各自应用层样式。

## 5. 主题基础 Token

本期仅定义服务于主题基础层的最小 token 集：

1. `--iterlife-color-bg-base`
2. `--iterlife-color-text-primary`
3. `--iterlife-color-text-muted`
4. `--iterlife-color-border-subtle`
5. `--iterlife-color-panel`
6. `--iterlife-color-link`
7. `--iterlife-shadow-panel`
8. `--iterlife-bg-overlay-top`
9. `--iterlife-bg-overlay-bottom`
10. `--iterlife-bg-star-primary`
11. `--iterlife-bg-star-secondary`

这些 token 只负责统一主题底层视觉语义，不直接描述业务组件外观。

## 6. 包架构设计

### 6.1 包命名与目录结构

共享包采用如下组织方式：

```text
iterlife-reunion-stack/
  packages/
    themes/
      dark-universe/
```

包名定义为：

```text
@iterlife/theme-dark-universe
```

该结构兼顾了当前单主题落地与未来多主题扩展：

1. `packages/themes` 作为统一主题层级。
2. `dark-universe` 作为当前主题实例。
3. 后续可平行扩展其他主题目录，而不影响已发布包结构。

### 6.2 主题启用模型

所有消费方统一通过根节点主题标识启用共享主题：

```html
<html data-theme="dark-universe">
```

对应主题样式以属性选择器为作用域：

```css
html[data-theme='dark-universe'] body {
  background-color: var(--iterlife-color-bg-base);
}
```

该模型用于确保：

1. 主题启用是显式行为。
2. 未来多主题切换具备统一入口。
3. 默认页面不会被无条件全局污染。

### 6.3 文件结构

建议文件结构如下：

```text
packages/
  themes/
    dark-universe/
      package.json
      README.md
      LICENSE
      src/
        tokens.css
        background.css
        index.css
      scripts/
        build.mjs
      dist/
        tokens.css
        background.css
        index.css
```

各文件职责如下：

1. `src/tokens.css`：定义最小 token。
2. `src/background.css`：定义背景层与移动端降级规则。
3. `src/index.css`：统一导出主题入口。
4. `package.json`：定义包元数据、导出和脚本。
5. `README.md`：提供对外安装与接入说明。
6. `LICENSE`：存放 Apache 2.0 标准许可证。

## 7. 主题包实施方案

### 7.1 源码迁移

主题实现以 `iterlife-reunion-ui/public/theme/reunion-background.css` 为初始来源，迁移原则如下：

1. 背景本体迁移至 `src/background.css`。
2. 可复用颜色与基础视觉语义迁移至 `src/tokens.css`。
3. 所有原本直接作用于 `body` 的样式改为在 `html[data-theme='dark-universe']` 作用域下生效。
4. 补充移动端滚动与 fixed 背景的降级规则。

### 7.2 包入口组织

统一通过 `src/index.css` 导出共享主题：

```css
@import './tokens.css';
@import './background.css';
```

构建产物输出到 `dist/`，至少包含：

1. `dist/index.css`
2. `dist/tokens.css`
3. `dist/background.css`

### 7.3 包元数据

建议 `package.json` 至少包含如下字段：

```json
{
  "name": "@iterlife/theme-dark-universe",
  "version": "0.1.0",
  "license": "Apache-2.0",
  "type": "module",
  "files": ["dist"],
  "exports": {
    ".": "./dist/index.css",
    "./index.css": "./dist/index.css",
    "./tokens.css": "./dist/tokens.css",
    "./background.css": "./dist/background.css"
  },
  "scripts": {
    "build": "node scripts/build.mjs"
  }
}
```

## 8. npm 发布方案

### 8.1 发布模型

共享主题包通过 npm 官方公共 registry 发布。由于 `iterlife` scope 已可用，首发包名直接采用：

```text
@iterlife/theme-dark-universe
```

包的注册建立发生在首次成功发布时，不需要单独申请“安装包注册”。公开包的普通使用者也不需要组织权限即可安装。

### 8.2 首次初始化

包目录初始化建议：

```bash
npm init --scope=iterlife
```

随后将 `package.json` 的名称调整为：

```json
"name": "@iterlife/theme-dark-universe"
```

同时补充：

```json
"license": "Apache-2.0"
```

如需为当前环境设置默认 scope 和公开访问策略，可配置：

```bash
npm config set scope iterlife
npm config set access public
```

### 8.3 首次发布

首次公开发布命令：

```bash
npm publish --access public
```

首次发布成功后，该包即在 npm registry 建立记录，并可被外部使用者直接安装。

### 8.4 后续版本发布

后续版本遵循语义化版本管理：

1. `patch`：修复和非破坏性调整。
2. `minor`：新增 token 或增强兼容性。
3. `major`：修改主题启用方式或其他破坏性调整。

典型发布流程：

```bash
npm version patch
npm publish --access public
```

或：

```bash
npm version minor
npm publish --access public
```

### 8.5 当前本地验证策略

在首个 npm 公开版本发布前，`iterlife-reunion-ui` 与 `iterlife-expenses-ui` 当前使用本地 `file:` 依赖指向共享包目录，以便先完成联调和构建验证。

当前依赖形态如下：

```json
"@iterlife/theme-dark-universe": "file:../iterlife-reunion-stack/packages/themes/dark-universe"
```

该策略仅用于首版发布前的本地验证，不应作为长期发布形态保留。

## 9. npm 发布 Workflow 方案

### 9.1 目标

通过 GitHub Actions 在 `iterlife-reunion-stack` 中实现自动校验和受控发布。

### 9.2 触发策略

建议采用两段式策略：

1. PR 或普通 push：仅执行安装依赖、构建和包内容校验。
2. tag 发布：仅在推送形如 `theme-dark-universe-v*` 的 tag 时执行正式发布。

该策略用于保证：

1. 日常提交不会误发 npm 包。
2. 包发布是显式动作。
3. 版本节奏可控。

### 9.3 Workflow 结构

建议 workflow 文件：

```text
.github/workflows/publish-theme-dark-universe.yml
```

建议包含两个 job：

1. `verify`
   执行 checkout、安装依赖、构建主题包、校验 `dist/` 和 `package.json` 关键字段。

2. `publish`
   仅在 tag 触发，依赖 `verify` 成功后执行，并使用 npm token 发布到 npm 官方公共 registry。

### 9.4 Workflow 所需配置

建议在 GitHub 仓库中配置：

1. `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`

该 token 需具备向 `@iterlife` scope 发布包的权限，并与 npm 组织的 2FA 策略兼容。

### 9.5 Workflow 校验项

建议流水线自动检查：

1. `name` 必须为 `@iterlife/theme-dark-universe`
2. `license` 必须为 `Apache-2.0`
3. `exports` 必须包含 `index.css`
4. `dist/index.css` 必须存在
5. `dist/tokens.css` 必须存在
6. `dist/background.css` 必须存在

## 10. 消费方接入方案

### 10.1 `iterlife-reunion-ui`

接入原则：

1. 不再依赖 `/theme/reunion-background.css` 静态路径。
2. 改为通过 npm 依赖消费共享主题包。
3. 保留文章页、卡片、代码块等应用层样式在当前仓库。

实施方式：

1. 安装 `@iterlife/theme-dark-universe`
2. 在 `nuxt.config.ts` 的 `css` 数组中引入该包
3. 删除 `app.vue` 中注入 `/theme/reunion-background.css` 的 `useHead().link` 配置
4. 在 `app.vue` 或全局入口设置 `htmlAttrs.data-theme = dark-universe`

参考接入代码：

```ts
export default defineNuxtConfig({
  css: ['@iterlife/theme-dark-universe'],
})
```

```ts
useHead({
  htmlAttrs: {
    'data-theme': 'dark-universe',
  },
})
```

### 10.2 `iterlife-expenses-ui`

接入原则：

1. 删除 `index.html` 中对 `/theme/reunion-background.css` 的直接引用。
2. 改为通过 npm 依赖消费共享主题包。
3. 保留 Ant Design Vue 主题配置、图表主题和业务页面样式在当前仓库。

实施方式：

1. 安装 `@iterlife/theme-dark-universe`
2. 在 `src/main.ts` 中引入共享主题包
3. 在启动阶段设置 `document.documentElement.dataset.theme = 'dark-universe'`

参考接入代码：

```ts
import '@iterlife/theme-dark-universe'

document.documentElement.setAttribute('data-theme', 'dark-universe')
```

## 11. 发布后依赖切换方案

首个 npm 版本发布成功后，两个消费方应从本地 `file:` 依赖切换为正式 registry 版本。

建议切换方式如下：

1. 将依赖声明从本地路径：

```json
"@iterlife/theme-dark-universe": "file:../iterlife-reunion-stack/packages/themes/dark-universe"
```

改为正式版本：

```json
"@iterlife/theme-dark-universe": "^0.1.0"
```

2. 在 `iterlife-reunion-ui` 执行：

```bash
pnpm install
```

3. 在 `iterlife-expenses-ui` 执行：

```bash
pnpm install
```

4. 重新执行构建与页面回归，确认正式 npm 版本与本地联调版本行为一致。

5. 若后续发布 `0.1.1`、`0.2.0` 等新版本，则继续通过更新依赖版本和人工验收完成升级。

## 12. 接入与安装说明

共享主题包的安装方式如下：

```bash
pnpm add @iterlife/theme-dark-universe
```

由于主渠道为 npm 官方公共 registry，普通使用者默认无需额外配置 registry，也无需加入 `iterlife` organization。只有发布者需要 npm 组织成员权限和发布凭证。

## 13. 实施 Checklist

### 13.1 主题包 Checklist

1. 创建 `packages/themes/dark-universe`
2. 迁移背景样式
3. 抽取最小 token
4. 建立 `src/index.css`
5. 配置 `package.json`
6. 添加 `LICENSE`
7. 编写 `README.md`
8. 实现构建脚本
9. 生成 `dist/`
10. 本地自检通过
11. 发布首个 npm 版本

### 13.2 `iterlife-reunion-ui` Checklist

1. 安装共享主题包
2. 在 `nuxt.config.ts` 引入共享主题
3. 删除旧静态主题 link 注入
4. 设置 `data-theme="dark-universe"`
5. 本地启动验证背景
6. 构建验证通过
7. 回归首页、文章页、页脚、代码块和链接样式

### 13.3 `iterlife-expenses-ui` Checklist

1. 安装共享主题包
2. 删除 `index.html` 中旧静态样式引用
3. 在 `src/main.ts` 引入共享主题
4. 设置 `data-theme="dark-universe"`
5. 本地启动验证背景
6. 构建验证通过
7. 回归登录页、Dashboard、Timeline、Stardust、Categories、Payment 页面

## 14. 首个 npm 发布前最终检查清单

在执行首个正式发布前，应完成以下检查：

1. `packages/themes/dark-universe/package.json` 的 `name` 已确认为 `@iterlife/theme-dark-universe`
2. `license` 已确认为 `Apache-2.0`
3. `LICENSE` 文件已存在且内容完整
4. `src/tokens.css`、`src/background.css`、`src/index.css` 已完成整理
5. `dist/index.css`、`dist/tokens.css`、`dist/background.css` 已重新生成
6. `npm run build` 已在共享包目录执行通过
7. `npm pack --dry-run` 已通过，用于确认最终发布内容
8. `iterlife-reunion-ui` 已通过本地 `file:` 依赖完成构建验证
9. `iterlife-expenses-ui` 已通过本地 `file:` 依赖完成构建验证
10. GitHub 仓库 `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN` 已配置
11. 发布 tag 命名已确认采用 `theme-dark-universe-v*`
12. 发布后消费者从 `file:` 依赖切回正式版本的步骤已准备完成

## 15. 发布与升级治理

1. 消费方固定版本范围，不自动跟随最新版本。
2. 每次升级共享主题包后，需要在 `reunion-ui` 和 `expenses-ui` 做人工验收。
3. 发布说明中应记录版本号、变更内容、接入影响和消费方是否需要补改。

## 16. 验收标准

1. `@iterlife/theme-dark-universe` 可在 npm 官方公共 registry 成功发布。
2. `iterlife-reunion-ui` 与 `iterlife-expenses-ui` 均通过 npm 依赖方式接入主题。
3. 两个项目不再依赖跨仓库复制 `reunion-background.css`。
4. 主题启用统一采用 `data-theme="dark-universe"`。
5. 许可证文件与 `package.json` 的 `license` 字段一致为 `Apache-2.0`。
6. 普通使用者无需 npm 组织权限即可安装该公共包。
7. GitHub Actions 可完成自动校验与 tag 发布。
