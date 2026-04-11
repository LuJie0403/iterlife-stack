# 系统概要设计文档 (SDR) - 壹零贰肆老友记 (iterlife.com)

最后更新：2026-03-27  
适用范围：`iterlife-reunion` 后端当前实现基线 + 已确认的后续演进方向

## 1. 架构总体设计 (Architecture Overview)

本仓库当前承担 `iterlife-reunion` 后端 API，采用 Spring Boot 单体服务 + GitHub 驱动的文章发布链路。前端 SSR 与页面体验由 `iterlife-reunion-ui` 仓库单独维护，本仓库只提供文章查询、认证、评论、Webhook 同步和健康检查能力。

说明：
* 阅读侧 Markdown 渲染、代码高亮、图片预览、`heading anchor` 等页面体验能力属于 `iterlife-reunion-ui` 仓库设计范围。
* 后端仓库仅负责输出文章元数据、Markdown 正文、GitHub 编辑链接等阅读原材料，不负责正文图片代理、图片预览交互或运行时代码格式化。
* 阅读侧详细方案见 `../../reunion-ui/design/article-reader-rendering.md`。

### 1.1 当前技术栈 (Current Tech Stack)

* **后端 (Backend)**：Java 17/21 + Spring Boot 3.x 单体架构。
* **持久层 (Database)**：MySQL + MyBatis-Plus。
* **文章源 (Content Source)**：GitHub 仓库 Markdown + FrontMatter。
* **搜索引擎 (Search Engine)**：Meilisearch，可通过配置开关启用。
* **外部集成**：GitHub Webhook、GitHub Contents API、GitHub OAuth。

说明：
* 当前仓库代码中没有 Redis 限流实现。
* 当前仓库部署资产只覆盖 API 与 Meili，不再维护统一 webhook/systemd 编排。

### 1.2 基础设施与部署 (DevOps)

* **服务器**：阿里云 ECS。
* **容器化**：`deploy/compose/reunion-api.yml` 编排 `iterlife-reunion-api` 与 `iterlife-reunion-meili`。
* **持续集成 / 发布**：本地开发 -> PR -> 合并 `main` -> GitHub Actions 构建 GHCR 镜像 -> 统一 webhook 回调 -> `iterlife-reunion-stack` 控制面按 `iterlife-reunion-api` 执行 `docker compose up -d --no-build`。
* **统一路由与 webhook**：由 `iterlife-reunion-stack` 仓库维护。
* **网关与证书**：Nginx + HTTPS 证书，运行时配置外置于 `/apps/config/...`。

## 2. 核心架构设计 (Core Domain Design)

### 2.1 GitOps 文章发布链路 (Current)

数据库中不存文章正文，GitHub Markdown 是正文真理源；数据库保存查询索引、身份映射、评论和用户数据。

当前文章发布主链路：
1. 作者向文章仓库 push Markdown 变更。
2. GitHub 调用 `POST /api/webhook/github/push`。
3. 后端使用 `X-Hub-Signature-256` 做 HMAC 验签，通过后先写入 `article_publish_event`，再返回包含 `deliveryId` 和 `eventId` 的 `202 Accepted`。
4. `ArticlePublishEventService` 使用独立线程池分发事件，并通过定时扫描恢复卡住的 in-flight 事件。
5. `ArticleSyncService` 基于持久化事件收集 changed/removed Markdown 路径；当 commit 文件列表为空时，回退到 compare API 获取变更文件。
6. 删除路径按 `repository_name + github_path` 逻辑删除 `article`，并同步删除 Meili 文档。
7. 新增/修改路径会先经过 `ArticleFrontmatterService`：
   * 若 FrontMatter 缺少 `id`/`title` 或需要刷新 `publish_date` / `last_modify_date` / `sha256`，则优先规范化并尝试 bot 回写。
   * 已规范化的 bot replay 事件会被识别并跳过二次补写，直接进入投影。
8. 最终由 `FrontMatterParserService` 解析出标准化 `ArticleMeta`，并由 `ArticleRepository` upsert `article` + 重建 `article_tag`，随后同步 Meili。
9. 文章详情查询时，再按 `repository_name + github_path + content_ref` 回源 GitHub 获取 Markdown 正文。

### 2.2 读模型与身份语义

当前读模型语义已经固定为：
* 文章详情路由：`GET /api/articles/{id}`，直接使用业务 `id`
* 浏览筛选：统一只使用 `Tag`
* 列表排序：`modify_time DESC`，再以 `publish_time DESC` 兜底
* 侧边栏最新文章：按 `publish_time DESC`

补充的阅读侧前后端协作约束：
* 文章详情接口继续返回原始 Markdown 正文，由前端负责渲染为 HTML。
* 阅读增强能力由前端仓库单独设计与实现，后端侧只保留接口与数据边界约束。

### 2.3 安全与访问控制

当前已实现：
* **CORS**：`CorsConfig` 读取 `iterlife.cors-origins`，对 `/api/**` 放行配置中的 origin；默认值包含本地开发域名以及 `iterlife.com`、`www.iterlife.com`、`reunion.iterlife.com`、`1024.iterlife.com` 兼容入口。
* **Webhook 验签**：GitHub Push 事件必须通过签名校验。
* **登录认证**：GitHub OAuth + 邮箱绑定 + JWT Access Token。
* **评论权限**：评论发布要求登录用户，评论读取对访客开放。

当前尚未实现：
* Redis / AOP 形式的接口限流
* 统一 AuthN/AuthZ 新表模型
* 发布事件查询 / 手工重试 / 回放 / 重建索引等后台运维 API

## 3. 当前数据库核心模型 (Database Schema)

### 3.1 已落地表

内容与发布链路当前主要依赖以下表：
1. `article`：文章元数据与 GitHub 映射（不存正文）
2. `article_tag`：文章标签映射表
3. `article_comment`：两级评论表
4. `sys_user`：当前 GitHub OAuth 用户表，使用 `uid` 作为业务用户标识
5. `article_frontmatter`：FrontMatter 规范化幂等与 bot replay 防循环记录

字段语义基线：
* `article.id`：内部自增主键，仅数据库内部使用
* `article.article_id`：文章业务 ID，对外路由与评论关联都使用它
* `sys_user.id`：内部自增主键
* `sys_user.uid`：用户业务 ID，对外鉴权与评论作者关联使用它

### 3.2 已确认但尚未落地的演进方向

统一身份和权限模型仍保留为后续设计方向，不是当前实现事实：
* `app_user`
* `authenticate_identity`
* `user_session`
* `authorize_role`
* `authorize_permission`
* `user_role`
* `authorize_role_permission`

详细设计见：
`unified-idaas.md`

## 4. 当前接口基线 (API Baseline)

### 4.1 文章接口

* `GET /api/articles`
* `GET /api/articles/filter?keyword=&tags=&page=&size=`
* `GET /api/articles/index/sidebar`
* `GET /api/articles/tag/{tag}`
* `GET /api/articles/search/{keyword}`
* `GET /api/articles/{id}`

说明：
* 详情接口返回 Markdown 正文与 `githubEditUrl`
* 多标签筛选当前走 query 参数 `tags=a,b`

### 4.2 认证与评论接口

* `GET /api/auth/github/url`
* `POST /api/auth/github/callback`
* `POST /api/auth/email/bind`
* `GET /api/auth/me`
* `POST /api/comment/publish`
* `GET /api/comment/article/{articleId}`

### 4.3 Webhook 接口

* `POST /api/webhook/github/push`
* 行为：验签后先落 `article_publish_event`，再异步处理，并返回包含 `deliveryId` 与 `eventId` 的 `202 Accepted`

## 5. 日志与可观测性 (Observability)

当前已实现：
* 健康检查：`/health` 和 `/api/health`
* 发布链路结构化日志：包含 `repo`、`ref`、`after`、`deliveryId`、changed/removed 统计、删除/投影结果、FrontMatter 规范化状态
* Meili 和 GitHub 集成失败会输出明确 warn/error 日志

当前未实现：
* 指标采集与告警
* 持久化的发布事件视图
* Dozzle 等日志面板集成资产

## 6. 文档边界说明

本文档只描述当前后端事实基线与已确认的后续方向。

* 前端 UI 视觉、阅读器形态、侧边栏配置等以 `iterlife-reunion-ui` 为准。
* 身份模型重构仍属于设计态，不应被误读为已在本仓库代码中落地。
* 统一 webhook/systemd/多应用部署编排以 `iterlife-reunion-stack` 仓库文档为准。
