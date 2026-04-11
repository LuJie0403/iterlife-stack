# 产品需求文档 (PRD) - 壹零贰肆老友记 (iterlife.com)

## 1. 产品概述 (Product Overview)

* **产品名称**：壹零贰肆老友记
* **产品域名**：`iterlife.com` / `www.iterlife.com` / `reunion.iterlife.com`（兼容入口：`1024.iterlife.com`，重定向到 `iterlife.com`）
* **产品定位**：一个面向极客与互联网从业者的技术博客与个人知识库。以“迭代人生(IterLife)”为理念，兼具个人技术沉淀展现与“老友圈子”的轻量级技术探讨功能。
* **核心目标**：提供极致纯净的暗色系极客阅读体验；通过 GitOps 彻底解放博主的创作与发布工作流；构建低维护成本、高访问性能的现代化个人站点。
  
## 2. 用户角色 (User Roles)

1. **超级管理员（博主/Admin）**：仅限 1 人。通过 Git 提交代码的方式发布和管理文章，拥有系统最高权限。
2. **普通访客（Guest）**：无需注册即可浏览所有文章、使用全文检索、查看开源项目看板。
3. **注册用户（User）**：通过 GitHub 授权登录并强制绑定邮箱后，拥有对文章发布评论、回复评论的权限。
   
## 3. 核心功能说明 (Core Features)

### 3.1 C 端前台展示模块 (Frontend Viewer)

* **UI 视觉风格**：全局极简暗色系（Dark Mode）。首页加入极客终端风元素，默认包含打字机动画，输出一段 Java 欢迎代码（`System.out.println("Welcome to Iteration Life!");`）。
* **文章阅读体验**：
  * 支持 Markdown 基础渲染。
  * 支持技术文章所需的代码高亮、图表展示与仓库内图片阅读体验。
  * 前台阅读侧详细渲染方案由 `iterlife-reunion-ui` 仓库维护，不在本仓库设计文档中展开实现细节。
* **全站搜索引擎**：基于错别字容错算法，提供毫秒级、带关键字高亮的全局标题与全文检索功能。
* **开源项目大盘 (`/projects`)**：展示博主在 GitHub 上的 Star/Pinned 项目列表（按 Star 排序，精选 5~7 条），并在页脚或侧边栏提供不超过 5 个个人社交媒体 Logo 链接。
  

### 3.2 互动与社交模块 (Interaction & Social)

* **第三方快捷登录**：MVP 支持 GitHub OAuth2.0 快捷授权登录，首次登录强制进入邮箱绑定流程；后续演进支持 Google、微信扫码、支付宝扫码等方式。全站账号以邮箱为唯一底层标识。
* **两级评论系统**：
  * 文章底部提供评论区，采用“两级平铺结构”。
  * 主评论按时间倒序排列；所有子回复均平铺挂载在主评论下方，并通过 `@用户昵称` 的方式指明回复对象。
  * 评论区支持纯文本及 Emoji。
    

### 3.3 内容创作与管理模块 (GitOps CMS)

* **抛弃传统富文本/在线 Markdown 编辑**，全面采用“本地编写 + Git 提交”的工作流。
* **YAML 元数据驱动**：博主在本地 Markdown 文件头部编写 YAML（包含固定的 `id`, `title`, `tags`, `publish_date`, `last_modify_date`, `summary`, `sha256` 等），系统统一以 `tags` 作为文章索引与展示语义；其中 `publish_date` 语义映射为数据库 `publish_time`，`last_modify_date` 语义映射为数据库 `modify_time`。FrontMatter 统一采用单行 `key: value` 两列式写法，`tags` 也按单行值维护。
* **配图管理**：文章配图优先与 Markdown 一同维护在 GitHub 仓库内；前台仅渲染当前文章所属仓库内图片，并将相对路径统一解析到 GitHub raw 地址。
* **逻辑删除/隐藏**：当博主在 GitHub 删除某个 MD 文件时，博客前台将其隐藏，但数据库保留关联的评论数据（逻辑删除状态）。


## 4. 功能裁剪与演进计划 (Phased Plan)

* **MVP 阶段（一期核心）**：跑通 GitHub Webhook 自动同步文章、前台 SSR 渲染展示、集成 Meilisearch 搜索、GitHub 登录与基础两级评论。
* **暂缓/剥离的功能（降低初期复杂度）**：
  * 无限嵌套层级评论（已被两级结构替代）。
  * 复杂的 SMTP 邮件提醒与 RSS 订阅生成。
  * 数据库定时备份脚本。
  * 前端可交互式 Shell 控制台。
