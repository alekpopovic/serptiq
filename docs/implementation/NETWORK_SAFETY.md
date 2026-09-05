# Public destination and connection safety

Prompt 068 establishes the single SSRF boundary for customer-controlled HTTP
destinations. Verification and Crawling consume it through `Shared::Public`;
application code must not create another direct target HTTP client.

An approved destination is a point-in-time network-policy observation. It does
not prove ownership, establish that a site is trustworthy or authorize later
DNS answers, redirects, browser subresources or requests.

## Decision pipeline

Each request follows one ordered pipeline:

1. parse and canonicalize one HTTP(S) DNS target;
2. allow only effective ports 80 and 443;
3. query both A and AAAA with a bounded answer count and timeout;
4. classify every returned address under policy version
   `iana-special-purpose-2025-10-09`;
5. reject the whole destination when any answer is disallowed;
6. return an immutable approved IP set, port and safe resolution provenance;
7. connect to one member of that set while retaining the canonical DNS name
   for the `Host` header, TLS SNI and hostname verification; and
8. verify the connected peer before reading a streamed, size-bounded response.

The parser lowercases and converts IDNA hostnames to ASCII, removes one terminal
DNS dot and rejects credentials, fragments, unsupported schemes, IP literals,
zone identifiers, single-label names, ambiguous authority syntax, whitespace,
backslashes, and integer/octal/hexadecimal-looking address forms. DNS is never
consulted when the URL or port is already invalid.

The address policy rejects loopback, private, shared, link-local, unspecified,
multicast, documentation, benchmarking, reserved and metadata-capable ranges.
IPv4-mapped IPv6 is normalized and evaluated as IPv4. IPv4-compatible IPv6,
NAT64 translation prefixes, 6to4 and special-purpose IPv6 blocks are rejected
conservatively. The explicit globally reachable exceptions in the current IANA
special-purpose registries remain allowed. Any registry update requires a
policy-version change, fixtures and review.

## Redirect and transport contract

Every redirect is parsed, resolved and classified from scratch. There is no
process-global DNS decision cache. Redirect policy caps hops, forbids
credentials/fragments and HTTPS downgrade, and selects either an exact
verification allowlist or the bounded public mode used by Crawling. A prior
approval is never reused for the next hop.

The crawler production transport accepts only an `ApprovedDestination`; it
does not resolve the host again. Its raw bounded HTTP/1.1 socket connects to the
approved IP while retaining the original hostname for `Host`, TLS SNI and
certificate verification. It does not use environment proxy routing or
automatic retries. TLS requires peer/hostname verification and TLS 1.2 or
newer. Complete header/body stages, total time, header count/bytes, compressed
bytes, decoded bytes and decompression ratio are independently bounded. A
retry is a new higher-level request and therefore requires a new destination
decision. The earlier small-response verification client remains on its
separately bounded pinned `Net::HTTP` adapter.

`Crawling::HttpFetcher` owns GET/HEAD-only retries, manual redirect policy,
cancellation, normalized metadata and streamed artifact hashing. Its complete
contract is documented in [HTTP_FETCHER.md](HTTP_FETCHER.md).

## Evidence and denial telemetry

Approved results expose only address-family counts, total answer count, port
and address-policy version. Rejections may emit
`crawler.destination_rejected` with a stable reason code, allowlisted denial
stage and the same bounded counts. URLs, hostnames, DNS answers, IP addresses,
headers, response bodies and resolver error text are excluded. Telemetry
failure cannot turn a denial into an approval or break a successful request.

The architecture checker rejects direct customer-target clients under `app/`,
including `Net::HTTP`, raw sockets and common HTTP libraries. Only the shared
network-safety transport and the separately scoped Identity and Billing
provider transports are explicit exceptions.

## Infrastructure egress enforcement

Application checks are reinforced by a dedicated network namespace or
equivalent policy for `worker_crawl` and `worker_render`. The machine-readable
contract is `config/crawler_egress_policy.yml`: default-deny, explicit TCP/UDP
DNS port 53 access to deployment-owned resolver addresses, outbound HTTP(S)
only on ports 80/443, and denial of the documented IPv4/IPv6 special-purpose,
private, reserved and metadata ranges. Infrastructure may be stricter than the
application policy.

`ruby script/validate_crawler_egress_policy.rb` detects drift between the file
and application constants. In staging and production, crawl/render workers
refuse to boot unless `SEARCHOPS_CRAWLER_EGRESS_ENFORCED=true`. This flag is an
operator attestation, not a firewall: deployment must apply and verify the
network policy before setting it. A release is blocked if either the drift
check or an isolated-worker egress probe fails.

## Verification

The security corpus covers URL/parser ambiguities, IANA IPv4/IPv6 ranges,
mapped addresses, mixed answers, rebinding, excessive DNS answers, redirect
revalidation, safe telemetry and randomized reserved/private IPv4 samples.
Loopback-only malicious DNS and HTTP fixtures prove behavior without weakening
production policy. Transport tests separately prove IP pinning with the
canonical `Host` value, TLS certificate/hostname enforcement, fixed-size
streaming, timeout/size/decompression controls and higher-level retry,
redirect and cancellation behavior. CI runs these contracts explicitly, and
`bin/quality` validates both architecture access and the infrastructure policy
file.

There is no database migration or data backfill for this boundary.
