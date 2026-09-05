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
- [`BILLING_WEBHOOK_PROJECTION.md`](./BILLING_WEBHOOK_PROJECTION.md) defines mapping-authenticated,
  stale-safe canonical billing projection, retry/dead-letter behavior and controlled replay.
- [`BILLING_SUBSCRIPTION_LIFECYCLE.md`](./BILLING_SUBSCRIPTION_LIFECYCLE.md) defines canonical transitions,
  request-time access, provider-confirmed plan changes, immutable reservations and durable outbox delivery.
- [`BILLING_RECONCILIATION.md`](./BILLING_RECONCILIATION.md) defines bounded provider comparison, safe repair,
  platform support access, alert metrics, consistency checks and incident recovery.
- [`USAGE_LEDGER.md`](./USAGE_LEDGER.md) defines immutable weighted usage events, explicit metering
  windows, corrections, read models, retention and partitioning policy.
- [`USAGE_QUOTAS.md`](./USAGE_QUOTAS.md) defines atomic quota admission, immutable limit snapshots,
  idempotent reservation finalization/release and stale-hold recovery.
- [`PLAN_USAGE_UI.md`](./PLAN_USAGE_UI.md) defines the catalog-driven pricing, plan comparison, billing-control
  visibility and tenant-safe usage presentation contract.
- [`ACCESS_BOUNDARY.md`](./ACCESS_BOUNDARY.md) defines the stable permission-entitlement-resource-quota
  evaluation order, integration APIs, reservation cleanup and feature-operation key registry.
- [`PROJECTS.md`](./PROJECTS.md) defines stable project identity, tenant/scope linkage, lifecycle,
  active-project capacity, audit/outbox history and bulk placeholder read models.
- [`PROPERTIES.md`](./PROPERTIES.md) defines versioned typed property configuration, tenant/project scope
  linkage, active property limits, lifecycle, verification-reset and grouped read-model semantics.
- [`PROPERTY_ENVIRONMENTS.md`](./PROPERTY_ENVIRONMENTS.md) defines canonical IDNA origin parsing, public-only
  input policy, property environment lifecycle and the concurrent exactly-one-primary invariant.
- [`DOMAIN_VERIFICATION.md`](./DOMAIN_VERIFICATION.md) defines origin-bound proof challenges, safe adapter
  evidence, retry/expiry lifecycle and workload-specific freshness.
- [`DNS_TXT_VERIFICATION.md`](./DNS_TXT_VERIFICATION.md) defines bounded exact-name DNS resolution, byte-exact
  TXT semantics, single-consumption concurrency and periodic ownership rechecks.
- [`HTTP_VERIFICATION.md`](./HTTP_VERIFICATION.md) defines exact file/static-meta proof, centralized public-network
  destination enforcement, explicit canonical redirects and bounded evidence.
- [`SEARCH_CONSOLE_VERIFICATION.md`](./SEARCH_CONSOLE_VERIFICATION.md) defines separate provider consent,
  exact URL-prefix/domain matching, dual authorization and connection-change revalidation.
- [`PROJECT_ONBOARDING.md`](./PROJECT_ONBOARDING.md) defines the persisted guided setup state machine,
  composed permission boundary, atomic/idempotent provisioning, plan preview and factual readiness semantics.
- [`CRAWL_POLICIES.md`](./CRAWL_POLICIES.md) defines exact-origin crawl configuration, global/plan bounds,
  safe path globs, immutable versions and idempotent scan snapshots.
- [`BILLING_PROVIDER_CONTRACT.md`](./BILLING_PROVIDER_CONTRACT.md) defines normalized billing values,
  adapter operations/errors, transport policies, canonical lifecycle and second-provider requirements.
- [`LEMON_SQUEEZY_ADAPTER.md`](./LEMON_SQUEEZY_ADAPTER.md) defines the first production adapter's exact
  endpoints, no-retry mutation policy, mapping validation, lifecycle translation and sanitized fixtures.
- [`../../tracking/README.md`](../../tracking/README.md) defines prompt evidence,
  recovery and state integrity.
