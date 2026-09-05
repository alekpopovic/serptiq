# Bounded crawler HTTP fetcher

Prompt 069 adds the Crawling-owned GET/HEAD operation on top of the approved
destination boundary from Prompt 068. Prompt 071 makes an exact frontier-lease
`permit_context` mandatory at `Crawling::Public.fetch_http`; each request,
redirect and retry must acquire PostgreSQL pressure capacity before resolution.
The operation returns an immutable normalized result and never performs
destination resolution or a connection outside `Shared::NetworkSafety`.

## Request and redirect contract

Only GET and HEAD are accepted, so the bounded transient retry policy never
replays a non-idempotent method. Every network attempt obtains a fresh
`ApprovedDestination`, connects to its selected IP address and preserves the
canonical DNS name for `Host`, TLS SNI and certificate hostname verification.
TLS peer verification is mandatory and TLS 1.2 is the minimum; there is no
runtime switch that disables verification.

Redirects are not followed by the transport. Crawling parses each `Location`,
rejects credentials, fragments, unsupported schemes, HTTPS downgrade and
unapproved origins, then repeats DNS/address approval before the next request.
The default allowlist contains only the initial origin. A caller may provide an
explicit set of already crawl-authorized origins. Each attempted request has a
bounded hop value with status, safe redirect target, outcome, timing/size facts
and count-only resolution-policy provenance. URLs and addresses are excluded
from structured telemetry.

## Resource limits and streaming

The transport applies separate connect, TLS, complete-header and complete-body
deadlines under one total fetch deadline. Header fields/count/bytes, compressed
response bytes, decoded bytes, compression ratio, redirect count, retry count
and retry delay are independently bounded. Supported content encodings are
`identity`, `gzip` and `deflate`; unknown, malformed or excessive encodings are
rejected. Chunked response chunks are streamed in fixed-size reads instead of
being buffered according to an attacker-provided chunk length.

Decoded bytes are hashed while being passed to the caller-owned sink in chunks
of at most 16 KiB. The transport retains only a 512-byte content sample for
defensive type classification. It does not retain a response body. Redirect,
retry and rejected content sinks are aborted. Prompt 070 supplies private
object-storage sinks; Prompt 073 persists normalized fetch and artifact
references with frontier orchestration. Large content is never stored in
PostgreSQL by this operation.

The response exposes only bounded allowlisted headers plus normalized media
type, charset, content encoding, status, sizes, SHA-256 and a coarse sniffed
kind. A strong conflict such as declared HTML with a PDF signature is rejected
as `content_type_mismatch`; content sniffing is an observation, not proof that
untrusted content is safe.

## Retry, cancellation and outcomes

Transport retries are disabled. The higher-level fetcher retries only GET/HEAD
after explicitly classified transient network failures or statuses 408, 425,
429, 500, 502, 503 and 504. It performs at most the configured retry count,
caps exponential/`Retry-After` delay, obtains a fresh destination decision and
rechecks both cancellation and the total deadline. Default backoff waits poll
cancellation at most every 100 ms. Certificate, malformed, oversize,
decompression, encoding, redirect and content-type failures are not retried.

Normalized outcomes are `succeeded`, `http_error`, `rejected`, `failed`,
`canceled` and `throttled`, with a stable failure category. A pressure denial
returns `throttled` without DNS or transport activity; orchestration uses its
durable scan observation to schedule a later attempt. The final result is not itself
retryable; orchestration must make any later durable retry decision explicitly.
Every call emits a bounded `crawler.http_fetch` event containing method,
outcome, category, status, duration and retry count only.

Every transport response or classified network failure releases its opaque
permit and supplies bounded status/failure evidence. HTTP 429/503 and valid
`Retry-After` signals update host backoff. Release failure is reported without
payload data; permit expiry remains the safe capacity-recovery boundary. See
[`CRAWL_PRESSURE_CONTROLS.md`](./CRAWL_PRESSURE_CONTROLS.md).

## Operator settings

The public `SEARCHOPS_CRAWLER_*` settings in `.env.example` control DNS,
connect, TLS, header, body and total deadlines; header, compressed and decoded
size limits; decompression ratio; redirects; and safe retry/backoff limits.
Defaults are conservative application limits. Infrastructure timeouts and the
default-deny crawler egress policy may be stricter.

The request identifies itself as `SearchOpsBot/1.0` and includes the configured
application `/crawler` contact URL unless the caller supplies another valid
HTTP(S) contact URL. It never submits forms, authenticates or executes page
JavaScript.

## Verification

The local hostile HTTP/TLS fixtures exercise exact IP pinning with the expected
Host header, GET/HEAD behavior, gzip decoding, unsupported encodings,
decompression bombs, oversized headers/bodies, slow headers/bodies, trusted,
untrusted and wrong-host certificates, redirect rejection/loops, transient
retry, fresh resolution, cancellation, media-type mismatch and fixed-size
streaming. The security-contract CI job runs the destination corpus and both
the transport and fetcher tests.

Prompt 073 supplies a usage context and exact frontier permit for static page
work. Every redirect/retry hop obtains both before DNS/transport; quota denial
returns without a network call. Its immutable normalized result is persisted in
`crawl_fetch_results`, while successful HTML bodies use private artifacts and
exact `crawl_page_snapshots` references. Robots and sitemap clients use a
pre-request observer with the same per-hop usage contract.
