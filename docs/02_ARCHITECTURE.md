# Architecture

## 1. Architectural style

SearchOps starts as a **modular Rails monolith**. The application has one source repository, one domain model, one release train, and one deployable image. Different runtime roles may be scaled and isolated independently:

```text
┌─────────────────────────────── Internet ───────────────────────────────┐
│                                                                        │
│  Browser / API clients / Webhooks / OAuth providers / CI systems       │
│                              │                                         │
└──────────────────────────────┼─────────────────────────────────────────┘
                               ▼
                    ┌──────────────────────┐
                    │ Reverse proxy / TLS  │
                    └──────────┬───────────┘
                               ▼
                    ┌──────────────────────┐
                    │ Rails web processes  │
                    │ Hotwire + JSON API   │
                    └──────┬───────┬───────┘
                           │       │
                    enqueue│       │signed URLs
                           ▼       ▼
                 ┌───────────────────┐     ┌──────────────────────────┐
                 │ PostgreSQL        │     │ S3-compatible storage    │
                 │ app/queue/cache/  │     │ HTML/DOM/screenshots/    │
                 │ cable schemas     │     │ Lighthouse/report files │
                 └────────┬──────────┘     └──────────────────────────┘
                          │
        ┌─────────────────┼──────────────────────────────────────┐
        ▼                 ▼                 ▼                    ▼
┌──────────────┐  ┌───────────────┐ ┌──────────────┐  ┌────────────────┐
│ default jobs │  │ crawl workers │ │ render       │  │ report /       │
│ mail/events  │  │ HTTP + parse  │ │ Chromium     │  │ integration    │
└──────────────┘  └───────────────┘ └──────────────┘  └────────────────┘
                          ▲
                          │
                 ┌────────┴────────┐
                 │ scheduler role  │
                 └─────────────────┘
```

A runtime role is not a microservice. It uses the same code and domain contracts.

## 2. Baseline technology decisions

| Concern | Decision |
|---|---|
| Language | Ruby 4.0.5 baseline |
| Framework | Rails 8.1.3.1 baseline |
| Database | PostgreSQL |
| Web UI | ERB, Hotwire, Turbo, Stimulus, Tailwind CSS |
| Jobs | Active Job with Solid Queue |
| Cache | Solid Cache |
| WebSocket | Solid Cable |
| Tests | Minitest and Rails system tests |
| Static HTTP | `Net::HTTP` or a small application-owned adapter with explicit safety controls |
| HTML/XML parsing | Nokogiri |
| Rendering | Chromium controlled by Ferrum in dedicated workers |
| Lab performance | Lighthouse CLI in dedicated jobs |
| Artifacts | S3-compatible object storage through Active Storage or an application adapter |
| Deployment | Docker and Kamal |
| Billing | Provider interface; Lemon Squeezy first |
| Authentication | Application-owned sessions; Google OIDC and GitHub OAuth provider adapters |
| Secrets | Rails credentials/environment secret manager; Active Record Encryption for stored provider credentials |
| Observability | Structured Rails events/logs, metrics exporter, error reporter adapter |

Patch versions are verified in Prompt 001 before they are pinned.

## 3. Bounded modules

The folder layout should make ownership visible without prematurely splitting deployables.

```text
app/
  controllers/
    identity/
    organizations/
    projects/
    scans/
    findings/
    issues/
    billing/
    integrations/
    reports/
    admin/
  models/
  jobs/
    crawling/
    rendering/
    analysis/
    billing/
    integrations/
    reporting/
  domains/
    identity/
    tenancy/
    authorization/
    plans/
    entitlements/
    usage/
    billing/
    projects/
    properties/
    verification/
    crawling/
    analysis/
    findings/
    issues/
    search_data/
    app_discovery/
    releases/
    reporting/
    notifications/
    auditing/
    integrations/
    administration/
  policies/
  components/
```

Recommended responsibilities:

| Module | Owns |
|---|---|
| Identity | Users, external identities, sessions, OAuth/OIDC transactions |
| Tenancy | Organizations, memberships, invitations, teams |
| Authorization | Permission registry, roles, assignments, access decisions |
| Plans | Plans and immutable plan versions |
| Entitlements | Typed feature values and overrides |
| Usage | Usage events, windows, reservations, finalization |
| Billing | Provider adapters, customers, subscriptions, webhook projections |
| Projects | Projects and project settings |
| Properties | Project properties, property environments and ownership-verification summary state |
| Verification | Domain ownership challenges and evidence |
| Crawling | Scans, frontier, URL fetching, robots, sitemaps, links, artifacts |
| Analysis | Rule registry, rule versions, execution, evidence schemas |
| Findings | Finding identity, occurrences, prioritization, trends |
| Issues | Workflow, assignments, comments, suppressions, verification |
| SearchData | Search Console, URL Inspection, CrUX, Lighthouse data |
| AppDiscovery | Android/iOS association and store-listing audits |
| Releases | Releases, baselines, comparisons, gates, status publishers |
| Reporting | Immutable report snapshots and deliveries |
| Notifications | Notification policies, endpoints, deliveries |
| Auditing | Append-only audit events and security-relevant activity |
| Integrations | External connections, encrypted credentials and provider imports |
| Administration | Privileged cross-domain operational workflows |

## 4. Dependency rules

Allowed high-level direction:

```text
Identity ───────────────┐
Tenancy ────────────────┼──► Authorization
Plans ──────────────────┼──► Entitlements ─► Usage
Billing ────────────────┘

Projects ─► Verification
Projects ─► Crawling ─► Analysis ─► Findings ─► Issues
Projects ─► SearchData ────────────────────────► Findings
Projects ─► AppDiscovery ──────────────────────► Findings
Projects ─► Releases ─► Crawling/Analysis ─────► Findings

Reporting and Notifications consume documented read models/events.
Auditing consumes security and domain events, never owns business decisions.
```

Rules:

- A lower-level module does not call a UI controller.
- External provider payloads are translated at the adapter boundary.
- Cross-module state changes use an explicit domain operation or documented event, not an incidental callback.
- A job references an application service and explicit IDs; business logic is not hidden in the job class.
- A view may ask an authorization presenter for capabilities but cannot be the only enforcement point.
- Database joins across modules are allowed when deliberate and documented; circular orchestration is not.

## 5. Request context and tenancy

`Current` contains only request-scoped values:

```ruby
class Current < ActiveSupport::CurrentAttributes
  attribute :user, :session, :organization, :membership, :request_id
end
```

Organization establishment algorithm:

1. authenticate the session;
2. resolve the requested organization from an opaque ID or canonical slug;
3. query an active membership for `Current.user`;
4. reject suspended/deleted organizations and inactive memberships;
5. assign `Current.organization` and `Current.membership`;
6. authorize the requested action and scope.

Never derive access from a user-controlled `organization_id` alone. Background jobs receive explicit organization and resource IDs, load through tenant-aware queries, and validate that relationships still hold.

### Tenant query pattern

Prefer explicit repositories/scopes:

```ruby
Projects::VisibleTo.new(
  membership: Current.membership,
  relation: Project.all
).call
```

Avoid:

```ruby
default_scope { where(organization_id: Current.organization.id) }
```

Database-level safeguards include foreign keys, composite unique indexes, immutable organization ownership for high-risk rows, and tests that intentionally mix IDs from different organizations.

## 6. Identity and session architecture

### Data model

```text
User
├── Identity(provider, provider_subject, verified_email, profile)
└── Session(token_digest, expires_at, revoked_at, metadata)

OauthTransaction
(provider, state_digest, nonce_digest, pkce_verifier_encrypted, return_to, expires_at)
```

### Flow

```text
Start login
→ create one-time OAuth transaction
→ generate state + nonce + PKCE verifier/challenge where supported
→ redirect to provider
→ validate callback state
→ exchange code at provider token endpoint
→ validate OIDC ID token or fetch provider identity
→ enforce issuer/audience/signature/expiry/email policy
→ resolve or link Identity
→ rotate local session
→ delete/consume OAuth transaction
```

The application does not become an OAuth authorization server, so Doorkeeper is unnecessary. It does not use OmniAuth middleware; provider adapters expose explicit application-owned interfaces. Provider libraries may be used for standards-compliant primitives, but the domain owns transaction state, validation policy, and account linking.

## 7. Authorization architecture

An access decision is explicit:

```ruby
Authorization::Decision.call(
  actor: Current.membership,
  permission: "scans.run",
  scope: project
)
```

Role assignment scopes:

- organization;
- project;
- property as a narrower project-safe scope.

A team can receive a role assignment. A direct member assignment can supplement team assignments. Deny overrides are not exposed in the MVP; emergency feature denial belongs to entitlements, not RBAC.

Until the Project and Property aggregates are introduced, Authorization owns a minimal scope-reference
projection containing only opaque identifiers, tenant linkage, parent-project linkage and active/archive
state. The owning aggregates register changes through `Authorization::Public`; the projection is not a
second source of business metadata.

Permission registry keys are stable. Renaming a display label does not change the key.

## 8. Entitlement and usage architecture

### Entitlement precedence

```text
emergency deny
→ organization override
→ active subscription plan version
→ trial/default plan version
→ definition safe default
```

The resolver returns a value and provenance:

```json
{
  "key": "crawl.javascript_rendering",
  "type": "boolean",
  "value": true,
  "source": "plan_version",
  "source_id": "..."
}
```

### Usage lifecycle

Long work uses reservation semantics:

```text
estimate
→ atomically reserve
→ enqueue
→ allocate exact snapshotted operation weight before work
→ consume accepted/completed work into granular immutable usage events
→ release failed or abandoned operation allocations
→ finalize already-consumed actual amount
→ release unused amount
```

If work never starts or reaches a terminal infrastructure failure, reservation recovery releases eligible credits.
The ledger and remaining hold share one PostgreSQL pool lock; operation allocations divide the hold without
double-counting it. Idempotent scan/attempt keys prevent duplicate charging.

The check for a scan is:

```text
permission(scans.run)
AND entitlement(crawl.manual)
AND verified target when required
AND scan concurrency available
AND quota reservation succeeds
```

## 9. Billing architecture

Domain interface:

```ruby
Billing::Provider
  # create_checkout(...)
  # customer_portal_url(...)
  # fetch_subscription(...)
  # change_subscription(...)
  # cancel_subscription(...)
  # resume_subscription(...)
  # verify_webhook(...)
  # parse_event(...)
```

Provider events are never applied synchronously in the controller.

```text
HTTP webhook
→ read exact raw body
→ validate size/content type/signature
→ insert immutable BillingWebhookEvent with provider event fingerprint
→ return success for accepted duplicate/new event
→ enqueue projector
→ map provider event to canonical event
→ apply locked subscription transition
→ emit audit/domain events
→ reconciliation later confirms state
```

Provider status is mapped to a canonical local status. Local access behavior is a separate policy, enabling grace periods and read-only behavior without rewriting provider data.

## 10. Crawl architecture

### Scan state

```text
draft
→ reserving
→ queued
→ discovering
→ crawling
→ rendering
→ analyzing
→ finalizing
→ completed

terminal alternatives:
canceled
failed
quota_exhausted
expired
```

### Frontier state

```text
pending → leased → succeeded
   ▲         ├── retry/pending
   │         ├── rejected
   │         ├── failed
   └─────────└── exhausted
```

Rows are leased in fair organization/host/scan rounds with PostgreSQL `FOR UPDATE SKIP LOCKED`, a bounded expiry,
a worker identity and a one-lease opaque token whose digest is persisted. A worker crash does not permanently own a
URL. Parsing and analysis are downstream records rather than ambiguous frontier ownership states.

### URL pipeline

```text
seed
→ parse
→ normalize
→ validate scheme
→ resolve host
→ reject unsafe address
→ check project origin/policy
→ check robots and budget
→ fetch
→ validate every redirect
→ classify response
→ store metadata/artifact
→ extract links
→ enqueue new allowed URLs
```

### Network policy

The destination validator rejects:

- loopback;
- private address space;
- link-local;
- carrier-grade NAT where policy requires;
- multicast;
- unspecified;
- documentation/test/reserved ranges where appropriate;
- cloud metadata addresses;
- non-HTTP(S) protocols;
- embedded credentials;
- disallowed ports;
- DNS results containing any rejected destination under strict mode.

Validation occurs before connection and again after every redirect. Connection code must not perform an unchecked second resolution that enables DNS rebinding; the resolved and approved address is bound to the request while preserving correct TLS hostname verification.

The implemented boundary is `Shared::NetworkSafety::DestinationPolicy`. It
queries A and AAAA, rejects a mixed public/disallowed answer set, returns an
immutable approved set and safe count-only provenance, and gives the pinned
set to the only customer-target HTTP transport. That transport disables proxy
routing and automatic retries, retains the DNS hostname for `Host`, SNI and TLS
verification, and bounds each protocol stage plus header, encoded and decoded
response consumption. Crawling manually validates redirects, reauthorizes each
retry, checks cancellation and streams/hashes bodies into caller-owned sinks.
Direct target HTTP clients elsewhere under `app/` fail the architecture gate.

Application policy is reinforced by a default-deny crawl/render worker network
policy. Its versioned contract is `config/crawler_egress_policy.yml`; protected
workers fail boot until deployment attests that the policy is active.

### Rendering

Rendering is a second, metered operation. The render worker:

- runs in an isolated process/container profile;
- has no access to application-private networks;
- blocks downloads and unsupported schemes;
- caps navigation and total execution time;
- caps page requests, response bytes, CPU, and memory;
- intercepts every request through the same destination policy;
- stores artifacts outside PostgreSQL;
- destroys the browser context after each page or bounded batch.

## 11. Rule engine architecture

Rule contract:

```ruby
Analysis::RuleResult = Data.define(
  :rule_key,
  :rule_version,
  :subject_type,
  :subject_key,
  :outcome,
  :severity,
  :confidence,
  :evidence,
  :recommendation,
  :verification
)
```

Rules are pure where practical. They declare required inputs, supported property kinds, and cost class. A rule version is immutable after activation.

Outcomes:

```text
pass
fail
warning
not_applicable
unknown
error
```

`unknown` is not treated as pass. Provider failure and insufficient evidence remain visible.

## 12. Finding identity and history

A finding fingerprint is based on stable logical identity, not scan row IDs:

```text
organization
project/property
rule key
rule major identity version
subject type
normalized subject key
selected evidence identity fields
```

A `Finding` survives across scans. A `FindingOccurrence` belongs to one scan and records the observed evidence. Resolution occurs only after a qualifying scan or explicit workflow policy. Reappearance creates a recurrence and can reopen an issue.

## 13. Search and performance data

Provider data is ingested into source-specific tables/read models. It is not flattened into crawl facts.

- Search Analytics: aggregate rows by declared dimensions and date.
- URL Inspection: Google-known indexed state at inspection time.
- CrUX: field distributions and percentiles for available origin/URL data.
- Lighthouse: reproducible lab execution metadata and audit JSON.
- Crawler timing: network timing from SearchOps workers.

The UI displays source, collection interval, requested dimensions, freshness, and known limitations.

## 14. Release guard

A release has:

- external system and external ID;
- commit/revision;
- environment;
- deployed timestamp;
- baseline scan;
- post-release scan;
- policy version;
- result and evidence;
- publisher deliveries.

Policy evaluation is deterministic from a frozen comparison. Example:

```yaml
fail_when:
  new_critical_findings_gte: 1
  newly_non_indexable_pages_gte: 10
  broken_internal_links_increase_gte: 20
  canonical_change_percent_gte: 10
warn_when:
  mobile_lcp_regression_percent_gte: 15
```

A project must explicitly enable blocking behavior. Default is advisory.

## 15. Reporting and events

Reports use immutable snapshots:

```text
ReportDefinition
→ ReportRun
→ frozen data cutoff and filters
→ rendered artifact
→ ReportDelivery
```

Notifications and outgoing webhooks consume domain events through an outbox table. Publishing is at-least-once; consumers and receivers use idempotency keys.

## 16. Database topology

The MVP may use one PostgreSQL server with separate databases or schemas/connections for application, queue, cache, and cable workloads. Production configuration should preserve the ability to move queue/cache workloads without changing domain code.

Recommended initial logical databases:

```text
searchops_primary
searchops_queue
searchops_cache
searchops_cable
```

All remain PostgreSQL. Development may consolidate when documented.

High-volume candidates for later partitioning:

- crawl_urls;
- crawl_fetch_permits;
- crawl_fetches;
- crawl_links;
- page_snapshots metadata;
- finding_occurrences;
- usage_events;
- audit_events;
- webhook deliveries.

## 17. Artifact storage

PostgreSQL stores:

- content hash;
- byte size;
- MIME type;
- compression;
- encryption/storage key;
- retention class;
- redaction state;
- capture timestamps;
- association to scan/fetch/report.

Object storage holds:

- response bodies;
- rendered DOM;
- screenshots;
- Lighthouse JSON;
- optional HAR/network summaries;
- report files;
- export archives.

Access uses short-lived signed URLs after authorization. Object keys do not expose customer domain names or emails.

The private artifact implementation stores source/scan/retention metadata in `artifacts` and unique physical object metadata in `artifact_blobs`. Deduplication is constrained by organization, project, property and encryption-key version. Raw bodies remain outside PostgreSQL. See [`implementation/PRIVATE_ARTIFACT_STORAGE.md`](./implementation/PRIVATE_ARTIFACT_STORAGE.md).

## 18. Failure handling

- Provider timeouts are retried with bounded exponential backoff and jitter.
- Validation and authorization failures are not retried.
- Jobs classify transient, permanent, quota, canceled, and security rejection states.
- Scan checkpoints make retry idempotent.
- Repeatedly failing work reaches an inspectable terminal state.
- Every crawler request obtains short-lived global/organization/scan/host capacity from PostgreSQL before DNS;
  provider backoff and a hard scan deadline prevent both pressure bypass and unbounded delay.
- A partial provider outage does not erase previously known data; freshness and error state are shown.
- The web application remains responsive when render workers are unavailable.

## 19. Extraction thresholds

A separate crawler service is considered only when at least one condition is measured:

- crawler connections or locks materially degrade primary application SLOs;
- worker fleet needs independent deploy cadence or language/runtime;
- browser isolation cannot be achieved safely with process/container roles;
- regional crawling becomes a paid requirement;
- dedicated customer worker pools become common;
- crawl throughput exceeds the practical Solid Queue/frontier architecture;
- a separate team owns and operates the subsystem.

An extraction proposal requires an ADR, measured baseline, data ownership plan, failure semantics, migration strategy, and rollback plan.
