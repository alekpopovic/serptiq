# Test Strategy

## 1. Purpose

SearchOps combines financial state, multi-tenant authorization, asynchronous work, hostile network input, browser execution, third-party APIs, and high-volume analytical data. The test strategy therefore treats correctness and isolation as product requirements, not as cleanup work after feature development.

The goals are to:

- prevent cross-organization access;
- prove permission, entitlement, and quota decisions independently and together;
- keep subscription state deterministic under duplicate and out-of-order webhooks;
- make crawler and browser workers safe against malicious destinations and documents;
- keep SEO rules reproducible and explainable;
- detect regressions before deployment;
- test failures, retries, cancellation, and recovery—not only happy paths.

## 2. Test layers

| Layer | Tooling | Primary purpose |
|---|---|---|
| Domain/unit | Minitest | Value objects, transitions, resolvers, normalizers, scoring and rule evaluation |
| Model/database | Minitest + PostgreSQL | Constraints, indexes, locking, tenancy relationships and lifecycle invariants |
| Policy/access | Minitest | Permission, scope, entitlement and quota decisions |
| Request/integration | Rails integration tests | HTTP contracts, sessions, CSRF, rate limits, authorization and error responses |
| Job | Active Job test helpers + real PostgreSQL suite | Idempotency, retries, leases, cancellation and tenant context |
| Adapter contract | Shared Minitest contracts | OAuth, billing, provider APIs, object storage, DNS and notification adapters |
| System | Capybara + browser | Critical user journeys and progressive enhancement |
| Security | Focused regression suites | SSRF, redirect rebinding, XSS, parser bombs, signature validation and tenant isolation |
| Performance | Benchmarks/load scripts | Crawl frontier, rule batches, dashboards, usage ledger and report generation |
| Production smoke | Read-only/low-risk checks | Health, login redirect, queue execution, storage, provider connectivity and rollback readiness |

Fast suites should remain deterministic and runnable on every commit. External services are represented by local fakes and recorded fixtures in CI. A small opt-in sandbox suite may contact provider test environments, but it must not be required for ordinary pull requests.

## 3. Required test environments

### Local

- PostgreSQL using the same major version as production.
- Separate application, queue, cache and cable databases are allowed, but all use PostgreSQL.
- Local S3-compatible service or filesystem adapter for ordinary development.
- Stub OAuth, billing, Search Console, CrUX, Slack and store-provider adapters.
- Chromium image matching the production worker image closely enough to reproduce renderer behavior.

### CI

CI starts clean PostgreSQL databases, applies the schema from zero, and runs tests with randomized order. It stores failure artifacts such as screenshots, browser console output, server logs and failing fixture payloads.

At least one CI job must exercise:

- Solid Queue against real PostgreSQL;
- database locking and `SKIP LOCKED`;
- Chromium/Ferrum behavior;
- security scanners;
- production asset compilation;
- container build and boot.

### Staging

Staging uses separate provider applications, webhook secrets, buckets, databases and domains. It must never share production OAuth callbacks or billing webhook endpoints.

## 4. Naming and organization

Suggested layout:

```text
test/
  models/
  domain/
  policies/
  services/
  controllers/
  requests/
  jobs/
  system/
  adapters/contracts/
  adapters/providers/
  security/
  performance/
  fixtures/
    files/
    provider_payloads/
    crawl_sites/
```

Tests name the behavior and decision, not the implementation method. Example:

```ruby
test "project viewer cannot trigger a billable rendered scan"
test "duplicate paid webhook does not create a second subscription transition"
test "redirect to link-local address is rejected before the second request"
```

## 5. Multi-tenant isolation suite

Create at least two organizations, two projects and overlapping human-readable names. Reuse real IDs from the opposing tenant in request parameters to prove denial.

The reusable isolation matrix covers:

- organization settings;
- memberships and invitations;
- teams and role assignments;
- projects, properties and verifications;
- integrations and credentials;
- scans, crawl URLs and artifacts;
- findings, issues, comments and reports;
- releases and policies;
- billing, usage and audit events;
- API keys and webhooks.

For every tenant-owned route or domain operation, test:

1. authorized user in the correct organization;
2. authenticated user in another organization;
3. member without the permission;
4. member whose permission exists only at a different scope;
5. suspended membership;
6. stale or archived target;
7. background job with mismatched tenant and resource identifiers.

Generated object-storage URLs are tested only after authorization and must be short-lived.

`bin/tenancy-security` is the required consolidated gate for every identity, organization, membership,
invitation, team, role-assignment and audit entity implemented through Phase 03. It mixes real identifiers
across two tenants, then runs ownership and audit relationship consistency reports against PostgreSQL.

## 6. Authorization, entitlement and quota matrix

The access decision suite independently varies:

```text
authentication
membership status
permission
scope
entitlement
quota
resource state
```

Representative truth table:

| Permission | Entitlement | Quota | Expected |
|---|---|---|---|
| allow | enabled | available | perform |
| deny | enabled | available | forbidden |
| allow | disabled | available | upgrade required |
| allow | enabled | exhausted | quota exceeded |
| allow | enabled | reserved elsewhere | conflict/retry |
| allow | enabled | available | still deny when resource state is invalid |

Test that failures do not consume quota and retries do not double-charge. Reservations must be atomic under concurrent workers.

## 7. Authentication and session tests

Google OIDC and GitHub OAuth adapters share contract tests while preserving provider-specific validation.

Required cases include:

- valid start and callback;
- missing, expired, consumed and mismatched state;
- PKCE verifier mismatch;
- OIDC nonce mismatch;
- wrong issuer or audience;
- expired/not-yet-valid token;
- unknown or rotated signing key;
- unverified email handling;
- callback with an unexpected redirect URI;
- denied consent and provider errors;
- duplicate callback replay;
- identity collision;
- explicit account linking with recent authentication;
- session fixation prevention;
- session rotation after login and privilege change;
- logout and revocation;
- safe `return_to` allowlist;
- CSRF on state-changing application actions.

Never make a live provider call in the main test suite.

## 8. Billing tests

### Webhook ingress

Test signature verification against the exact raw body, size limits, unsupported event types, stale timestamps where applicable, malformed JSON and secret rotation.

### Event persistence and projection

For every supported subscription event, test:

- first delivery;
- duplicate delivery;
- same event ID with conflicting payload;
- out-of-order delivery;
- missing referenced customer/subscription;
- temporary database failure and retry;
- permanent invalid payload;
- replay from the admin interface;
- reconciliation correcting drift.

The provider event is stored before asynchronous projection. Projection uses locking/idempotency and produces one deterministic canonical state.

### Access lifecycle

Cover trial, active, past due, paused, cancelled, expired and grace-period behavior. Verify exact feature behavior during downgrade, scheduled cancellation and reactivation. Existing reports remain readable when new scans are paused.

## 9. Usage and concurrency tests

Run multi-thread/process tests against PostgreSQL for:

- competing reservations near a quota boundary;
- reservation expiration;
- partial consumption and release;
- retry with the same idempotency key;
- monthly window rollover;
- plan change during an active scan;
- cancellation and refund of unused reserved credits;
- append-only usage ledger;
- repair/reconciliation.
- exact scan meter snapshots and operation-level source-key replay;
- accepted HTTP responses versus rejected/transport/canceled non-billable attempts;
- pre-work incremental allocation denial and customer-visible quota pause;
- parallel scans assigning the final shared credit under the real advisory lock;
- terminal/crash recovery releasing pending allocations and unused hold capacity;
- authorized scan corrections remaining append-only and cross-tenant denied.

Do not mock the database for concurrency behavior.

## 10. Crawler security tests

Build a local malicious-target fixture service. It should simulate:

- loopback and private IPv4/IPv6;
- link-local and cloud metadata addresses;
- DNS answer changing between validation and connection;
- public URL redirecting to private address;
- redirect loops and excessive chains;
- encoded/alternative IP representations;
- credentials in URLs;
- unsupported schemes;
- oversized body and decompression bomb;
- slow headers/body and connection stalls;
- misleading `Content-Type`;
- huge sitemap index;
- recursive sitemap references;
- invalid encodings and malformed XML;
- robots redirects and conflicting directives;
- hostname with mixed Unicode/punycode edge cases.

Every destination and every redirect hop must be resolved and validated. Tests assert that no forbidden network connection is attempted, not only that an error is eventually returned.

## 11. Browser-worker tests

Execute hostile pages in an isolated Chromium test container and verify:

- private/network destinations are blocked;
- downloads, popups, permissions and unexpected protocols are disabled;
- browser context and cookies are new for each target;
- service workers and persistent storage do not leak between scans;
- CPU, memory, wall-clock and network-request limits stop abusive pages;
- console/page errors are captured safely;
- cancellation kills the page and eventually the browser process;
- crashed browser jobs can be retried idempotently;
- secrets are absent from browser environment and logs.

## 12. SEO rule tests

Each rule has versioned fixtures:

```text
valid document
single violation
boundary condition
malformed input
missing source data
not-applicable case
```

A rule-result contract asserts:

- stable rule key and version;
- category, severity and confidence;
- evidence locator;
- affected resource;
- deterministic fingerprint;
- user-facing summary;
- remediation;
- verification method;
- no unescaped hostile content.

Golden files are acceptable for normalized rule output, but changes require explicit review. Rule tests must not depend on wall-clock time, network access or provider availability.

## 13. Finding and issue lifecycle tests

Cover:

- first detection;
- repeated occurrence;
- evidence change with same fingerprint;
- disappearance and automatic resolution candidate;
- manual risk acceptance;
- false-positive suppression;
- reappearance/reopen;
- rule-version migration;
- targeted verification;
- assignment/comment audit;
- archived project behavior.

A finding is not marked resolved merely because a user closes an issue. Verification state remains explicit.

## 14. Integration contract tests

All adapters implement shared contracts for:

- normalized success response;
- authentication failure;
- authorization/scope failure;
- rate limit;
- timeout;
- transient server error;
- malformed provider response;
- pagination;
- idempotency where applicable;
- credential refresh and revocation;
- observability/redaction.

Recorded fixtures must remove access tokens, emails not needed for the case, customer data and signatures.

## 15. System-test journeys

Minimum critical journeys:

1. Social login → create organization → choose free plan → create project.
2. Invite member → assign scoped role → member sees only permitted project.
3. Verify domain → run initial crawl → inspect evidence → create issue.
4. Assign issue → mark ready for verification → targeted rescan resolves it.
5. Upgrade through checkout → signed webhook activates entitlements.
6. Hit quota → see accurate limit → upgrade/add credits → resume.
7. Connect Search Console → select property → import data.
8. Configure release policy → submit release → view pass/fail result.
9. Add Android/iOS property → validate association files → map routes.
10. Cancel subscription → preserve read access while enforcing lifecycle policy.

Critical flows must also pass with JavaScript disabled where the Rails/HTML path is intended to remain functional.

## 16. Performance and scale tests

Initial targets are product hypotheses and must be revised from production measurements.

Test at representative volumes:

- 100 organizations × 20 projects;
- 1 million crawl URL rows;
- 10 million finding occurrences;
- concurrent frontier leasing;
- dashboard queries over 12 months;
- report snapshot generation;
- usage ledger monthly aggregation;
- bulk retention deletion/partition detach.

Performance tests record dataset, PostgreSQL version, hardware, query plan and percentile distribution. Avoid one-number benchmarks without context.
The implemented frontier plan fixture and its reproducible environment are recorded in
[`implementation/CRAWL_FRONTIER.md`](./implementation/CRAWL_FRONTIER.md).

## 17. CI quality gates

Recommended order:

1. dependency lock consistency;
2. Ruby syntax and formatting/lint;
3. ERB/JavaScript/CSS lint;
4. unit/domain tests;
5. model/request/job/integration tests;
6. system tests;
7. SSRF and tenant-isolation regression suites;
8. Brakeman;
9. dependency vulnerability audit;
10. database migration safety check;
11. assets precompile;
12. production container build and `/up` boot;
13. generated configuration/schema validation.

No gate may be silently ignored. Temporary exceptions require an owner, reason and expiry recorded in the repository.

## 18. Test data and privacy

- Use synthetic identities, domains and billing data.
- Never copy production HTML or provider payloads into fixtures without sanitization and approval.
- Keep secrets out of VCR-like recordings.
- Use deterministic clocks and UUIDs where behavior depends on them.
- Delete browser and report artifacts after tests.
- Make test cleanup safe even after interrupted runs.

## 19. Release acceptance

A release candidate is eligible for production only when:

- all required CI suites pass;
- no unresolved critical security finding exists;
- migrations have forward/rollback or recovery notes;
- staging smoke and webhook tests pass;
- backups and restore procedure are current;
- rollback image is available;
- feature flags/defaults are reviewed;
- observability dashboards and alerts cover new critical paths;
- relevant runbooks and customer-facing behavior are documented.
