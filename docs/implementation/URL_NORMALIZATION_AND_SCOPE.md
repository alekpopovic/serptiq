# URL normalization and crawl scope

Prompt 065 defines version 2 of the deterministic HTTP(S) URL identity used by the crawl frontier. It is a
syntactic identity and scope decision, not a DNS or public-network decision. Every fetch and redirect must still
pass the centralized `Shared::NetworkSafety` resolver and pinned connection policy.

## Fetch URL and identity URL

`Crawling::NormalizedUrl` deliberately carries two values:

- `fetch_url` is the canonical network target: lowercase ASCII-IDNA host, collapsed default port, normalized
  dot segments and percent encoding, original normalized query parameter order and no fragment;
- `identity_url` uses the same origin and path, then applies the scan's query identity policy and deterministic
  ordering. Its version-prefixed SHA-256 digest is the frontier uniqueness key.

The first discovered fetch URL is immutable. Two URLs that differ only by a removed tracking or configured
non-identity parameter can therefore share one frontier identity without rewriting what the first worker will
request. Filtering never mutates the fetch query. A literal `+` is not converted to a space, reserved percent
escapes remain escaped with uppercase hex, duplicate values for one name keep their order, and only distinct
parameter names are sorted. Empty path becomes `/`; literal and percent-encoded dot segments are removed;
percent-encoded slash remains `%2F` and is never treated as a path separator.

`ignore` removes the complete query from identity, `tracking_only` removes bounded known analytics keys and
prefixes, and `all` retains ordinary parameters. An optional exact allowlist narrows identity parameters and an
exact denylist removes named parameters; overlap is rejected and custom lists cannot accompany `ignore`.
Both lists are bounded immutable policy-version fields and are copied into scan settings snapshots.

## Parsing and versioning

Version 2 rejects userinfo, raw/control ambiguity, backslashes, malformed or control percent escapes,
unsupported schemes, absent/unqualified hosts, IP literals and legacy numeric IP spellings, empty/out-of-range
ports, and over-limit URLs or queries. Host IDNA conversion and authority validation reuse the shared HTTP target
contract. Parsing performs no DNS lookup.

The identity input is exactly `crawl-url:v<version>:<identity_url>`. Version 1 remains readable through explicit
fixtures and retains the earlier unfiltered query behavior; new frontier entries use version 2. Changing these
rules requires a new supported version and fixtures rather than rewriting an existing scan's identity.

## Scope decisions

`Crawling::UrlScopePolicy` evaluates in this order: valid non-negative depth, maximum depth, parse/normalize,
scheme, effective port, exact origin or explicitly supplied trusted host, exclude path and include path. Exclude
wins. Allowed hosts are exact normalized hosts and do not imply subdomain, scheme or port expansion. Lookalikes
such as `notexample.com` and `example.com.evil.test` remain outside scope.

The decision is immutable and returns one stable reason code:

- allowed: `same_origin`, `allowed_host`;
- denied: `url_invalid`, `depth_invalid`, `depth_exceeded`, `scheme_out_of_scope`, `port_out_of_scope`,
  `host_out_of_scope`, `path_excluded`, `path_not_included`.

`Crawling::Public.url_scope_for_scan` reloads the exact organization/scan/environment relation and builds the
policy from the immutable scan settings snapshot. A mismatched tenant receives only `url_scope_unavailable`.

## Canonical observations are not authorization

SearchOps URL normalization answers “which crawl identity is this?” An HTML `<link rel="canonical">` is an
untrusted publisher recommendation recorded by later extraction rules. It never expands allowed hosts or paths,
never bypasses robots or budget checks, and never authorizes a redirect or network connection.

## Migration and operations

Migration `20260904150000_add_canonical_url_identity.rb` adds immutable `fetch_url` to the high-volume frontier,
backfills it from the prior identity URL in 10,000-row batches, validates a `NOT VALID` bounded check before
setting `NOT NULL`, and adds two bounded array columns to immutable policy versions. Adding the array columns with
constant empty defaults is metadata-only on supported PostgreSQL. The fetch backfill writes every pre-existing
frontier row and the final nullability change takes a table lock; observe replicas and deploy during a low-write
window if the frontier already contains material data.
