# 前端共享主题包说明

最后更新：2026-03-26

本文档描述 `@iterlife/theme-dark-universe` 在本仓库中的当前目录位置、共享边界、发布方式和消费方式。

## 1. 当前定位

当前共享包位于：

```text
packages/themes/dark-universe/
```

包名为：

```text
@iterlife/theme-dark-universe
```

该包是 IterLife 前端共享主题基座，负责统一黑色宇宙主题的基础视觉层，不承载业务组件和页面布局。

## 2. 当前目录结构

```text
packages/
  themes/
    dark-universe/
      LICENSE
      README.md
      package.json
      scripts/
        build.mjs
      src/
        background.css
        index.css
        tokens.css
```

工作区匹配规则由仓库根目录 `pnpm-workspace.yaml` 管理，当前覆盖：

- `packages/*`
- `packages/*/*`

这样可以保证 `packages/themes/dark-universe` 被 pnpm workspace 正确识别。

## 3. 共享边界

### 3.1 包内共享内容

当前共享内容包括：

- 主题入口样式。
- 基础 token。
- 页面背景和罩层。
- 共享基础色、弱文字色、边框色、面板色和阴影。
- 移动端背景降级规则。

### 3.2 不进入共享包的内容

以下内容继续留在各业务前端仓库：

- 登录页、首页、仪表盘等页面布局。
- 业务卡片、导航、品牌区块等应用层样式。
- 组件库逐项定制样式。
- 图表主题和业务交互色。

## 4. 当前使用方式

### 4.1 通用接入

```bash
pnpm add @iterlife/theme-dark-universe
```

```ts
import '@iterlife/theme-dark-universe'

document.documentElement.setAttribute('data-theme', 'dark-universe')
```

### 4.2 Nuxt 接入

```ts
export default defineNuxtConfig({
  css: ['@iterlife/theme-dark-universe'],
})
```

### 4.3 本地联调

跨仓库本地联调时，可以临时使用 `file:` 依赖指向该包目录。联调结束后，消费方应回到正式 npm 版本依赖。

## 5. 构建与发布

### 5.1 本地构建

```bash
cd packages/themes/dark-universe
npm run build
```

### 5.2 发布入口

共享包发布由 `.github/workflows/publish-theme-dark-universe.yml` 管理：

- PR 和普通 push 触发 `verify`。
- `theme-dark-universe-v*` tag 触发正式发布。

### 5.3 发布凭证

发布 npm 包使用仓库 secret：

- `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`

更完整说明见 [github-actions-secrets-inventory.md](./github-actions-secrets-inventory.md)。

## 6. 目录治理规则

- 共享包统一收纳在 `packages/<domain>/<package>`。
- 包内 README 只解释该包如何使用；跨仓库治理规则放在 `/docs`。
- 如果未来新增主题，继续在 `packages/themes/` 下并列扩展，不新增新的顶层共享包目录。
- 共享包只沉淀稳定基础层能力，避免演变为业务组件仓库。

## 7. 变更检查清单

调整主题包时，至少同步检查：

- `packages/themes/dark-universe/package.json`
- `packages/themes/dark-universe/src/`
- `.github/workflows/publish-theme-dark-universe.yml`
- `pnpm-workspace.yaml`
- 本文档
