# Product Requirements Document v1

## 1. Document control

| Field | Value |
|---|---|
| Product | SearchOps |
| Status | Implementation baseline |
| Version | 1.0 |
| Date | 2026-09-04 |
| Audience | Product, engineering, design, security, operations, QA |
| Delivery target | Production-capable MVP |
| Working name | SearchOps; not trademark-cleared |

## 2. Problem statement

Organizations commonly use separate systems for technical SEO crawls, Search Console reporting, performance monitoring, app-store optimization, mobile deep-link verification, project management, and deployment checks. This creates five recurring failures:

1. findings are disconnected from owners and implementation work;
2. static crawl evidence is confused with search-engine state or real-user performance;
3. regressions are discovered after traffic loss rather than during release;
4. web and mobile discovery surfaces are managed independently;
5. plan access, permissions, and usage controls become inconsistent as the SaaS grows.

SearchOps provides one operational model for collecting evidence, prioritizing issues, coordinating fixes, verifying outcomes, and preventing regressions.

## 3. Product principles

### 3.1 Evidence before score

Every finding must expose what was observed, where it was observed, which rule version produced it, when it first and last appeared, and how it can be verified. A composite score may summarize results but may never replace evidence.

### 3.2 Separate data meanings

The UI and data model must distinguish:

- live fetch state;
- rendered browser state;
- Google-known indexed state;
- real-user field performance;
- laboratory performance;
- app-store listing state;
- configured deep-link state;
- inferred or experimental AI-search visibility.

### 3.3 Workflow over issue volume

The product optimizes for verified remediation, not the number of warnings emitted. Rules must minimize noise and support suppression, false-positive handling, risk acceptance, and verification.

### 3.4 Safe-by-default crawling

The crawler is an outbound network security boundary. Domain verification, destination filtering, bounded resource use, redirect revalidation, and browser isolation are product requirements, not later hardening.

### 3.5 Explicit commercial controls

Authorization, plan capabilities, and usage limits are independent decisions. Business code must use permission, entitlement, and quota services rather than plan-name conditionals.

### 3.6 Modular monolith first

The MVP optimizes for correctness, delivery speed, and operational simplicity. Process separation is allowed; distributed ownership and service boundaries are deferred until justified by measured constraints.

## 4. Personas

### 4.1 Agency owner

Needs multiple client projects, controlled client access, branded reports, predictable usage, billing control, and proof that the agency resolved meaningful problems.

### 4.2 SEO lead

Needs scans, prioritization, evidence, issue triage, assignments, comments, trends, Search Console context, and verified remediation.

### 4.3 Developer

Needs reproducible technical evidence, release diffs, API/webhook integration, environment separation, and low-noise regression gates.

### 4.4 Content editor

Needs metadata, headings, content, internal-link, structured-data, and app-listing tasks without access to billing or infrastructure settings.

### 4.5 Product analyst

Needs read-only trends, Search Console and performance context, report exports, and change attribution.

### 4.6 Client stakeholder

Needs a limited project view, clear progress, reports, and no visibility into other clients.

### 4.7 Platform administrator

Needs support tooling, event replay, subscription reconciliation, job visibility, security audit data, and safe impersonation alternatives. Direct silent impersonation is excluded from the MVP.

## 5. Jobs to be done

- When a deployment changes public pages, detect whether it introduced search regressions before they become long-lived.
- When a scan finds a problem, provide enough evidence for an engineer or editor to reproduce and fix it.
- When a task is marked ready, re-scan the affected target and determine whether the finding is truly gone.
- When traffic data exists, rank findings by likely impact rather than severity alone.
- When a company has web and mobile properties, validate the mapping between public URLs and app destinations.
- When an agency invites a client, expose only the intended project and actions.
- When a subscription or plan changes, apply capabilities and quotas deterministically without corrupting running work.
- When a provider webhook is duplicated or reordered, converge local billing state safely.
- When a user supplies a URL, prevent access to private or metadata networks.
- When a rule changes, preserve historical explainability.

## 6. Scope

### 6.1 Included in MVP

#### SaaS foundation

- Google OIDC and GitHub OAuth login.
- Application-owned, revocable server-side sessions.
- Organizations, members, invitations, teams, system roles, scoped role assignments.
- Project and organization scopes.
- Versioned plan catalog and entitlements.
- Credit-based usage with atomic reservations and finalization.
- Lemon Squeezy checkout, customer portal, subscription synchronization, reconciliation, and test mode.
- Provider-neutral billing interface.
- Audit events, data export, account and organization deletion workflows.

#### Project model

- Project as the customer product or client engagement.
- Website, Android, and iOS properties.
- Production, staging, and custom environments.
- Domain verification by DNS TXT, HTML file, meta tag, or trusted Search Console ownership.
- Project-level settings, crawl policies, notification policies, and release policies.

#### Web scanning

- Sitemap discovery and sitemap-index traversal.
- Bounded internal crawl.
- HTTP response, redirect, header, MIME, and body metadata collection.
- Robots policy interpretation.
- URL normalization and deduplication.
- Internal link extraction and graph metrics.
- Optional isolated JavaScript rendering.
- Artifact storage and retention.
- Targeted rescans.

#### Analysis

- Technical rule registry and versioning.
- Indexability, canonical, hreflang, metadata, heading, link, image, structured-data, source/render differences, and selected performance rules.
- AI crawler policy matrix for declared user agents; no ranking guarantees.
- Finding identity, occurrences, evidence, severity, confidence, and priority.
- Issue workflow, assignment, comments, suppression, false positive, risk acceptance, verification, reopen behavior.
- Baselines and scan comparisons.

#### Integrations and data

- Google Search Console OAuth and Search Analytics imports.
- URL Inspection imports for bounded user-selected URLs.
- CrUX API and CrUX History API where data exists.
- Lighthouse lab runs for bounded samples.
- Slack and email notifications.
- Incoming deployment webhook.
- Outgoing signed webhook.
- API keys and a small read-oriented public API.
- IndexNow submission adapter as an opt-in action, with accurate status semantics.

#### Mobile discovery

- Android App Links validation using hosted Digital Asset Links data and supplied/imported manifest declarations.
- iOS Universal Links validation using associated domains and hosted AASA data.
- Web-to-app route map.
- App Store and Google Play metadata audits using user-supplied or connected data.
- Listing snapshots and differences.

#### Operations

- Docker image and process-role commands.
- Kamal deployment baseline.
- PostgreSQL backups and restore test.
- Object-storage lifecycle.
- Structured logs, metrics, health, readiness, and job visibility.
- Security, tenant-isolation, billing-idempotency, and crawler-abuse test suites.

### 6.2 Excluded from MVP

- Proprietary global backlink index.
- Proprietary global keyword or SERP database.
- Automated link purchasing or outreach.
- Guaranteed ranking claims.
- Automatic production-site modification.
- Bulk AI article generation or autonomous publishing.
- Full device farm.
- Private-site authenticated crawl with customer browser credentials.
- Native mobile SDKs.
- SAML/SCIM implementation; retained as Enterprise roadmap entitlement.
- Multi-region active-active architecture.
- Kubernetes.
- Elasticsearch/OpenSearch.
- Customer-defined executable rules.
- Arbitrary plugin execution.
- Full Jira/Trello/GitHub issue synchronization.
- Automated competitive content copying.

## 7. Information architecture

```text
Organization
├── Billing
├── Members
├── Teams
├── Roles
├── Audit log
└── Projects
    ├── Overview
    ├── Properties
    ├── Scans
    ├── Findings
    ├── Issues
    ├── Performance
    ├── Search Console
    ├── App discovery
    ├── Releases
    ├── Reports
    ├── Integrations
    └── Settings
```

## 8. Core domain model

```text
User
└── Identity
└── Session
└── Membership
    └── Organization
        ├── Subscription
        ├── Entitlements
        ├── Usage
        ├── Roles and assignments
        └── Project
            └── Property
                └── Scan
                    ├── Fetch
                    ├── PageSnapshot
                    ├── Link
                    ├── FindingOccurrence
                    └── Artifact
```

A durable `Finding` represents the identity of a problem across scans. `FindingOccurrence` records an observation in one scan. An `Issue` represents workflow around one or more related findings.

## 9. Functional requirements

### FR-001 Authentication

The system shall authenticate users through supported external identity providers and maintain application-owned sessions. It shall validate authorization response state, OIDC nonce, token issuer, token audience, token signature, expiry, redirect URI, and PKCE when supported. It shall prevent identity takeover through unverified or colliding email addresses.

### FR-002 Session management

Users shall be able to view and revoke active sessions. Authentication and privilege changes shall rotate sessions. Session records shall include creation, last activity, expiry, IP prefix or address according to policy, and user-agent metadata.

### FR-003 Organizations

A user shall be able to create and switch organizations. Every organization shall have at least one owner. Slugs shall be unique and changeable through a controlled redirect/alias policy.

### FR-004 Memberships and invitations

Authorized members shall invite users by email, assign initial roles and project scopes, resend or revoke invitations, and remove members subject to last-owner rules. Invitation tokens shall be single-use, hashed at rest, expiring, and scoped to one organization.

### FR-005 Teams

Authorized users shall create teams, manage team memberships, and assign a role to a team at organization or project scope.

### FR-006 Roles and permissions

The platform shall seed immutable system-role templates. Role assignments shall be scoped to organization or project. Authorization shall be evaluated server-side for every action. Custom roles are designed but not exposed before the applicable plan is implemented.

### FR-007 Plans and versions

Plans shall contain immutable versions. A plan version shall define price display metadata, billing mapping, entitlements, quota limits, and availability. Existing subscriptions remain attached to their plan version until an explicit migration.

### FR-008 Entitlements

A typed entitlement resolver shall answer whether a feature is enabled and what configured value applies. Sources, in precedence order, are emergency deny, organization override, subscription plan version, trial/default plan, then safe default.

### FR-009 Usage and quotas

Metered actions shall create immutable usage events. Long-running work shall reserve quota atomically, finalize actual usage, and release unused reservations. Duplicate idempotency keys shall not double-charge usage.

### FR-010 Billing

The first provider adapter shall integrate Lemon Squeezy. Checkout shall include signed or verifiable application identifiers. Raw signed webhooks shall be stored and acknowledged quickly, then processed asynchronously and idempotently. Reconciliation shall repair missed, delayed, duplicated, or reordered events.

### FR-011 Projects

Authorized members shall create, update, archive, restore, and delete projects subject to plan limits and retention policy. A project may contain website, Android, and iOS properties.

### FR-012 Properties

A website property shall store a normalized origin, environment, verification state, crawl policy, and optional sitemap seeds. Android and iOS properties shall store platform identifiers and deep-link configuration references without exposing signing secrets.

### FR-013 Domain verification

Large scans and rendered scans require verified ownership. Verification methods shall have creation, attempt, success, expiry, revocation, and evidence records. The system shall not infer permanent ownership solely from a successful historical fetch.

### FR-014 Scan creation

Authorized users may create a scan when entitlement, quota, target state, verification state, and concurrency policy allow it. Scan creation must be idempotent for a supplied request key.

### FR-015 Crawl execution

The crawler shall use explicit states, bounded retries, cancellation, resumability, and failure classification. It shall not visit destinations rejected by network policy. Redirects and DNS changes shall be revalidated.

### FR-016 Robots and sitemap behavior

The product shall parse and report robots directives and sitemap contents. The customer can choose whether an audit crawler obeys site robots for verified properties, but the default is respectful behavior. The product shall clearly state that robots rules are not access control.

### FR-017 Rendering

Rendered scans shall execute in an isolated browser worker with strict navigation, request, CPU, memory, time, download, protocol, and network restrictions. No customer page code may execute in a web or default worker process.

### FR-018 Rule execution

Rules shall implement a versioned contract and produce deterministic results from a declared input schema. Results shall contain rule key, version, evidence, affected resource, default severity, confidence, and verification method.

### FR-019 Findings

The system shall deduplicate the same logical problem across scans using a stable fingerprint that includes organization, project/property, rule identity, and canonical subject. It shall preserve first seen, last seen, resolved, and recurrence history.

### FR-020 Issues

Users shall triage findings into issues, assign owners, add comments, change workflow status, accept risk with expiry, mark false positives with rationale, request verification, and observe automatic reopen behavior.

### FR-021 Prioritization

Priority shall be explainable and may combine severity, confidence, affected pages, search impressions/clicks, recurrence, release novelty, and estimated remediation effort. The raw components shall be stored so the score can be recalculated.

### FR-022 Search Console

The system shall connect verified Search Console accounts with least-required scopes, import aggregate performance rows, preserve source dimensions and date windows, and disclose that returned data may not represent every possible row.

### FR-023 URL Inspection

The system shall import Google-known indexed state for bounded URLs and clearly distinguish it from the platform's current live fetch.

### FR-024 Performance

The system shall distinguish CrUX field data from Lighthouse lab data and crawler timing. It shall not represent lab results as real-user measurements.

### FR-025 Scheduling

Organizations with the entitlement may define recurring scans. Schedule changes shall be tenant-scoped, validated, auditable, and safe during scheduler restarts or duplicated scheduler processes.

### FR-026 Reports

Users shall generate immutable report snapshots with filters, period, data cutoff, source freshness, branding policy, and delivery history. Reports must not silently mutate when underlying data changes.

### FR-027 Notifications

Notification rules shall select event, severity, project/property scope, channel, quiet hours, and deduplication window. Delivery retries shall be bounded and observable.

### FR-028 Android discovery

The platform shall validate the hosted Digital Asset Links document, declared hosts, package name, certificate fingerprints, and route rules. It shall explain Android-version-specific limitations when relevant.

### FR-029 iOS discovery

The platform shall validate the hosted AASA document, associated-domain declarations, application identifiers, components/path rules, content type, redirect behavior, and accessibility.

### FR-030 App listings

The platform shall snapshot supplied or connected listing metadata, validate platform constraints, compare versions/locales, and raise evidence-backed findings. It shall not claim direct ranking causation.

### FR-031 Route map

Users shall map public web patterns to Android and iOS destinations and fallback behavior. The platform shall identify missing, conflicting, unreachable, and inconsistent routes.

### FR-032 Releases and regression gates

Users shall register deployments/releases, attach pre/post scans, calculate newly introduced or worsened findings, apply a versioned policy, and publish a pass/warn/fail result. Blocking a deployment requires explicit project configuration.

### FR-033 API and webhooks

The platform shall issue hashed API keys with scopes, expiry, last-used data, and revocation. Outgoing webhooks shall be signed, idempotent, retried, and replayable. Public APIs shall enforce the same tenant, permission, entitlement, and quota decisions as the UI.

### FR-034 Audit

Sensitive administrative and domain actions shall create append-only audit events with actor, organization, action, subject, metadata, request correlation, and timestamp. Secrets and full sensitive payloads shall not be logged.

### FR-035 Data lifecycle

The system shall implement retention by plan and data class. Organization export and deletion shall be asynchronous, auditable, resumable, and include object-storage artifacts. Legal holds are out of MVP but deletion jobs shall support a future hold check.

## 10. Non-functional requirements

### NFR-001 Availability

The MVP target is 99.9% monthly availability for authenticated web and API requests, excluding announced maintenance and third-party outages. Scan processing has separate queue latency and completion objectives.

### NFR-002 Tenant isolation

Automated tests must attempt cross-organization access at model-service, request, job, API-key, report, artifact, and webhook boundaries.

### NFR-003 Performance

- P95 authenticated HTML response under 500 ms for non-reporting pages at target MVP load.
- P95 JSON API response under 400 ms for simple reads.
- Paginated collections shall avoid unbounded queries.
- Scan pages shall use summaries and pagination rather than loading raw crawl rows.
- Web requests shall never wait for a full crawl, Lighthouse run, report render, or provider reconciliation.

### NFR-004 Scale assumptions

Initial design target:

- 1,000 paying organizations;
- 10,000 active users;
- 100,000 projects/properties;
- 20 million HTTP fetches per month;
- 2 million rendered-page operations per month;
- 100 million finding occurrences retained under tiered policies.

These are design envelopes, not launch forecasts.

### NFR-005 Reliability

Long-running jobs shall be idempotent, retry-safe, observable, and resumable at meaningful checkpoints. Poison work shall reach a reviewable failed/dead state rather than retry forever.

### NFR-006 Security

The application shall implement OWASP-aligned web controls, OAuth/OIDC best current practices, encrypted credentials, strict webhook verification, secure session cookies, CSP, CSRF defenses, dependency scanning, and a crawler-specific SSRF defense.

### NFR-007 Privacy

The platform shall minimize personal data, document subprocessors, support export and deletion, and define configurable retention. Page artifacts may contain customer-site personal data and therefore require access control, encryption, expiry, and redaction guidance.

### NFR-008 Accessibility

Critical product flows target WCAG 2.2 AA. Keyboard navigation, visible focus, semantic landmarks, labels, error association, reduced motion, and sufficient contrast are acceptance requirements.

### NFR-009 Internationalization

The UI architecture shall support localization. The MVP language may be English, but dates, times, numbers, currencies, and time zones must not be hardcoded.

### NFR-010 Observability

Every web request, job, scan, provider call, webhook, and report shall carry correlation identifiers. Logs shall be structured and redacted. Metrics shall expose queue depth, latency, failures, scan throughput, provider errors, and quota activity.

### NFR-011 Portability

Production dependencies shall be standard PostgreSQL, S3-compatible object storage, SMTP/email provider, and HTTPS integrations. AWS-specific capabilities are optional deployment choices rather than domain dependencies.

## 11. User flows

### 11.1 First-run flow

```text
Sign in
→ accept terms/privacy
→ create organization
→ choose evaluation plan
→ create project
→ add website property
→ prove domain ownership
→ configure crawl bounds
→ reserve credits
→ run baseline scan
→ review prioritized findings
```

Prompt 057 implements the organization-to-property portion as a persisted six-step setup. It previews current
resource and crawl entitlements, creates the reviewed project/properties atomically, and reports verification
and settings readiness without starting a crawl. Credit reservation remains part of the later explicit scan
admission step, never a GET, refresh or wizard completion side effect.

### 11.2 Issue remediation flow

```text
Open finding
→ inspect evidence and affected URLs
→ create or attach issue
→ assign member/team
→ move to in progress
→ implement fix
→ request verification
→ targeted rescan
→ resolve or reopen automatically
```

### 11.3 Billing flow

```text
Open plans
→ compare effective entitlements and quotas
→ create hosted checkout
→ return to pending state
→ receive signed webhook
→ project local subscription
→ activate plan version
→ reconcile with provider
```

### 11.4 Release guard flow

```text
Register release
→ choose baseline
→ deploy
→ receive deployment webhook
→ run targeted scan
→ compute regressions
→ apply policy
→ publish pass/warn/fail
→ notify configured channels
```

### 11.5 Mobile discovery flow

```text
Add Android/iOS property
→ enter identifiers
→ fetch hosted association file
→ import or enter app declarations
→ map web routes
→ validate configuration
→ create findings
→ save snapshot
→ compare after app release
```

## 12. UX requirements

- Every score has a tooltip or detail view explaining inputs.
- Source freshness and last successful import are visible.
- Destructive actions require clear scope and consequences.
- Plan-limit messages identify the exact entitlement or quota and current usage.
- Users retain read access to existing data during most billing grace states.
- Empty states guide users to the next meaningful action.
- Finding lists support filtering by property, scan, category, severity, confidence, status, assignee, first seen, regression, and traffic impact.
- Large URL lists use pagination or cursor navigation.
- Accessibility is tested in the sign-in, onboarding, scan, finding, issue, billing, and member-management flows.
- No dark pattern is used to hide cancellation or data export.

## 13. Analytics events

At minimum:

```text
auth.login_started
auth.login_succeeded
organization.created
member.invited
project.created
property.created
verification.started
verification.succeeded
scan.requested
scan.started
scan.completed
scan.failed
finding.viewed
issue.created
issue.assigned
verification.requested
issue.verified_resolved
issue.reopened
integration.connected
checkout.started
subscription.activated
subscription.canceled
quota.blocked
report.generated
release_gate.completed
```

Product analytics must not include page bodies, access tokens, secrets, or sensitive query strings.

## 14. Risks and mitigations

| Risk | Mitigation |
|---|---|
| Crawler used for SSRF or abuse | Verification, destination filtering, redirect revalidation, budgets, rate limits, isolated workers |
| Noisy findings reduce trust | Versioned rules, confidence, suppression, false-positive workflow, verification |
| Browser rendering costs exceed revenue | Weighted credits, per-plan limits, reservations, sampled rendering, process isolation |
| Provider webhook inconsistency | Raw event storage, idempotency, state machine, ordered comparison, reconciliation |
| Cross-tenant data exposure | Explicit organization scoping, policy service, composite constraints, adversarial tests |
| Search/API semantics misunderstood | Source-specific labels, freshness, limitations, no unsupported ranking claims |
| App-store integrations are brittle | Adapter contracts, snapshots, manual/import fallback, provider health indicators |
| Single PostgreSQL workload contention | Separate database configurations/connections, workload indexes, retention, measurable extraction thresholds |
| Overbuilding before demand | Explicit exclusions, phase gates, usage telemetry, customer validation |

## 15. Launch gates

The production MVP cannot launch until:

- all P0 and P1 acceptance scenarios pass;
- tenant-isolation suite passes;
- billing webhook replay and reconciliation tests pass;
- crawler SSRF and redirect-rebinding tests pass;
- backup restore is demonstrated;
- secret rotation and session invalidation procedures exist;
- domain-verification bypass tests pass;
- data export and deletion complete in staging;
- production dashboards and alerts exist;
- terms, privacy, acceptable-use, subprocessors, retention, and support policies are published;
- at least two pilot organizations complete the full detect-to-verify workflow.
