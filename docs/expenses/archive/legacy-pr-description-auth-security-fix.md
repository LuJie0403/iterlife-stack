# Legacy PR Description: Refactor Auth Config (Security Fix)

这是一份历史 PR 描述归档，不作为当前仓库规范或 CI/CD 基线。

## Changes
- **Hardcoded Secrets Removed**: All database credentials (password, host, user) removed from source code.
- **Config Module**: Introduced `backend/config.py` to load settings from environment variables.
- **Env Template**: Added `backend/.env.example` as a template for local development.
- **Git Safety**: Added `.env` to `.gitignore` (verified).

## Instructions for Merge
1. Review the changes in this PR.
2. Ensure production server has `.env` file created based on `.env.example`.
3. Merge into `master`.
