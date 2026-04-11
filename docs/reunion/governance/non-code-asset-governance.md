# Non-Code Asset Governance

## Goal

Keep the repository readable, deployable, and low-noise by giving non-code assets clear ownership and placement.

## Placement Rules

- Config examples go under `config/`
- Product or roadmap material goes under `docs/reunion/product/`
- Architecture and schema design goes under `docs/reunion/design/`
- External API contracts go under `docs/reunion/api/`
- Release summaries go under `docs/reunion/release/`
- Deployment or security runbooks are centralized in `docs/`
- Repository and asset conventions go under `docs/reunion/governance/`
- Backend image deployment script goes under `deploy/scripts/`

## Noise Rules

- Do not commit generated directories such as `target/`
- Do not keep duplicate script entrypoints with real logic in multiple places
- Keep root-level files limited to canonical entrypoints, build manifests, and top-level documentation
