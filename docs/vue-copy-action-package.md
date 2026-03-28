# Vue Copy Action 共享包说明

最后更新：2026-03-28

本文档描述 `@iterlife/vue-copy-action` 在本仓库中的当前目录位置、共享边界、发布方式和消费方式。

## 1. 当前定位

当前共享包位于：

```text
packages/vue/copy-action/
```

包名为：

```text
@iterlife/vue-copy-action
```

该包负责提供 IterLife 前端统一的复制按钮交互，不承载业务表单、业务弹框或 markdown 渲染逻辑。

## 2. 当前目录结构

```text
packages/
  vue/
    copy-action/
      LICENSE
      README.md
      package.json
      scripts/
        build.mjs
      src/
        CopyActionButton.ts
        index.ts
        style.css
        useCopyAction.ts
      tsconfig.json
```

## 3. 共享边界

### 3.1 包内共享内容

当前共享内容包括：

- 统一复制按钮组件 `CopyActionButton`。
- 统一复制状态逻辑 `useCopyAction`。
- 统一复制按钮状态样式，包括 `idle / copied / failed`。

### 3.2 不进入共享包的内容

以下内容继续留在各业务前端仓库：

- 输入框、弹框、卡片等业务布局。
- 复制成功后的业务提示文案编排。
- markdown 代码块的事件委托实现。
- 应用级主题变量和页面样式。

## 4. 当前使用方式

### 4.1 通用接入

```bash
pnpm add @iterlife/vue-copy-action
```

```ts
import '@iterlife/vue-copy-action/style.css';
import { CopyActionButton } from '@iterlife/vue-copy-action';
```

### 4.2 Nuxt 接入

```ts
export default defineNuxtConfig({
  css: ['@iterlife/vue-copy-action/style.css'],
})
```

## 5. 构建与发布

### 5.1 本地构建

```bash
cd packages/vue/copy-action
pnpm build
```

### 5.2 发布入口

共享包发布由 `.github/workflows/publish-vue-copy-action.yml` 管理：

- PR 和普通 push 触发 `verify`。
- `vue-copy-action-v*` tag 触发正式发布。

### 5.3 发布凭证

发布 npm 包使用仓库 secret：

- `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`

更完整说明见 [github-actions-secrets-inventory.md](./github-actions-secrets-inventory.md)。

## 6. 目录治理规则

- 共享包统一收纳在 `packages/<domain>/<package>`。
- 包内 README 只解释该包如何使用；跨仓库治理规则放在 `/docs`。
- 共享包只沉淀稳定交互原语，不直接沉淀业务对话框。

## 7. 变更检查清单

调整该共享包时，至少同步检查：

- `packages/vue/copy-action/package.json`
- `packages/vue/copy-action/src/`
- `.github/workflows/publish-vue-copy-action.yml`
- `pnpm-workspace.yaml`
- 本文档
