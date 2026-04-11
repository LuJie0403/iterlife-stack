# 文章阅读渲染设计

最后更新：2026-03-27  
适用范围：`iterlife-reunion-ui` 文章详情页 / 阅读弹层

## 1. 目标与边界

本设计聚焦文章阅读侧 Markdown 渲染体验，覆盖：
- 代码块高亮、语言标签、复制按钮
- GitHub 仓库内图片渲染与单图预览
- `heading anchor`

本设计不覆盖：
- 后端文章发布链路
- 后台文章管理
- 文章目录（TOC）
- `PlantUML` 图形渲染
- 运行时代码格式化

## 2. 已确认结论

### 2.1 代码块渲染

1. 页面渲染阶段保留原 Markdown 中的原始格式。
2. 不在页面渲染阶段做自动格式化；代码排版应在 Markdown 源文件中完成。
3. 每个代码块需支持：
   - 语法高亮
   - 语言标签
   - `Copy` 按钮
   - 复制成功提示“已复制”
4. `PlantUML` 本轮仅支持：
   - 源码高亮
   - 复制
5. `PlantUML` 本轮不支持：
   - 图形渲染
   - SVG / PNG 运行时生成

### 2.2 图片渲染

1. 仅允许渲染“当前文章所属 GitHub 仓库内图片”。
2. Markdown 中相对路径图片必须统一解析到 GitHub raw 地址。
3. 非法来源图片不渲染，默认显示小图标占位，表示加载失败或来源不允许。
4. 暂不支持图片标题 / caption。

### 2.3 图片预览

本轮仅支持单图预览：
- 点击图片弹出单张预览
- 支持 `Esc` 关闭
- 支持点击遮罩关闭
- 支持 `Close` 按钮关闭
- 支持放大 / 缩小

本轮不支持：
- 完整画廊
- 上一张 / 下一张切换
- 缩略图条

### 2.4 标题导航

1. 本轮支持 `heading anchor`。
2. 本轮不实现文章目录（TOC）。

### 2.5 文章交互权限

1. 文章详情阅读页默认允许所有访客进入阅读。
2. `评论` 功能属于登录用户权限，未登录用户不开放。
3. `下载` 功能属于登录用户权限，未登录用户不开放。
4. 权限约束需在独立详情页和后续衍生的文章交互入口上保持一致。
5. 本条为产品权限备忘，后续若调整登录策略，需同步更新本文档。

## 3. 当前实现基线

当前仓库已具备以下能力：
- `markdown-it` 基础 Markdown 渲染
- `shiki` 代码高亮
- `mermaid` 图表渲染
- 文章详情页通过 `v-html` 注入渲染后的 HTML

对应位置：
- `components/articles/ArticleReaderPanel.vue`
- `composables/useMarkdownRenderer.ts`
- `composables/useMermaidRenderer.ts`
- `assets/css/main.css`

## 4. 目标方案

### 4.1 渲染职责划分

1. 后端负责返回：
   - 原始 Markdown
   - `repositoryName`
   - `githubPath`
   - `contentRef`
   - 文章元数据
2. 前端负责：
   - Markdown 转 HTML
   - 代码高亮
   - 图片 URL 安全解析
   - 图片预览交互
   - `heading anchor`

### 4.2 图片 URL 解析规则

输入：
- 当前文章的 `repositoryName`
- 当前文章的 `contentRef`
- 当前文章的 `githubPath`
- Markdown 图片原始路径

规则：
1. 若为相对路径，则基于当前 Markdown 文件所在目录解析。
2. 解析结果统一转换为 GitHub raw URL：
   - `https://raw.githubusercontent.com/{repo}/{ref}/{resolvedPath}`
3. 若为绝对 URL，仅允许属于当前文章仓库的 GitHub raw 资源。
4. 非法协议、第三方域名、跨仓库资源一律拒绝渲染。

### 4.3 代码块输出结构

每个 fenced code block 统一输出结构：
1. Header
   - 语言名
   - `Copy` 按钮
2. Body
   - `shiki` 高亮结果
   - 保留横向滚动

建议结构：

```html
<div class="code-block">
  <div class="code-block-header">
    <span class="code-block-lang">java</span>
    <button type="button" class="code-block-copy">Copy</button>
  </div>
  <div class="code-block-body">
    <!-- shiki html -->
  </div>
</div>
```

### 4.4 heading anchor

标题节点需自动注入稳定锚点：
1. `h1-h6` 生成 slug
2. 标题右侧显示可复制或可跳转的 anchor
3. 点击 anchor 后更新 hash

约束：
1. 不在本轮实现目录树（TOC）
2. anchor 样式需足够轻量，避免干扰阅读

## 5. 重点语言支持

本轮重点保证以下语言具备稳定高亮：
- `plaintext`
- `bash`
- `javascript`
- `typescript`
- `java`
- `json`
- `yaml`
- `xml`
- `html`
- `css`
- `sql`
- `markdown`
- `vue`
- `dockerfile`
- `python`
- `plantuml`
- `puml`

说明：
- `plantuml` / `puml` 只高亮源码，不做图形渲染。

## 6. 安全要求

1. Markdown 渲染继续保持 `html: false`。
2. 图片必须经过“当前仓库内资源”校验后才允许输出。
3. 外链 `a` 标签统一补充安全属性。
4. 渲染失败的图片不得退回直接输出原始不安全 URL。

## 7. 实施顺序

1. 改造 `useMarkdownRenderer.ts`
   - 代码块统一壳层
   - 图片 URL 解析
   - `heading anchor`
2. 改造 `ArticleReaderPanel.vue`
   - 图片预览弹层
   - 代码复制交互
3. 改造 `main.css`
   - 图片样式
   - 代码块 toolbar
   - anchor 样式
4. 补充测试
   - Markdown 渲染单测
   - 图片解析规则单测
   - 复制交互与 heading anchor 用例

## 8. 验收标准

1. 相对路径 GitHub 仓库内图片可正常显示。
2. 非法图片来源不渲染，并显示占位。
3. 点击图片可进入单图预览并支持放大 / 缩小。
4. `PlantUML / JSON / XML / SQL / Java` 代码块高亮正常。
5. 每个代码块均显示语言标签与 `Copy` 按钮。
6. 点击 `Copy` 后出现“已复制”提示。
7. 标题可生成并使用 `heading anchor`。
8. `TOC` 不出现。
