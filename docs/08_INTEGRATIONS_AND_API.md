# Integrations and Public API

## 1. Integration principles

- The application owns domain interfaces and canonical state.
- Provider payloads never leak directly into core business decisions.
- Credentials are encrypted and scope-minimized.
- Calls have explicit timeouts, retries, idempotency, rate-limit handling, and health status.
- Source freshness and provider errors are visible.
- Every adapter has contract fixtures and a fake implementation.
- A provider outage degrades the affected feature without making the main application unavailable.

## 2. Integration connection lifecycle

```text
pending
→ connected
→ healthy
→ degraded
→ reauthorization_required
→ revoked
```

Connection records include organization, optional project scope, provider, external account/property identifiers, granted scopes, token expiry, last successful sync, last failure category, and revocation metadata.

## 3. Google Search Console

### Authentication

Use Google OAuth/OpenID infrastructure with the least scopes necessary for Search Console data. Login identity and Search Console authorization are separate connections; a user may log in with one identity while connecting a different permitted Search Console account.

### Property selection

After authorization:

1. list accessible Search Console properties;
2. let an authorized member select an exact property;
3. verify that it corresponds to the SearchOps website property;
4. record permission level and external identifier;
5. never infer access to sibling domains.

### Search Analytics

Persist:

- requested and returned date range;
- dimensions such as query, page, country, device, and search appearance;
- clicks, impressions, CTR, and position;
- row limit/pagination request metadata;
- provider freshness and import timestamp;
- aggregation type.

The UI must disclose that provider results may return top rows rather than an exhaustive list of all possible rows.

### URL Inspection

Use only for bounded, authorized URLs. Store:

- inspected URL;
- inspection timestamp;
- Google-known index status and coverage fields;
- referring/sitemap fields made available by the provider;
- provider response version;
- error/permission state.

Label this as **Google-known indexed state**, not a live fetch. SearchOps live fetch and rendered state remain separate.

### Quotas

Provider quotas are configuration and operational policy, not hardcoded product promises. Track provider response headers/errors, apply backoff, and schedule work fairly across organizations.

## 4. CrUX

Use CrUX API and CrUX History API for available URL/origin field data.

Persist:

- source scope: URL or origin;
- collection period;
- form factor;
- metric histogram/distribution and percentile data;
- provider key and response version;
- `no data` as an explicit state.

Never substitute Lighthouse results when CrUX is unavailable. Display lab data separately.

## 5. Lighthouse

Lighthouse executes in a dedicated worker and records:

- Lighthouse and Chromium versions;
- device/network profile;
- target URL and approved destination record;
- run timestamp;
- selected categories;
- key metrics;
- full JSON artifact reference;
- execution errors and limits.

Runs consume weighted credits. Sampling policy chooses representative templates/pages rather than every URL by default.

## 6. Google login and GitHub login

### Google OIDC

Validate state, nonce, PKCE transaction, discovery metadata allowlist, issuer, audience, signature, key ID, expiry, issued-at, and verified email policy.

### GitHub OAuth

Validate one-time state, S256 PKCE and the exact callback; exchange the code server-to-server once; fetch the stable numeric provider user ID; and query the bounded primary email list only with granted `user:email`. Access tokens remain transient. Do not key identities by mutable login name or treat a public/unverified email as account authority.

### Account linking

Linking a second provider requires an active recent local session, a signed provider/session-bound confirmation, a CSRF-protected start and a one-time OAuth transaction. Email equality alone is insufficient and an identity owned by another account is never transferred. Unlinking revokes the selected identity only when another active sign-in provider remains, and atomically rotates the current session. Account-security pages expose local linked/last-use times, not provider tokens, subjects or raw profiles.

## 7. Lemon Squeezy

Supported MVP functions:

- hosted checkout creation;
- customer portal link;
- subscription create/update/cancel/resume synchronization;
- payment success/failure/recovery handling;
- test-mode separation;
- provider subscription reconciliation.

Webhook receiver:

1. reads bounded exact raw body;
2. validates `X-Signature` using the configured signing secret and constant-time comparison;
3. inserts an idempotent ingress record;
4. returns success for accepted new/duplicate events;
5. processes asynchronously;
6. maps to canonical billing events;
7. locks and updates local subscription projection;
8. emits audit/outbox events.

The ingress portion is implemented at `POST /webhooks/billing/lemon_squeezy` with a 512 KiB exact-body limit,
current/previous-secret HMAC rotation, encrypted durable payloads, logical-event/checksum conflict detection
and commit-before-enqueue behavior. See `docs/implementation/BILLING_WEBHOOK_INGRESS.md`. Projection into
canonical subscription state follows in Prompt 047.

Only subscribe to required event types. Retain enough raw data for troubleshooting under the declared retention policy.

The production client uses the fixed Lemon Squeezy HTTPS API origin and JSON:API media type. It validates the
configured and returned store, product, variant and test-mode tuple before normalizing any subscription.
Because the provider documentation does not declare mutation idempotency support, POST/PATCH/DELETE calls are
not retried; a digest of the local operation key is used only for safe correlation. Subscription retrieval and
bounded reconciliation pagination may retry short transient failures. See
`docs/implementation/LEMON_SQUEEZY_ADAPTER.md` for the dated endpoint/status mapping and observability contract.

The provider-neutral contract, canonical lifecycle, redacted values and per-operation timeout/retry policy are
implemented in `docs/implementation/BILLING_PROVIDER_CONTRACT.md`. Ordinary access reads the trusted local
projection and never calls the provider synchronously.

## 8. Slack notifications

The MVP uses a Slack app or incoming webhook strategy selected during implementation. The domain adapter accepts structured messages, not preformatted provider payloads.

Events may include:

- critical scan completed;
- scan failed;
- new release regression;
- issue assigned;
- issue verification failed/reopened;
- quota threshold reached;
- integration requires reauthorization.

Secrets are encrypted. Delivery is retried with backoff and deduplicated. Message content avoids raw page bodies and credentials.

## 9. App Store and Google Play

Provider APIs and authentication requirements can change. Implement adapters behind a common snapshot contract:

```ruby
AppDiscovery::ListingSnapshot
  platform
  app_identifier
  locale
  captured_at
  fields
  assets_metadata
  provider_version
  source
```

The MVP supports:

- connected provider source when credentials and APIs are available;
- validated user-supplied export/JSON fallback;
- manual metadata entry for evaluation;
- immutable snapshots and diffs.

Rules use a dated provider-constraint catalog. Never scrape in violation of provider terms or represent a listing audit as proof of ranking change.

## 10. Android and iOS association validation

Validation is a safe fetch plus platform-specific parsing.

Android inputs:

- website host;
- hosted `/.well-known/assetlinks.json`;
- package name;
- expected SHA-256 signing fingerprints;
- supplied/imported manifest intent filters;
- Android platform behavior version.

iOS inputs:

- website host;
- hosted `/.well-known/apple-app-site-association` and supported fallback location;
- Team ID and Bundle ID;
- supplied associated-domain declarations;
- AASA app identifiers and components/path rules.

Every validation captures fetch chain, MIME/content type, parse result, exact matched association, and sample route evaluations.

## 11. IndexNow

IndexNow is an opt-in submission adapter. The UI and events must distinguish:

```text
submission accepted by protocol endpoint
≠ URL crawled
≠ URL indexed
≠ ranking changed
```

Submission requires verified ownership and permission. Deduplicate URL batches, respect provider limits, store request/response metadata, and never auto-submit arbitrary third-party URLs.

## 12. Incoming deployment webhook

Endpoint pattern:

```text
POST /api/v1/projects/{project_id}/releases
```

Authentication options for MVP:

- project-scoped API key;
- signed webhook secret;
- provider adapter added later.

Request includes idempotency key, environment, revision, deployed timestamp, source system, URL, and metadata allowlist. The endpoint creates or returns a release, optionally schedules a post-release scan, and returns asynchronous status.

## 13. Public API v1

The initial API is deliberately narrow.

Suggested resources:

```text
GET  /api/v1/organizations/{organization_id}
GET  /api/v1/projects
GET  /api/v1/projects/{id}
GET  /api/v1/projects/{id}/properties
POST /api/v1/projects/{id}/scans
GET  /api/v1/scans/{id}
GET  /api/v1/projects/{id}/findings
GET  /api/v1/projects/{id}/issues
PATCH /api/v1/issues/{id}
POST /api/v1/projects/{id}/releases
GET  /api/v1/releases/{id}/gate
POST /api/v1/findings/{id}/verify
```

### API conventions

- JSON with explicit versioned representations.
- Opaque IDs.
- Cursor pagination for high-volume collections.
- ISO 8601 UTC timestamps.
- Stable machine-readable error codes.
- Idempotency key required for create/run operations.
- `ETag`/conditional requests where useful.
- Rate-limit headers.
- No raw provider tokens or raw page artifacts in normal representations.
- Artifact downloads use separate short-lived authorized URLs.

### Error example

```json
{
  "error": {
    "code": "quota_reservation_failed",
    "message": "The organization does not have enough scan credits.",
    "request_id": "req_...",
    "details": {
      "entitlement": "crawl.credits_monthly",
      "required": 1200,
      "available": 740
    }
  }
}
```

## 14. API keys

Create once and display the raw secret once:

```text
sop_live_<public-prefix>_<secret>
```

Store:

- key prefix;
- digest;
- organization;
- optional project restriction;
- scopes;
- created by;
- expiry;
- last used;
- revoked timestamp.

Critical write scopes require an explicit role and plan entitlement. Key use never bypasses project scoping.

## 15. Outgoing webhooks

Envelope:

```json
{
  "id": "evt_...",
  "type": "scan.completed",
  "version": 1,
  "occurred_at": "2026-09-04T18:00:00Z",
  "organization_id": "org_...",
  "project_id": "prj_...",
  "data": {}
}
```

Headers include event ID, timestamp, signature version, and HMAC signature. Receivers can reject old timestamps and deduplicate event IDs. SearchOps retries boundedly and supports authorized replay.

Destination URLs pass an outbound webhook safety policy. Private/internal destinations are rejected in hosted SaaS.

## 16. Adapter contract testing

Each adapter must test:

- successful request/response mapping;
- authentication and signature verification;
- timeout;
- 429 and retry-after;
- transient 5xx;
- permanent 4xx;
- malformed response;
- schema evolution/unknown fields;
- duplicate event;
- out-of-order event where relevant;
- redacted logging;
- health-state transitions.

Live sandbox smoke tests are separate from deterministic CI fixtures.
