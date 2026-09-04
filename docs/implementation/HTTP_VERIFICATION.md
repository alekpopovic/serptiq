# HTTP ownership verification

Prompt 055 implements HTML-file and static meta-tag proof through the shared outbound network-safety boundary.
Both methods remain exact, origin-bound observations: success proves that the challenge value was served at one
approved public origin at one point in time. It does not declare the site, every URL on it, or later responses safe.

## Exact proof contracts

The HTML-file method requests only `/.well-known/searchops-verification.txt` below the challenge's immutable
normalized origin. The response must be `text/plain`, and its entire byte string must equal the displayed
`searchops-verification=<43-character base64url value>`. A trailing newline, surrounding whitespace, markup,
case change or partial match fails.

The meta method requests only `/` below that origin and accepts `text/html`. Nokogiri parses the returned source
without a browser or script execution. Exactly one static `<meta name="searchops-verification" content="…">`
element must exist, and its `content` must exactly equal the challenge value. Missing, duplicate, differently
cased and whitespace-altered values fail.

The existing challenge aggregate supplies the high-entropy one-time value, stores only its SHA-256 digest,
serializes consumption, and enforces retry spacing, attempt limits, expiry, idempotent success and tenant/origin
binding. Page bodies and proof values are never persisted as evidence.

## Safe destination and redirect policy

`Shared::Public.safe_http_client` exposes the centralized `Shared::NetworkSafety` destination boundary used here
and reserved for the crawler. It:

- accepts normalized HTTP/HTTPS DNS hostnames without credentials, fragments or IP literals;
- permits only the effective ports 80 and 443;
- resolves all A/AAAA answers, rejects the entire destination if any answer is non-public, and caps answers;
- pins the connection to an approved address while retaining TLS hostname verification;
- re-resolves and revalidates every redirect before connecting;
- caps DNS, open and read time, response bytes and redirects;
- streams the body and rejects a disallowed or malformed content type.

Verification redirects preserve the exact requested path, contain no query or fragment, never downgrade HTTPS,
and may target only explicitly enumerated canonical variants: the same host's HTTP-to-HTTPS origin and one
literal `www.` add/remove variant. Arbitrary subdomains, path changes, cross-site redirects and redirects to
private, loopback, link-local, metadata, multicast, reserved or mixed public/private resolutions are rejected.
Production egress controls remain required as defense in depth.

## Evidence and operations

Retained evidence is restricted to bounded status, byte/redirect/meta counts and booleans describing path,
origin, content-type, destination and exact-value decisions. Network errors expose a fixed category and safe
boolean/count evidence only; URLs, IP addresses, headers and response bodies are not copied into records or UI
messages.

Runtime controls are `SEARCHOPS_HTTP_VERIFICATION_ENABLED`, `SEARCHOPS_VERIFICATION_HTTP_DNS_TIMEOUT`,
`SEARCHOPS_VERIFICATION_HTTP_OPEN_TIMEOUT`, `SEARCHOPS_VERIFICATION_HTTP_READ_TIMEOUT`,
`SEARCHOPS_VERIFICATION_HTTP_MAX_RESPONSE_BYTES` and `SEARCHOPS_VERIFICATION_HTTP_MAX_REDIRECTS`. The default
test environment disables live fetches; adapter and security tests inject deterministic transports and the shared
malicious-response fixtures.

Migration `20260904142000_expand_http_verification_failures.rb` replaces the two verification failure-category
checks with allowlists that include the bounded HTTP categories. Each check replacement briefly takes the normal
PostgreSQL DDL lock and validation scans the existing verification table; deploy before attempt history is large.
Rollback restores the DNS-era allowlists and therefore requires that no row retains a newer HTTP category.
