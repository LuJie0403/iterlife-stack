# 仓库目录治理方案

最后更新：2026-03-26

本文档定义 `iterlife-reunion-stack` 的当前目录结构、目录职责和持续治理规则。目标是让仓库长期保持“目录少而稳、职责清晰、文档单源、运行时配置外置”。

## 1. 仓库定位

当前仓库同时承担两类职责：

- IterLife 统一 CI/CD 控制面。
- 跨前端共享前端包的发布源仓库。

因此，本仓库只保留“控制面资产”和“共享包资产”，不承载业务应用源码，也不承载业务仓库内部的部署文档。

## 2. 当前顶层目录

当前稳定目录结构如下：

```text
.
├── .github/workflows/
├── config/
├── docs/
├── packages/
│   ├── themes/
│   │   └── dark-universe/
│   └── vue/
│       └── copy-action/
├── scripts/
├── systemd/
└── webhook/
```

补充说明：

- `.codex/` 是协作工具元数据，不属于业务结构主干。
- `.idea/` 属于本地 IDE 目录，未纳入仓库治理主干。

## 3. 目录职责

| 目录 | 当前职责 | 准入规则 |
| --- | --- | --- |
| `.github/workflows/` | 统一发布和共享包发布的 GitHub Actions 工作流 | 只放仓库级自动化；业务仓库专属 workflow 不进入本仓库 |
| `config/` | 部署目标注册表等静态配置 | 只放可入库、可审计、非私密配置 |
| `docs/` | 当前有效的治理、运维和共享包说明 | 只放长期有效文档，不放临时排查记录 |
| `packages/` | 可复用前端共享包 | 采用 `packages/<domain>/<package>` 结构收纳 |
| `scripts/` | 被 webhook 或运维流程调用的通用脚本 | 只放通用脚本，不放某个业务仓库私有部署脚本 |
| `systemd/` | 控制面服务的 unit 和 drop-in | 只保留 webhook 运行所需资产 |
| `webhook/` | webhook 服务源码与示例环境文件 | 真实运行时配置保持外置，不入库 |

## 4. 当前收敛结果

当前仓库已经按以下规则收敛：

- 控制面配置集中在 `config/`、`scripts/`、`systemd/`、`webhook/`。
- 共享前端资产集中在 `packages/themes/dark-universe/` 与 `packages/vue/copy-action/`。
- 文档集中在 `/docs`，并按“治理 / 运维 / 共享包 / secrets”四类划分。
- `pnpm-workspace.yaml` 与实际包目录保持一致，覆盖两级包路径。

## 5. 顶层目录治理规则

### 5.1 目录准入

- 新增顶层目录前，必须先回答“是否已经能归入现有目录”。
- 只有在现有目录无法表达职责边界时，才允许新增顶层目录。
- 新增目录必须在本文件中补充职责说明。

### 5.2 运行时与源码分离

- 真实 secret、真实 env、真实日志、容器数据和服务器状态不进入仓库。
- 运行时配置模板只保留在 `webhook/*.example` 一类示例文件中。
- 服务器上的真实路径只作为文档说明，不作为仓库内容保存。

### 5.3 脚本与配置分离

- 路由、目标服务、部署矩阵这类静态事实放在 `config/`。
- 执行动作放在 `scripts/`。
- 任何脚本如果依赖长内联 JSON 或重复的 shell 常量，应优先回收到 `config/`。

### 5.4 共享包治理

- 共享包统一放在 `packages/<domain>/<package>`。
- 共享包 README 负责包自身说明；跨仓库治理规则统一写入 `/docs`。
- 构建产物仅保留对发布必需的内容，不把业务应用产物带入本仓库。

## 6. `/docs` 治理规则

### 6.1 文档边界

- `repository-directory-governance.md` 负责目录结构与治理规则。
- `unified-deployment-and-operations.md` 负责部署与运维事实。
- `dark-universe-theme-package.md` 负责共享主题包事实。
- `vue-copy-action-package.md` 负责共享复制按钮包事实。
- `github-actions-secrets-inventory.md` 负责 secrets 事实。

### 6.2 文档写作规则

- 文件名使用英文，正文优先中文。
- 文档写“当前如何工作”，不写已经结束的迁移过程。
- 同一条事实只在一个主文档里完整描述，其它地方只保留链接。
- 文档标题避免使用 `manual`、`blueprint`、`reference` 之外的混合命名；当前已统一为短英文文件名。

### 6.3 文档更新触发器

- 调整目录边界或新增目录时，更新本文件。
- 调整部署流程、服务矩阵、运维命令时，更新 `unified-deployment-and-operations.md`。
- 调整共享主题包目录、发布方式、消费方式时，更新 `dark-universe-theme-package.md`。
- 调整共享复制按钮包目录、发布方式、消费方式时，更新 `vue-copy-action-package.md`。
- 调整 workflow secrets 时，更新 `github-actions-secrets-inventory.md`。

## 7. 持续治理计划

### 7.1 立即执行规则

- 顶层目录继续保持收敛，不再引入新的“临时说明目录”。
- 业务部署差异继续回收到控制面文档，不在本仓库以外复制部署手册。
- 新增共享包继续沿用 `packages/<domain>/<package>`，不回退到平铺式目录。

### 7.2 评审检查项

每次涉及目录结构的变更，至少检查：

- 是否新增了不必要的顶层目录。
- 是否把静态事实错误写进了脚本而不是 `config/`。
- 是否把运行时私密信息带进了仓库。
- 是否在 `/docs` 中新增了重复主题文档。
- 是否同步更新了文档索引和对应事实源文档。
