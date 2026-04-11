# Reunion 系统概览

最后更新：2026-04-11

本文档统一描述 Reunion 当前的系统结构、文章发布链路和阅读侧边界。

## 1. 系统范围

Reunion 当前由两个应用组成：

- `iterlife-reunion`：Spring Boot 后端 API
- `iterlife-reunion-ui`：Nuxt 3 前端阅读与交互界面

## 2. 当前架构

### 后端职责

- 文章查询接口
- GitHub 驱动的文章同步与发布投影
- GitHub 登录与评论鉴权
- 评论读写与健康检查
- Meilisearch 集成

### 前端职责

- Markdown 渲染
- 代码高亮与复制交互
- GitHub 仓库内图片解析与预览
- Mermaid 渲染
- 文章详情、评论和分享交互

### 部署方式

- API 服务：`iterlife-reunion-api`
- UI 服务：`iterlife-reunion-ui`
- 标准发布链路：PR -> `main` -> GitHub Actions -> GHCR -> webhook -> compose

## 3. 文章发布链路

当前文章正文真理源仍是 GitHub 仓库 Markdown，数据库保存读模型与索引。

主链路：

1. 作者向文章仓库 push Markdown 变更。
2. GitHub 回调 `POST /api/webhook/github/push`。
3. 后端验签后先落发布事件，再返回 `202 Accepted`。
4. 异步任务解析新增、修改、删除的 Markdown 文件。
5. 删除文件时逻辑删除 `article`，并同步删除 Meili 文档。
6. 新增或修改文件时，必要时先做 FrontMatter 规范化，再 upsert `article`、重建 `article_tag`、同步 Meili。
7. 文章详情读取时，再按 GitHub 元信息回源 Markdown 正文。

当前稳定规则：

- 文章详情路由直接使用业务 `id`
- 列表排序以 `modify_time DESC` 为主
- 浏览筛选统一使用 `Tag`

## 4. 阅读侧规则

当前阅读侧已确认规则：

- 页面渲染阶段保留 Markdown 原始格式，不自动格式化代码
- 每个代码块支持高亮、语言标签、复制按钮和“已复制”反馈
- 仅允许渲染当前文章所属 GitHub 仓库内图片
- 图片预览当前只支持单图预览
- 当前支持 `heading anchor`，不做 TOC
- 评论和下载属于登录用户权限，阅读对访客开放

## 5. 当前接口基线

### 文章接口

- `GET /api/articles`
- `GET /api/articles/filter`
- `GET /api/articles/index/sidebar`
- `GET /api/articles/tag/{tag}`
- `GET /api/articles/search/{keyword}`
- `GET /api/articles/{id}`

### 认证与评论接口

- `GET /api/auth/github/url`
- `POST /api/auth/github/callback`
- `POST /api/auth/email/bind`
- `GET /api/auth/me`
- `POST /api/comment/publish`
- `GET /api/comment/article/{articleId}`

## 6. 当前重点与边界

当前重点：

- 保持文章同步链路稳定
- 继续推进统一身份改造
- 逐步补齐自动化测试和可观测性

当前不在正式文档体系中继续细拆：

- 单独的目录索引型 README
- 独立的阅读渲染子目录文档
- 过细的发布时序图说明文档
- 阶段性、历史性的发布说明和归档草稿
