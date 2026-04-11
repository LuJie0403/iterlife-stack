# 共享前端包说明

最后更新：2026-04-11

本文档统一描述 `iterlife-stack` 当前维护的共享前端包。

## 1. 当前包清单

### `@iterlife/theme-dark-universe`

- 目录：`packages/themes/dark-universe/`
- 作用：统一黑色宇宙主题基础视觉层
- 包含：主题入口样式、基础 token、背景和罩层
- 不包含：页面布局、业务组件样式、图表主题

### `@iterlife/vue-copy-action`

- 目录：`packages/vue/copy-action/`
- 作用：统一复制按钮与已复制反馈交互
- 包含：`CopyActionButton`、`useCopyAction`、统一按钮状态样式
- 不包含：业务弹框、业务提示编排、markdown 事件委托实现

## 2. 工作区规则

`pnpm-workspace.yaml` 当前覆盖：

- `packages/*`
- `packages/*/*`

共享包统一放在 `packages/<domain>/<package>`，不新增新的顶层共享包目录。

## 3. 构建与发布

### 本地构建

```bash
cd packages/themes/dark-universe && npm run build
cd packages/vue/copy-action && pnpm build
```

### 发布入口

- `.github/workflows/publish-theme-dark-universe.yml`
- `.github/workflows/publish-vue-copy-action.yml`

### 发布凭证

- `GH_NPM_PACKAGES_PUBLISH_ACTION_TOKEN`

## 4. 接入原则

- 共享包只沉淀稳定、跨应用复用的基础能力。
- 业务页面、业务布局、业务交互编排继续留在各应用仓库。
- 包自身使用说明写在各包目录下的 `README.md`；跨仓库治理规则统一写在本文档。
