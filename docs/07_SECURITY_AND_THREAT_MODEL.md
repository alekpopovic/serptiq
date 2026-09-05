# Security and Threat Model

## 1. Scope

This threat model covers the Rails application, PostgreSQL workloads, object storage, background jobs, crawler and Chromium workers, OAuth/OIDC login, external integrations, billing webhooks, API keys, reports, and production operations.

The crawler creates an unusually strong outbound trust boundary. SearchOps must assume that a customer-controlled URL, DNS record, redirect, page body, JavaScript program, XML document, JSON-LD block, mobile association file, store metadata record, and webhook payload may be malicious.

## 2. Protected assets

- User identity and active sessions.
- Organization, project, scan, finding, report, and billing isolation.
- OAuth access/refresh tokens and provider credentials.
- Billing webhook secrets and subscription state.
- API keys and outgoing webhook signing secrets.
- Customer page artifacts that may contain personal or confidential data.
- Crawl capacity, browser capacity, provider quotas, and monthly credits.
- Production network, cloud metadata endpoints, internal services, and databases.
- Audit integrity and incident evidence.
- Release-gate integrity.
- Source code, CI credentials, deployment credentials, and backups.

## 3. Threat actors

- Anonymous internet attacker.
- Malicious free-trial user.
- Paying customer attempting to exceed plan limits or scan unauthorized targets.
- Compromised customer account.
- Malicious or compromised organization member.
- Compromised third-party provider or leaked provider token.
- Malicious page owner serving adversarial HTML/JavaScript/XML.
- Insider with operational access.
- Automated bot attempting credential abuse, scraping, or denial of service.
- Accidental operator or developer error.

## 4. Trust boundaries

```text
browser ↔ Rails web
external identity provider ↔ OAuth callback
billing provider ↔ webhook ingress
CI/CD system ↔ release webhook/API
Rails web ↔ PostgreSQL
Rails web/jobs ↔ object storage
jobs ↔ external provider APIs
crawl worker ↔ customer/public internet
render worker/Chromium ↔ customer/public internet
application ↔ mail/Slack provider
operator ↔ production control plane
```

Each boundary requires authentication, authorization, validation, rate limits, observability, and failure behavior appropriate to its risk.

## 5. Top threats and required controls

### T-01 Cross-tenant data access

Attack examples:

- changing an organization, project, scan, report, or artifact ID;
- using a valid API key against another project;
- background job receives mismatched organization/resource IDs;
- project-scoped role is treated as organization-scoped;
- signed artifact URL is generated before authorization.

Controls:

- opaque identifiers;
- explicit tenant-aware query entry points;
- organization IDs on aggregate roots and high-risk child rows;
- relationship validation on every write;
- policy enforcement in controllers and domain operations;
- short-lived signed artifact URLs generated after authorization;
- adversarial integration tests mixing real IDs across two organizations;
- no `default_scope` as the security mechanism;
- audit denied high-risk attempts.

### T-02 Privilege escalation

Attack examples:

- member grants a role containing permissions they do not possess;
- last owner removes or demotes themselves;
- stale session keeps old privileges;
- team assignment crosses organizations;
- project role performs billing or organization deletion.

Controls:

- immutable system-role definitions;
- grant-subset validation for custom roles;
- scope-compatible permission filter;
- last-owner database/domain invariant;
- recent-authentication requirement for critical actions;
- session rotation/re-evaluation after privilege changes;
- same-organization checks for teams, memberships, roles, and scopes;
- composite foreign keys for principal, grantor, custom-role and typed scope tenant agreement, including
  same-organization property-to-project scope references;
- grant-subset and self/team-self escalation rejection before assignment, plus allow-only database checks;
- authorization negative-path tests.

### T-03 OAuth/OIDC login attacks

Attack examples:

- callback CSRF;
- authorization-code interception;
- nonce replay;
- issuer/audience confusion;
- algorithm/key confusion in ID tokens;
- open redirect through `return_to`;
- account takeover through unverified email collision;
- identity-linking CSRF.

Controls:

- one-time hashed state;
- OIDC nonce;
- PKCE where provider supports it;
- exact registered redirect URIs;
- provider metadata allowlist;
- issuer, audience, authorized-party, signature, key ID, expiry, issued-at, and nonce validation;
- bounded JWKS caching and key rotation;
- local-path allowlist for return destinations;
- do not auto-link identities on unverified email;
- recent-authenticated explicit account-linking flow;
- consume transactions exactly once;
- rotate local session after success.

### T-04 Session theft and replay

Controls:

- random high-entropy opaque session token;
- store only token digest;
- `Secure`, `HttpOnly`, appropriate `SameSite`;
- forced TLS and HSTS;
- session rotation;
- idle and absolute expiration;
- user-visible session list and revocation;
- server-side revoke on suspension/deletion;
- CSP and XSS prevention;
- no sensitive data in cookie payload.

### T-04a Organization invitation interception and replay

Attack examples:

- a raw invitation token is recovered from the database, logs, OAuth state, or browser history;
- a signed-in account accepts a link intended for a different provider-verified email;
- two requests consume the same token or create duplicate memberships;
- resend leaves the previous token usable;
- a crafted initial role or scope crosses an organization boundary;
- issue responses disclose whether the destination already has an account.

Controls:

- 256-bit random opaque token with only a keyed digest stored in PostgreSQL;
- public entry captures a format-valid token in a short-lived encrypted, `HttpOnly`, `SameSite=Lax`
  cookie and OAuth stores only the fixed local review path;
- acceptance requires an active identity and an exact email assertion from an active,
  provider-verified identity; primary/profile email alone is insufficient;
- invitation row lock, unique organization/user membership, one pending organization/email,
  and same-organization composite foreign keys;
- explicit accepted/revoked/expired/superseded terminal states and resend-as-new-token;
- removed memberships never reactivate through invitation acceptance; suspended memberships
  reactivate only through explicit acceptance;
- allowlisted organization-scoped initial role intent, backend owner authorization, neutral
  issue response, HMAC-keyed rate limits, and structured audit outcomes;
- atomic invitation acceptance plus initial role assignment through the ordinary grant-authority boundary;
- `no-store` and `no-referrer` on entry/review/error responses and one generic unavailable page
  for invalid, expired, revoked, replayed, or wrong-email links.

### T-05 Billing forgery, replay, and state corruption

Attack examples:

- fake subscription webhook;
- duplicated event;
- reordered old event overwrites newer state;
- checkout custom data points to another organization;
- provider call timeout causes duplicate change;
- privileged access granted before payment confirmation.

Controls:

- exact raw-body HMAC/signature validation with constant-time comparison;
- payload size and content-type limits;
- immutable ingress record and idempotency fingerprint;
- asynchronous projector;
- row lock/optimistic lock on subscription;
- compare provider event/update time and canonical state;
- organization correlation validated through signed metadata and provider customer mapping;
- provider API idempotency where supported;
- reconciliation job;
- access only after trusted local projection;
- test-mode isolation.

The reconciliation job verifies the stored tenant/subscription pair plus provider environment, customer,
subscription and active plan mapping. It stores only bounded allowlisted facts and a reference digest. A
missing object or ambiguous/stale snapshot cannot revoke or grant access automatically. Support replay and
targeted reconciliation require explicit platform grants and recent authentication; organization ownership is
insufficient.

### T-06 Quota bypass and double spending

Attack examples:

- concurrent scans pass a read-then-write limit check;
- retry consumes twice or gets free repeated work;
- cancel/retry leaks reservations;
- one organization charges another.

Controls:

- atomic locked usage window;
- organization-scoped idempotency key;
- reservation before enqueue;
- immutable usage events;
- finalization state machine;
- expiring reservation recovery;
- entitlement snapshot on long-running work;
- invariant/property tests under concurrency.

### T-07 SSRF and internal network discovery

Attack examples:

- URL points to loopback/private/link-local/metadata address;
- public DNS changes after validation;
- redirect leads to internal destination;
- IPv4-mapped IPv6 bypass;
- alternative numeric IP notation;
- userinfo/authority parser confusion;
- Chromium subresource reaches internal network;
- non-HTTP protocol is invoked.

Controls:

- one canonical URL parser;
- allow only HTTP/HTTPS;
- reject userinfo;
- normalize host and IDN safely;
- resolve all A/AAAA records;
- classify every resolved address;
- reject loopback, private, link-local, multicast, unspecified, reserved, metadata, and policy-disallowed ranges, including mapped forms;
- validate allowed ports;
- bind connection to an approved resolution while verifying TLS hostname;
- re-run full checks for each redirect;
- apply identical interception to browser navigation and subresources;
- egress firewall/network policy denying private/control-plane destinations;
- cap redirects and DNS answers;
- record a redacted network decision;
- dedicated regression corpus for parser and rebinding cases.

Prompt 068 implements these controls in the centralized
`Shared::NetworkSafety::DestinationPolicy` and pinned transport. The decision
uses the versioned IANA special-purpose matrix, approves only ports 80/443,
rejects an entire mixed A/AAAA answer set and produces count-only provenance.
The transport accepts only that immutable approval, preserves the DNS hostname
for `Host`/SNI/certificate verification, disables proxy routing and implicit
retries, and verifies the connected peer before response consumption. An
architecture rule prohibits other customer-target clients. Protected crawl and
render workers also require an operator attestation for the separately applied
default-deny egress contract in `config/crawler_egress_policy.yml`; the runtime
flag is not itself a firewall.

Prompt 069 layers the only general crawl fetcher over that approval. It accepts
GET/HEAD only, manually validates every redirect, requires verified TLS, and
applies independent header/body/total deadlines plus header, compressed,
decoded and decompression-ratio limits. Decoded content is streamed and hashed
without transport retention. Only explicitly transient failures/statuses may
retry; every retry re-resolves the target and checks cancellation. Strong
declared-type/signature conflicts are rejected before an artifact handle is
returned, and fetch telemetry excludes URLs, addresses, headers and bodies.

Prompt 071 requires an exact current frontier-owner context at that public fetch boundary and acquires a
short-lived PostgreSQL permit before each DNS decision. Global, organization, scan and normalized-host rate/
concurrency checks are serialized and durable across workers. Expiry and bounded recovery fail safely after a
worker crash; 429/503/network signals cannot back off past the scan's hard lifetime. Emergency global/host
controls require a dedicated platform grant, are audited and cannot be changed through tenant permissions.
Pressure telemetry and customer throttle observations exclude hostnames, URLs and permit tokens.

Property environment origins use one immutable value contract before any network activity. It lowercases the
scheme and DNS identity, converts Unicode names to a stable ASCII IDNA network form, derives a normalized
Unicode display form, collapses HTTP 80/HTTPS 443, removes one terminal DNS dot and treats only an empty/root
path as an origin. Credentials, query, fragment, non-root path, malformed labels, IP literals, single-label
names and known internal naming suffixes are rejected. Host-scope comparisons require equality or a literal
dot-delimited suffix, so `notexample.com` is never a subdomain of `example.com`. This parser deliberately does
not claim that a syntactically public hostname resolves to a public address: the crawler boundary must resolve
and validate every A/AAAA answer and every redirect before connecting.

Crawl URL identity version 2 separately retains a normalized fetch URL and a deterministic deduplication URL.
Fragments are removed; dot segments and percent encoding are canonicalized; query filtering changes identity
only and never rewrites semantic fetch values. Exact host/port/path/depth scope is evaluated before frontier
admission. An HTML canonical recommendation is untrusted content and never expands that scope.

Robots files and their sitemap directives are also untrusted. SearchOps fetches the top-level file through the
same pinned public-network boundary, follows at most five public redirects with full revalidation, rejects HTTPS
downgrades, streams at most 500 KiB and persists only a digest plus bounded parsed policy. Sitemap values are
syntactic candidates, never destination approval or an instruction to fetch. An explicit verified-owner robots
override changes only crawl-policy evaluation and cannot bypass scope, DNS/address, redirect or quota controls.
Robots exclusion is not treated or described as access authorization.

Sitemap discovery applies exact-origin scope before DNS, and restricts every redirect to that origin in
addition to the public-address policy. XML uses a strict streaming `NONET` parser with entity substitution,
DTD loading, XInclude and parser limit relaxation disabled; document/entity nodes are rejected explicitly.
Compressed and decompressed bytes, XML nesting, entries, documents and index recursion are independently
bounded. PostgreSQL retains only normalized graph/status/`lastmod` evidence and response digests, never raw
XML or gzip bodies.

### T-08 Denial of service and resource exhaustion

Attack examples:

- infinite URL spaces/calendars/faceted navigation;
- zip/XML bombs;
- huge headers or bodies;
- slow responses;
- redirect loops;
- JavaScript infinite loops and memory growth;
- millions of DOM nodes/links;
- repeated expensive Lighthouse requests;
- notification or webhook fan-out.

Controls:

- verified property before expensive work;
- monthly credits and per-scan hard caps;
- URL pattern and query-parameter policies;
- depth and discovery limits;
- response/header/body/decompression limits;
- streaming parsers where appropriate;
- timeouts and cancellation;
- per-host and per-organization concurrency;
- isolated Chromium memory/CPU/process limits;
- bounded queue retry/fan-out;
- circuit breakers/provider backoff;
- global emergency disable entitlement;
- operational alerts.

Static HTML analysis applies a separate 5 MiB source ceiling before the tolerant HTML5 DOM parse, explicit tree
depth/attribute/element limits, and independent caps for links, metadata, headings, images and JSON-LD. It stores
only bounded normalized facts and deduplicated edge evidence; oversized structured data retains a digest/status,
not its payload. Relative references and the first valid base URL still pass URL normalization, immutable scan
scope and frontier capacity before discovery.

### T-09 Stored and reflected XSS

Sources include fetched HTML, titles, anchor text, JSON-LD, app metadata, issue comments, webhook errors, and provider profile data.

Controls:

- Rails escaping by default;
- sanitize only through audited allowlists;
- display fetched markup as text, never raw HTML;
- CSP with nonces/hashes and no unnecessary unsafe directives;
- bounded plain-text evidence excerpts;
- safe Markdown renderer if introduced;
- no remote script injection through report branding;
- system tests with hostile fixtures.

HTML evidence normalization removes invalid encoding and control characters and bounds every display snippet,
but the stored value remains hostile text. Rails automatic escaping is mandatory and extraction code never marks
page evidence safe or executes scripts. Malformed/XSS fixture tests cover title, anchor, alt and JSON-LD values.

### T-10 SQL/command/template injection

Controls:

- parameterized Active Record queries;
- strict sort/filter allowlists;
- no user input in shell command strings;
- Lighthouse/Chromium invoked with argument arrays and controlled files;
- templates selected by internal IDs;
- report content escaped;
- no customer-defined Ruby, JavaScript, SQL, regex without safety review;
- regex length/time limits for configurable patterns.

### T-11 Artifact exposure

Controls:

- opaque object keys;
- private buckets;
- server-side encryption;
- short-lived signed downloads after authorization;
- content disposition and safe MIME;
- malware/content-type policy for uploads;
- per-class lifecycle deletion;
- access audit;
- no public bucket listing;
- delete/export reconciliation across database and storage.

Project/property deletion additionally uses an exact-target 30-day hold, recent authentication, durable
ordered stage state and a PostgreSQL guard that accepts physical deletion only for the matching tenant,
workflow lease and stage. Private artifact signing fails before the signer is called when either parent is
archived, pending deletion, deleted or belongs to another tenant. Final cleanup retains only minimized target
tombstones plus separately governed billing/security evidence. Hold length, backup erasure and exceptional
legal/fraud holds require product privacy/legal approval rather than being inferred from this control.

### T-12 XML and parser attacks

Controls:

- disable external entities and network access;
- limit document and element counts/depth;
- limit sitemap index recursion and total URLs;
- reject compressed bombs using compressed/uncompressed limits;
- use maintained parsers;
- fuzz parser adapters.

### T-13 Webhook and API abuse

Controls:

- API key prefix plus strong secret; store digest only;
- scopes, project restriction, expiry, revocation, last use;
- rate limits by key/organization/IP class;
- request body limits and JSON schema validation;
- outgoing webhook HTTPS requirement and destination safety policy;
- signed deliveries with timestamp and event ID;
- replay controls and idempotency;
- delivery response truncation/redaction.

Billing ingress additionally bypasses controller parameter parsing, caps the exact raw body before JSON
handling, verifies HMAC-SHA256 with constant-time current/previous-secret comparisons, encrypts accepted bytes
at rest and preserves the first payload when a logical duplicate has a different checksum.

### T-14 Sensitive data leakage in logs

Controls:

- structured allowlisted fields;
- Rails parameter filtering;
- token/header/query-string redaction;
- no raw page bodies or webhook secrets;
- exception message sanitization;
- access-controlled log platform;
- retention and incident access audit.

### T-15 Supply-chain and deployment compromise

Controls:

- locked dependencies;
- Bundler audit, Brakeman, static checks, secret scanning;
- pinned base image digest policy;
- SBOM and image vulnerability scan;
- least-privilege CI/deploy credentials;
- protected production environment;
- signed or provenance-aware image workflow where available;
- database backup before high-risk migrations;
- rollback and restore drills.

## 6. Domain verification threat model

A domain verification challenge:

- is random and high entropy;
- is stored as a digest;
- is bound to organization, property, host, method, and expiry;
- cannot be reused across hosts or organizations;
- records exact evidence;
- is revalidated before expensive scans according to risk/age;
- is revoked when property host changes;
- does not treat arbitrary redirects to another host as proof;
- validates DNS responses against the intended name and record type;
- limits HTML/meta proof fetch to the exact allowed origin and safe destination policy.

Search Console ownership may be trusted only after a separately consented tenant connection, both
`integrations.manage` and exact-property `properties.verify`, an exact provider property match and Google's
`siteOwner` permission are verified. Google login identity supplies none of these facts. Accessible provider
lists are bounded and request-local; only the selected identifier/type, connection revision, permission and
checked time persist. URL-prefix proof is exact-origin only, while `sc-domain:` matches only the exact host and
never infers sibling ownership. Account, scope, token-revision or property-origin changes revoke current proof.

The implementation derives each user-visible proof value from an application key and the immutable random
challenge identity, then stores only its SHA-256 digest. Exact instructions are available only behind
`properties.verify`; audit/outbox records contain method, lifecycle and bounded failure category but never the
origin, response body, provider payload or proof value. Adapter evidence is restricted to booleans and bounded
counts/status codes. HTML and meta adapters accept only an exact-origin network fetcher contract; canonical
origin parsing alone is never treated as SSRF authorization.

Attempts reserve a monotonic sequence under row lock, enforce a minimum interval and fail terminally after a
bounded number of mismatches. A process interruption can consume a sequence without fabricating evidence; a
later retry remains possible after the interval. Verified proof has a maximum lifetime, while high-volume and
render workloads require stricter freshness (seven days and 24 hours respectively). Origin mutation revokes
current bound proof in PostgreSQL even if application callbacks are bypassed.

DNS verification asks only the absolute intended TXT name, requires the response question to match, preserves
case and whitespace when joining DNS TXT chunks, and compares only the exact challenge digest. Record count,
relevant byte size, CNAME links and observed authority NS records are bounded; retained evidence contains only
counts and booleans. The resolver has no process-global decision cache. Periodic rechecks reload the explicit
tenant/challenge pair and exact current origin; a failed observation does not renew the proof's freshness.

HTML verification uses the centralized public-network destination client. It resolves and classifies every
A/AAAA answer, pins the connection to one approved address while preserving TLS hostname verification, then
repeats the full decision at every redirect. Redirects preserve the exact proof path, carry no query/fragment,
never downgrade HTTPS and target only an explicit same-host or one-literal-`www` canonical variant. Responses
are streamed under byte/time/redirect/content-type caps. File proof is a byte-exact whole-body comparison;
meta proof requires exactly one matching static source tag parsed without JavaScript. Only bounded booleans,
counts, status and stable error categories survive the request.

## 7. Browser isolation profile

Minimum production expectations:

- non-root browser process;
- read-only base filesystem;
- ephemeral writable directory;
- dropped Linux capabilities;
- seccomp/AppArmor where available;
- no host networking;
- egress denied to private/control-plane ranges;
- process, PID, memory, CPU, file, and open-descriptor limits;
- no persistent browser profile;
- downloads disabled;
- clipboard, camera, microphone, geolocation, notifications, and file access disabled;
- request interception with byte and count budgets;
- process termination on timeout;
- artifact collection bounded and sanitized.

`--no-sandbox` must not be the default production solution. If platform constraints ever require it, the browser must run inside a stronger container/VM sandbox and an ADR must document the risk.

## 8. Security event examples

```text
auth.oauth_state_rejected
auth.identity_link_attempt
session.revoked
authorization.denied_critical
membership.owner_invariant_blocked
organization.owner_invariant_violation
organization.ownership_transferred
organization.ownership_transfer_rejected
billing.webhook_signature_failed
billing.event_replay_ignored
quota.reservation_denied
crawler.destination_rejected
crawler.redirect_rejected
crawler.browser_limit_exceeded
api.rate_limited
webhook.delivery_disabled
artifact.access_denied
data.deletion_requested
data.deletion_canceled
data.deletion_completed
```

Security events contain correlation and stable reason codes, not secrets.

Customer-visible tenant and access-management events are also written to the append-only `audit_events`
ledger. Metadata accepts only bounded internal change keys; email addresses, IP addresses, user agents,
credentials and payload-like fields are filtered. Raw source IP and user-agent values are never retained;
only optional keyed digests may be stored. `audit_log.read` gates organization history, while CSV export
remains fail-closed until both `audit_log.export` and the future `audit.export` entitlement are satisfied.

## 9. Security test gates

Required before launch:

- two-tenant ID-mixing suite;
- role/scope privilege-escalation suite;
- OAuth state/nonce/issuer/audience/JWKS/expiry/account-linking suite;
- session rotation and revocation suite;
- billing signature/idempotency/reordering/reconciliation suite;
- quota concurrency suite;
- SSRF corpus including IPv4, IPv6, mapped addresses, redirects, DNS changes, and Chromium subresources;
- malicious HTML/JSON-LD/XML/XSS fixtures;
- oversized/slow/decompression-bomb controls;
- API key scope and rate-limit suite;
- artifact authorization and expiry suite;
- deletion/export completeness test;
- dependency, image, and secret scans.

## 10. Incident response minimum

1. Detect and classify.
2. Disable affected feature through emergency entitlement/operational switch.
3. Revoke sessions, API keys, provider credentials, or webhook endpoints as applicable.
4. Preserve immutable audit and ingress evidence.
5. Rotate secrets with documented blast radius.
6. Patch and deploy through reviewed release procedure.
7. Reconcile billing, usage, jobs, and artifacts.
8. Notify affected customers/regulators according to applicable obligations.
9. Produce post-incident actions and add regression tests.
