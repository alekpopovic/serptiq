# Architecture Decision Records

ADRs record durable architecture choices. `Accepted` decisions govern implementation until a later ADR explicitly supersedes them.

| ADR | Status | Decision |
|---|---|---|
| [0001](./0001_modular_rails_monolith.md) | Accepted | Start with a modular Rails monolith |
| [0002](./0002_postgresql_and_solid_stack.md) | Accepted | PostgreSQL and the Rails Solid stack |
| [0003](./0003_native_social_authentication.md) | Accepted | Application-owned social authentication |
| [0004](./0004_separate_rbac_entitlements_and_quotas.md) | Accepted | Separate RBAC, entitlements and quotas |
| [0005](./0005_object_storage_for_large_artifacts.md) | Accepted | Store large scan artifacts in object storage |
| [0006](./0006_ssrf_safe_crawler_boundary.md) | Accepted | Treat the crawler as an SSRF security boundary |
| [0007](./0007_isolated_browser_workers.md) | Accepted | Isolate JavaScript rendering from web processes |
| [0008](./0008_provider_neutral_billing.md) | Accepted | Provider-neutral billing with Lemon Squeezy first |
| [0009](./0009_versioned_rule_engine_and_evidence.md) | Accepted | Version SEO rules and persist evidence |
| [0010](./0010_docker_and_kamal_deployment.md) | Accepted | Docker and Kamal for initial production deployment |

## Lifecycle

- `Proposed`: under review and not yet binding.
- `Accepted`: current implementation decision.
- `Superseded`: replaced by a named later ADR; retained for history.
- `Rejected`: considered but not adopted.
- `Deprecated`: still present for compatibility but scheduled for removal.

Update an accepted ADR only to correct factual errors or add implementation notes. Change the decision through a new ADR that names the superseded record.

Use [`ADR_TEMPLATE.md`](./ADR_TEMPLATE.md) for new decisions.
