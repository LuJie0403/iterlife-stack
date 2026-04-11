# 文章管理模块系统设计（独立模块）

## 1. 设计目标

### 1.1 业务目标
- 支持后台完整文章生命周期：创建、编辑、审核、发布、下线、回滚。
- 支持多人协作（作者/审核者/发布者）与操作审计。
- 对外阅读接口继续沿用（`/api/articles` 不中断）。

### 1.2 技术目标
- 将“写侧（管理端）”与“读侧（前台查询）”解耦，避免直接在查询表上做复杂编辑流程。
- 所有核心表遵循软删除约定：`deleted_at = 0` 为有效。
- 先做单体内模块化，后续可平滑拆为独立服务。

## 2. 边界与上下文

### 2.1 模块边界
- 本模块仅负责文章管理流程（命令侧）。
- 前台展示继续使用既有查询模型（`article` + `article_tag`）。
- 评论模块、认证模块保持现状，仅通过用户身份与权限点集成。

### 2.2 上下文关系
- 输入：后台用户操作（编辑、审核、发布）。
- 输出：发布投影（将已发布版本写入读侧表），并触发搜索索引更新。
- 外部依赖：`AuthService`（身份认证）、`MeilisearchIndexService`（索引）。

## 3. 架构方案

### 3.1 分层结构
- `controller`: `ArticleAdminController`（仅后台 API）。
- `service`: `ArticleCommandService`、`ArticlePublishService`、`ArticleVersionService`。
- `repository`: 命令侧实体仓储 + 发布投影仓储。
- `policy`: 状态机与权限策略（可单独包管理）。

### 3.2 写读分离（同库双模型）
- 写侧（新）：承载草稿、版本、审核、审计。
- 读侧（沿用）：承载前台检索与展示。
- 发布动作：事务内写 `article_publish_event`，异步消费者做投影并刷新搜索索引（最终一致）。

### 3.3 状态机
- `DRAFT`：草稿态，可编辑。
- `IN_REVIEW`：待审核，不允许直接发布。
- `REJECTED`：审核拒绝，退回编辑。
- `SCHEDULED`：定时发布。
- `PUBLISHED`：已发布。
- `ARCHIVED`：下线归档。

允许的关键迁移：
- `DRAFT -> IN_REVIEW`
- `IN_REVIEW -> REJECTED | SCHEDULED | PUBLISHED`
- `REJECTED -> DRAFT`
- `PUBLISHED -> ARCHIVED`
- `ARCHIVED -> DRAFT`（复制最新版本为新草稿）

## 4. 数据模型（命令侧新增）

### 4.1 `article_post`
- 含义：文章主聚合（长期稳定 ID + 当前状态）。
- 字段建议：
  - `id` (varchar64, pk)
  - `status` (varchar32)
  - `current_version_no` (int)
  - `author_user_id` (varchar64)
  - `reviewer_user_id` (varchar64, nullable)
  - `published_version_no` (int, nullable)
  - `published_at` (datetime, nullable)
  - `deleted_at` (bigint, default 0)
  - `created_at` / `updated_at`

### 4.2 `article_version`
- 含义：文章版本快照，支持回滚。
- 字段建议：
  - `id` (bigint, pk, auto increment)
  - `article_id` (varchar64, idx)
  - `version_no` (int)
  - `title` (varchar255)
  - `summary` (varchar512)
  - `content_markdown` (longtext)
  - `cover_image_url` (varchar255, nullable)
  - `modify_time` (datetime, nullable)
  - `sha256` (varchar64)
  - `deleted_at` (bigint, default 0)
  - `created_by` / `created_at`
- 唯一约束：`uk_article_version(article_id, version_no, deleted_at)`。

### 4.3 `article_version_tag`
- 含义：版本维度标签（发布时投影到 `article_tag`）。
- 字段建议：
  - `id` (bigint, pk)
  - `article_id` (varchar64)
  - `version_no` (int)
  - `tag_name` (varchar64)
  - `deleted_at` (bigint, default 0)
  - `created_at`

### 4.4 `article_publish_event`
- 含义：发布事件 outbox，保证投影可靠执行。
- 字段建议：
  - `id` (bigint, pk)
  - `article_id` (varchar64)
  - `version_no` (int)
  - `event_type` (`PUBLISH`/`ARCHIVE`/`ROLLBACK`)
  - `status` (`NEW`/`PROCESSING`/`DONE`/`FAILED`)
  - `retry_count` (int)
  - `next_retry_at` (datetime, nullable)
  - `error_message` (varchar1024, nullable)
  - `deleted_at` (bigint, default 0)
  - `created_at` / `updated_at`

### 4.5 `article_audit_log`
- 含义：审计链路（满足可追溯）。
- 字段建议：
  - `id` (bigint, pk)
  - `article_id` (varchar64)
  - `action` (`CREATE`/`EDIT`/`SUBMIT_REVIEW`/`APPROVE`/`REJECT`/`PUBLISH`/`ARCHIVE`/`ROLLBACK`)
  - `operator_user_id` (varchar64)
  - `payload_json` (json)
  - `deleted_at` (bigint, default 0)
  - `created_at`

## 5. API 设计（后台）

统一前缀：`/api/admin/articles`

### 5.1 聚合与版本
- `POST /`：新建文章（生成 `article_id`，落 v1 草稿）。
- `GET /{articleId}`：文章聚合详情（含状态、当前版本号）。
- `GET /{articleId}/versions`：版本列表。
- `GET /{articleId}/versions/{versionNo}`：版本详情。
- `PUT /{articleId}/draft`：更新草稿（乐观锁：`If-Match` 或 `version_no`）。

### 5.2 审核与发布
- `POST /{articleId}/submit-review`：提交审核。
- `POST /{articleId}/approve`：审核通过（可附定时发布时间）。
- `POST /{articleId}/reject`：审核拒绝（含原因）。
- `POST /{articleId}/publish-now`：立即发布（仅有发布权限）。
- `POST /{articleId}/archive`：下线归档。
- `POST /{articleId}/rollback`：回滚到指定版本并重新发布。

### 5.3 管理列表
- `GET /`：后台分页查询（状态/作者/关键词/时间区间）。

## 6. 权限模型（最小可用）

权限点：
- `article:create`
- `article:edit`
- `article:submit_review`
- `article:review`
- `article:publish`
- `article:archive`
- `article:rollback`
- `article:read_admin`

推荐角色：
- `AUTHOR`: create/edit/submit_review/read_admin(own)
- `EDITOR`: edit/review/read_admin
- `PUBLISHER`: publish/archive/rollback/read_admin
- `ADMIN`: all

## 7. 关键流程

### 7.1 发布流程
1. 作者编辑草稿并提交审核。
2. 审核通过后触发发布（立即或定时）。
3. 事务内写 `article_post` 状态 + `article_publish_event(NEW)`。
4. 投影任务消费 `article_publish_event`：
   - upsert `article`
   - 重建 `article_tag`
   - 更新 MeiliSearch 索引
5. 成功后事件置 `DONE`；失败重试并记录错误。

### 7.2 回滚流程
1. 指定历史版本号。
2. 创建新版本（内容复制自历史版本，版本号递增）。
3. 触发标准发布流程，避免“直接改历史版本”。

## 8. 与现有系统衔接策略

- 前台接口 (`ArticleController`, `ArticleQueryService`) 保持不变。
- 当前 GitHub Webhook 同步链路可并行保留，作为导入通道：
  - 模式 A：只读迁移期，继续 Git 同步。
  - 模式 B：后台管理为主，Git 同步仅用于历史补录。
- 最终以后台发布事件作为主数据源，Git 同步可降级为可选能力。

## 9. 非功能设计

- 并发控制：草稿更新使用乐观锁，避免覆盖写。
- 一致性：发布使用 outbox + 重试，保证“至少一次”投影。
- 可观测性：记录发布耗时、失败率、重试次数。
- 安全：后台接口要求登录 + 权限校验 + 审计落库。

## 10. 落地里程碑（建议两周节奏）

### M1（基础骨架）
- 建表 + Entity/Mapper/Repository。
- 实现文章创建、草稿编辑、后台列表。

### M2（状态机 + 权限）
- 接入审核状态机与权限点。
- 完成提交审核、通过/驳回流程。

### M3（发布投影）
- 落地 `article_publish_event` 消费器。
- 打通到 `article` / `article_tag` / MeiliSearch。

### M4（稳定性）
- 增加回滚、审计查询、失败重试管理。
- 补充集成测试与压测。

## 11. 首批验收标准

- 能创建草稿并多次编辑，保留版本历史。
- 审核通过后 5 秒内可在前台 `/api/articles/{id}` 查到新内容。
- 发布失败可自动重试并可人工补偿。
- 所有关键动作在审计表可追踪到操作人和时间。
