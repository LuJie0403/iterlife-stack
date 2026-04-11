# IterLife Reunion v1.0.0 Release Notes

## Release Overview
- Version: `v1.0.0`
- Release date: `2026-03-14`
- Scope:
  - Backend: `iterlife-reunion`
  - Frontend: `iterlife-reunion-ui`
- Goal: finalize the first production-grade article publishing, reading, sharing, and personal-homepage baseline for `壹零贰肆老友记 (IterLife)`.

## Delivered Scope

### Article Publishing Baseline
- Completed the end-to-end publishing path from GitHub article repository changes to Reunion article projection.
- Stabilized article identity, FrontMatter parsing, article projection, and article update semantics.
- Clarified the storage model around article creation time, modify time, hash-based content change detection, and GitHub source mapping.
- Hardened the publishing flow with better idempotency and more explicit operational semantics for replay and repeated webhook delivery.

### Article Reading Experience
- Finalized the article list page with paging, summary-first previews, and stable metadata presentation.
- Standardized backend list ordering by `modify_time DESC`, with `publish_time DESC` as the secondary fallback; sidebar latest ordering uses `publish_time DESC`.
- Stabilized the backend article detail contract around `GET /api/articles/{id}`, including Markdown payload and `githubEditUrl`.
- Kept direct article URLs available for external sharing and QR entry.
- Improved Markdown rendering support for tables, code blocks, inline code, and FrontMatter display.

### Profile Sidebar and Homepage Experience
- Finalized the sidebar layout for profile, socials, tags, repositories, applications, and support.
- Made profile data configuration-driven instead of page-hardcoded.
- Added practical filtering and tag navigation patterns for article discovery.
- Normalized repository display names by hiding the `iterlife-` prefix in sidebar presentation.

### Sharing and Support
- Added `Edit on GitHub` and `Share Article` actions in the article reader.
- Completed permanent article links and non-expiring QR sharing.
- Added quick-share support for:
  - `X`
  - `Telegram`
  - `LinkedIn`
  - `Reddit`
  - `Threads`
  - `Discord`
  - `Stack Overflow`
- Finalized the `Support` module with:
  - shared EVM support address
  - full-address copy
  - original support QR image
  - original SafePal invite poster
  - blockscan report link
  - simplified primary card plus detailed secondary dialog

### Governance and Delivery
- Used release branches for the `v1.0.0` stabilization round.
- Cleaned a large set of stale local and remote development branches before the release baseline.
- Kept frontend and backend aligned with the shared CI/CD path:
  - local branch
  - PR
  - merge to `main`
  - GitHub Actions
  - GHCR / deployment workflow

## Validation Summary

### Backend Release PR
- Repository: `iterlife-reunion`
- PR: [#28](https://github.com/LuJie0403/iterlife-reunion/pull/28)
- Title: `chore: finalize v1.0.0 release branch`
- State: `MERGED`
- CI:
  - `backend-check`: `SUCCESS`

### Frontend Release PR
- Repository: `iterlife-reunion-ui`
- PR: [#31](https://github.com/LuJie0403/iterlife-reunion-ui/pull/31)
- Title: `chore: finalize v1.0.0 release branch`
- State: `MERGED`
- CI:
  - `ui-build-check`: `SUCCESS`

## Final Acceptance Result
- `v1.0.0` has passed the current acceptance scope.
- The system now has a stable first official release baseline for:
  - article publishing
  - article reading
  - article sharing
  - personal profile presentation
  - support / donation display
  - release governance

## Recommended Next Focus

### Priority 1
- Improve observability and diagnostics for the article publishing chain.
- Document FrontMatter authoring rules and article author workflow more explicitly.
- Strengthen replay, rename, delete, and exception recovery guidance.

### Priority 2
- Continue polishing the reading experience:
  - table responsiveness
  - code block tooling
  - article navigation
  - related content

### Priority 3
- Plan a dedicated AI enhancement phase for:
  - summary generation
  - tag assistance
  - content quality checks
  - publishing-time automation
