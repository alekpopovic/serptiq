# Robots exclusion policy

Prompt 066 implements the RFC 9309 policy used by SearchOps crawl workers. Robots exclusion expresses a site
owner's requested crawl policy. It is not authorization, authentication, data protection, or evidence that a
URL is absent from a search index.

## Identity and retrieval boundary

The robots product token is `SearchOpsBot`. HTTP requests identify the crawler as
`SearchOpsBot/1.0 (+<application-origin>/crawler)`; the linked public page describes its purpose and behavior.
Only the lowercase top-level `/robots.txt` resource is the initial target.

Retrieval uses `Shared::NetworkSafety`, never a direct HTTP connection. Each target and redirect is limited to
HTTP(S), resolved immediately before the pinned connection, rejected if any answer is non-public, and checked
again after every redirect. At most five redirects are followed, including across public authorities; an HTTPS
request is never downgraded to HTTP. DNS, open and read deadlines are independently configurable. The response
is streamed under a 500 KiB limit and successful content must be `text/plain`.

| Observation | Persisted status | Respect-mode decision |
|---|---|---|
| HTTP 2xx, parseable or empty file | `fetched` | evaluate the selected group and longest rule |
| HTTP 4xx | `unavailable` | allowed, as permitted by RFC 9309 |
| HTTP 5xx, other unresolved HTTP result, DNS/transport/timeout or redirect failure | `unreachable` | unknown and fail closed |
| Body exceeds 500 KiB | `oversized` | unknown and fail closed |
| Invalid successful media/response shape or no usable group amid fatal syntax/encoding errors | `malformed` | unknown and fail closed |

The parser still uses valid lines surrounding malformed lines, as RFC 9309 requires. An immutable fetched or
unavailable snapshot is not used for new crawl decisions after 24 hours; it becomes
`robots_snapshot_stale`/unknown. Network failures remain unknown rather than silently becoming permission.

## Parsing and matching

The versioned parser implements case-insensitive exact product-token selection, merged repeated matching
groups, `*` fallback only when no exact group exists, and the final empty-group allow behavior. Matching starts
at the first request-path octet, includes the query when present, is case-sensitive, normalizes UTF-8 and
percent-encoded octets, supports `*` and terminal `$`, chooses the most specific match, and lets `Allow` win an
equivalent tie. `/robots.txt` is implicitly allowed.

The matching algorithm does not compile customer input into regular expressions. Input is bounded to 500 KiB,
20,000 lines/rules, 2,000 groups/warnings, 2,048 bytes per rule and 100 unique sitemap records. Empty rules and
orphan rules are ignored. These limits bound CPU, memory and persisted diagnostics while meeting RFC 9309's
minimum processing size.

## Snapshot and decision provenance

`crawl_robots_snapshots` stores one row for each `(scan, origin digest)`. It repeats the exact tenant,
project, property and environment identity and has a composite foreign key to that scan. A snapshot records the
retrieval status/time, initial and final URL, status code, redirect count, SHA-256 response hash, parser version,
bounded normalized groups, sitemap candidates and warning codes. It never stores the raw robots response.
PostgreSQL checks payload/result shape and an immutable trigger rejects updates or ordinary deletes. The
resource-deletion workflow is the only deletion path.

Each evaluation returns `allowed`, `denied`, or `unknown` with a stable reason, snapshot ID, parser version,
artifact hash, retrieval time, evaluated canonical URL and matched rule when one exists. Unknown never permits a
fetch. A retry reuses the exact scan/origin snapshot and verifies the digest collision against the stored origin.

## Owner override and sitemap trust

New policies default to `respect`. `verified_owner_override` can be persisted only when the exact property has a
current verified-owner observation and the effective `crawl.custom_rules` entitlement enables the control.
Policy writes, scan snapshots and admission recheck both conditions; the immutable scan policy records the
choice. The override affects only the robots decision. URL scope, public DNS/address classification, redirect,
timeout, byte, quota and resource-state checks continue to apply.

`Sitemap` records are merely normalized discovery candidates. Invalid schemes, credentials, IP literals and
malformed URLs are omitted, but a syntactically public cross-origin URL is still marked `trusted: false`.
Reading a directive performs no fetch. Prompt 067 owns XML retrieval, same-scan scope validation and bounded
parsing.

## Migration and operations

Migration `20260904151000_create_crawl_robots_snapshots.rb` creates a new empty table, indexes, composite scan
foreign key, checks and immutable trigger, and expands the existing crawl-policy robots allowlist. There is no
row backfill or large-table rewrite. Adding the foreign key and replacing the policy check briefly lock their
tables; deploy under the standard migration lock/statement timeouts. Rollback removes robots provenance and is
appropriate only before snapshots are relied upon.
