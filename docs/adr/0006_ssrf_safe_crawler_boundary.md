# ADR 0006 — Treat the crawler as an SSRF security boundary

- Status: Accepted
- Date: 2026-09-04
- Owners: Security, Crawling
- Last reviewed: 2026-09-05 (Prompt 066)

## Context

Customers submit URLs and pages may redirect, change DNS answers or reference arbitrary resources. A crawler could otherwise access loopback, private networks, link-local addresses, metadata services or internal control planes.

## Decision

All outbound crawl destinations pass a centralized network-safety policy. Allow only HTTP/HTTPS, normalize hostnames, resolve DNS, reject non-public addresses, connect using validated resolution, re-resolve every redirect, bound redirects/bytes/time and record denials. Run crawl/render workers in networks with defense-in-depth egress restrictions.

Property environment origins are stored in canonical lowercase ASCII IDNA form with effective ports and a
separate derived Unicode display form. Origin admission rejects credentials, non-root URL components, IP
literals, unqualified/internal names and ambiguous authority syntax. This admission parser is not SSRF
authorization; the outbound worker still performs the full resolution and connection policy above.

Prompt 055 establishes that central policy as `Shared::NetworkSafety`, exposed through
`Shared::Public.safe_http_client`, and its pinned `Net::HTTP` transport.
HTML ownership verification is its first production consumer; Crawling must reuse this boundary rather than
introducing a direct customer-target HTTP client. Verification may redirect only to an explicitly enumerated
same/canonical-host variant, with exact path preservation, no query/fragment and no HTTPS downgrade.

Prompt 065 adds the Crawling-owned versioned syntactic identity above this boundary. It preserves a normalized
fetch URL separately from the query-filtered identity URL and returns explicit host/path/depth scope decisions.
Neither deduplication nor an HTML canonical observation authorizes DNS answers, redirects or connections.

Prompt 066 adds the bounded public-redirect mode needed by RFC 9309 robots retrieval. Crawling fixes the initial
target to the exact origin's `/robots.txt`; Shared requires that initial origin and parses, re-resolves,
public-address checks and connects every HTTP(S) redirect through the pinned transport. Cross-authority
redirects are allowed only through those checks, the chain is capped at five and HTTPS downgrade is rejected.
Shared owns those connection decisions; Crawling owns the crawler identity, robots status policy, parser and
immutable provenance.

## Consequences

- The HTTP client cannot be used directly for customer targets.
- DNS and IP parsing edge cases receive security regression tests.
- Domain verification is required before high-volume or rendering work.
- Some legitimate private/internal-site auditing is outside MVP scope.
