# Crawl policy configuration

Prompt 058 introduces the Crawling-owned, per-environment policy used by later
scan admission and execution. It configures public crawl intent; it does not
perform DNS resolution, fetch a URL, reserve credits or execute a browser.

## Access and tenant boundary

Every public operation resolves the project, website-family property and active
environment by the actor membership's `organization_id`. The operation then
requires `scans.configure` at the exact property scope and the effective
`crawl.manual` entitlement. A foreign, archived or mismatched resource fails
before any policy row is read or written.

`crawl_policy_sets` provides one lockable head per exact environment.
`crawl_policy_versions` repeats the organization/project/property/environment
identity and uses composite foreign keys for the head and creating membership.
Policy updates lock the head and append a monotonic immutable version. The
database trigger rejects update or delete of version rows.

## Effective controls

A policy stores:

- ordered start and sitemap URL lists;
- include and exclude path globs;
- maximum URLs and traversal depth;
- query handling (`ignore`, `tracking_only` or `all`);
- a fixed SearchOps crawler identity with an optional product-token suffix;
- request rate and per-scan concurrency;
- the required `respect` robots behavior;
- JavaScript sample percentage and rendered-page cap; and
- raw artifact retention days.

The effective maximum URL count is the lower of
`SEARCHOPS_CRAWLER_MAX_URLS_PER_SCAN` and `crawl.max_urls_per_scan`. Per-scan
concurrency cannot exceed `SEARCHOPS_CRAWLER_CONCURRENCY`; depth is capped at
20 and request rate at 10 requests/second. Rendering, rendered-page count,
custom path rules, custom user-agent suffix and artifact retention are bounded
by their current effective entitlements. Custom-required or missing numeric
entitlements fail closed. Settings can reduce these values but cannot expand
them. Scan admission must revalidate the selected version against the current
limits so a later plan or global-cap reduction is not bypassed.

The reset action appends a plan-safe version: the exact environment root URL,
tracking-parameter normalization, robots compliance, one concurrent request,
no rendering, and the lower current URL/retention bounds. Updates and resets
emit allowlisted audit metadata containing only the operation and changed field
names. URLs, paths and user-agent values are never placed in audit metadata.

## URL and pattern safety

Start and sitemap URLs pass the shared HTTP target parser. Credentials,
fragments, IP literals, ambiguous whitespace/backslashes and non-HTTP schemes
are rejected. The normalized ASCII origin must exactly equal the environment's
canonical origin; a sibling subdomain or port is not accepted. This syntactic
binding is not an SSRF decision. Scan execution must still resolve and validate
every destination and redirect through the global public-network policy.

Rules are path globs, not arbitrary regular expressions. Each begins with `/`,
is at most 256 bytes and 32 path segments, and is limited to 12 wildcard stars
and four recursive `**` tokens. Regex metacharacters, controls, backslashes and
three-or-more consecutive stars are rejected. Accepted text is escaped before
`*`/`**` expansion and the resulting anchored regex has a 10ms match timeout.

## Scan snapshots and estimates

`Crawling::Public.snapshot_for_scan` accepts an authorized exact resource and a
UUID allocated by the scan aggregate. It locks the policy head and copies the
complete selected configuration into `crawl_policy_snapshots` with its source
version and SHA-256 digest. A unique `scan_id` makes retries idempotent, while a
cross-tenant reuse fails closed. Snapshot rows are immutable in both the model
and PostgreSQL. Prompt 062 owns the `scans` table and will add the scan-side
relationship; until then, only the Crawling public operation may allocate this
foundation row.

The UI explains a maximum estimate using governed usage weights: one credit per
HTTP fetch and ten per rendered page in the current catalog. It is an estimate,
not a reservation and not a guarantee that the crawler will discover or fetch
that many pages. Quota reservation remains part of later scan admission.

## MVP exclusions

The MVP does not support authenticated/private crawl, customer credentials,
private network targets, robots bypass, raw regular expressions, a fully
replaceable user agent or impersonation of privileged third-party crawlers.
Browser rendering remains isolated-worker work owned by later prompts; this
policy only describes its bounded sample.

## Migration and operations

Migration `20260904145000_create_crawl_policies.rb` creates three new tables,
composite foreign keys, bounded checks, indexes and immutable-row triggers. The
tables start empty, so there is no data backfill or table rewrite. Installing
the environment foreign key briefly locks `property_environments`; production
deployment should use the normal migration lock/statement timeouts. Rollback is
destructive for policy history and scan snapshots and is appropriate only
before those rows are relied upon.
