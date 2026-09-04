# Implementation Evidence

Prompts create factual implementation reports in this directory when a document is larger than the structured tracker result.

Expected early files:

- `000_BASELINE.md`
- `MODULE_BOUNDARIES.md`

Expected final file:

- `PRODUCTION_MVP_ACCEPTANCE.md`

Do not pre-populate these reports with fictional implementation or test results.

## Architecture governance

- [`../adr/README.md`](../adr/README.md) indexes accepted decisions, owners,
  review dates and implementation status.
- [`../adr/ADR_TEMPLATE.md`](../adr/ADR_TEMPLATE.md) is the required starting
  structure for a new durable decision.
- [`MODULE_BOUNDARIES.md`](./MODULE_BOUNDARIES.md) defines enforceable module
  ownership and dependencies.
- [`CONFIGURATION.md`](./CONFIGURATION.md) defines public/secret configuration,
  redaction and key rotation.
- [`DATABASES.md`](./DATABASES.md) defines PostgreSQL topology, capacity,
  identifiers, setup and readiness behavior.
- [`SOLID_STACK.md`](./SOLID_STACK.md) defines queue isolation, retries,
  recurring ownership, disposable cache/cable bounds and worker operations.
- [`FRONTEND.md`](./FRONTEND.md) defines server-rendered UI, accessibility,
  reusable component, Hotwire and future charting conventions.
- [`QUALITY.md`](./QUALITY.md) defines local lint/security gates and the
  time-bounded advisory waiver process.
- [`TESTING.md`](./TESTING.md) defines suite tiers, deterministic support,
  tenant/provider boundaries and failure artifacts.
- [`CI.md`](./CI.md) defines the merge gate, immutable dependency pins,
  branch-protection settings and local job equivalents.
- [`CONTAINERS.md`](./CONTAINERS.md) defines the Ruby 4.0.5 Docker images,
  local Compose lifecycle, database isolation and container verification.
- [`OBSERVABILITY.md`](./OBSERVABILITY.md) defines public error codes,
  structured event fields, correlation lifecycle and prohibited log data.
- [`HEALTH_ENDPOINTS.md`](./HEALTH_ENDPOINTS.md) defines public liveness,
  readiness and release semantics plus private worker heartbeat inspection.
- [`AUTHENTICATION_SESSIONS.md`](./AUTHENTICATION_SESSIONS.md) defines native
  session tokens, cookies, request context, rotation and logout behavior.
- [`IDENTITY_DATA_MODEL.md`](./IDENTITY_DATA_MODEL.md) defines stable provider
  subjects, collision policy, protected OAuth transactions and anonymization.
- [`IDENTITY_PROVIDER_ADAPTERS.md`](./IDENTITY_PROVIDER_ADAPTERS.md) defines the
  Google OIDC/GitHub OAuth adapter contract, exact endpoints, bounded HTTP
  behavior, deterministic fakes and provider addition checklist.
- [`AUTHENTICATION_SECURITY.md`](./AUTHENTICATION_SECURITY.md) defines atomic
  authentication rate limits, privacy-safe keys, bounded failure metrics and
  the dedicated protocol/session regression command.
- [`TENANCY_FOUNDATION.md`](./TENANCY_FOUNDATION.md) defines organization,
  ownership and membership invariants plus verified request/job context.
- [`ORGANIZATION_FLOWS.md`](./ORGANIZATION_FLOWS.md) defines accessible
  organization creation, switching, settings and controlled slug redirects.
- [`MEMBERSHIP_LIFECYCLE.md`](./MEMBERSHIP_LIFECYCLE.md) defines durable member
  states, last-owner protection, immediate session invalidation and safe attribution.
- [`TEAMS.md`](./TEAMS.md) defines organization-consistent team membership,
  archive semantics and the future authorization-principal resolver contract.
- [`PLAN_CATALOG.md`](./PLAN_CATALOG.md) defines governed catalog synchronization,
  publication scheduling, checkout selection, grandfathering and deletion safety.
- [`ENTITLEMENTS.md`](./ENTITLEMENTS.md) defines strict entitlement types, safe defaults,
  subscription/override precedence, request caching and tenant-safe diagnostics.
- [`USAGE_LEDGER.md`](./USAGE_LEDGER.md) defines immutable weighted usage events, explicit metering
  windows, corrections, read models, retention and partitioning policy.
- [`USAGE_QUOTAS.md`](./USAGE_QUOTAS.md) defines atomic quota admission, immutable limit snapshots,
  idempotent reservation finalization/release and stale-hold recovery.
- [`../../tracking/README.md`](../../tracking/README.md) defines prompt evidence,
  recovery and state integrity.
