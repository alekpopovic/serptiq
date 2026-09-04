# Identity provider adapter boundary

The Identity module owns a deliberately small sign-in adapter contract. An
adapter builds an `Identity::AuthorizationRequest` and exchanges a validated
`Identity::CallbackInput` for an `Identity::CallbackExchange`. The exchange
contains a bounded `Identity::NormalizedIdentity` and, only for an OIDC
provider, verified `Identity::OidcClaims`. Failures use stable
`Identity::ProviderError` categories: `access_denied`, `configuration`,
`credentials_revoked`, `malformed_response`, `rate_limited`, `timeout`, and
`unavailable`.

These values are protocol observations, not local account decisions. Provider
subjects and profile fields remain untrusted until their provider adapter has
completed all applicable verification. The shared adapter interface never
creates or links a user, organization, membership, or session. Instead,
`Identity::Public.resolve_account` returns a side-effect-free decision keyed
first by the exact provider and stable subject. A verified email collision
returns `explicit_link_required`; it never merges accounts automatically.
Actual linking requires the later recent-authenticated, explicit-intent flow.

## Provider protocol profiles

The registry accepts only `google` and `github`, and configurations are built
from application-controlled definitions. Callback input and provider payloads
cannot replace any endpoint.

| Purpose | Google OIDC | GitHub OAuth |
|---|---|---|
| Issuer | `https://accounts.google.com` | not applicable |
| Discovery | `https://accounts.google.com/.well-known/openid-configuration` | not applicable |
| Authorization | `https://accounts.google.com/o/oauth2/v2/auth` | `https://github.com/login/oauth/authorize` |
| Token | `https://oauth2.googleapis.com/token` | `https://github.com/login/oauth/access_token` |
| JWKS | `https://www.googleapis.com/oauth2/v3/certs` | not applicable |
| User | `https://openidconnect.googleapis.com/v1/userinfo` | `https://api.github.com/user` |
| Verified email lookup | part of verified OIDC/user information policy | `https://api.github.com/user/emails` when needed and authorized |
| Callback | exact configured origin plus `/auth/google/callback` | exact configured origin plus `/auth/github/callback` |

Both protocols require an authorization-code flow, exact callback and PKCE.
Google additionally requires nonce and validated OIDC claims. GitHub is OAuth,
not OIDC, and must not fabricate issuer, JWKS, nonce, ID-token, or OIDC-claim
semantics. Full Google signature/claim verification and GitHub response mapping
are implemented by the following provider-specific prompts.

## HTTP boundary

The provider HTTP client accepts only the configuration object's exact HTTPS
endpoint strings. It does not follow redirects. The production transport uses
peer-verified TLS, explicit open/read timeouts and streaming response limits.
Successful responses must be a bounded JSON object with an
`application/json` or `application/*+json` content type and a maximum nesting
depth.

Only idempotent GET requests labelled `discovery` or `jwks` may retry timeout,
rate-limit or availability failures. Retries are capped by configuration (zero
through three), use bounded exponential delays, and honor `Retry-After` only
when it is at most two seconds; longer provider limits return immediately to
the caller. Authorization-code token exchange and profile/email requests never
retry inside this client because replay and provider semantics need explicit
higher-level handling.

Default bounds are a 2-second open timeout, 5-second read timeout, 256 KiB
response limit and two safe retries. Runtime overrides use
`SEARCHOPS_OAUTH_HTTP_OPEN_TIMEOUT`, `SEARCHOPS_OAUTH_HTTP_READ_TIMEOUT`,
`SEARCHOPS_OAUTH_HTTP_MAX_RESPONSE_BYTES`, and
`SEARCHOPS_OAUTH_HTTP_SAFE_RETRIES`.

Errors expose category, stable operation, retryability and an optional numeric
retry delay. They never include callback codes, tokens, client secrets,
provider bodies, request forms or unsafe endpoint input. Authorization,
callback, identity, claim and HTTP response objects also provide safe
diagnostic `inspect` output. Operators should still pass structured fields
through the shared redaction boundary and must never log raw provider payloads.

## Adding a provider

Every provider addition requires all of the following in one reviewed change:

1. Extend the database and application provider allowlists with a migration
   safety assessment; do not accept arbitrary provider names.
2. Add immutable application-owned definitions for the issuer and every
   authorization, token, discovery, JWKS, user/email and exact callback
   endpoint. Reject provider- or callback-supplied endpoint substitutions.
3. Document whether the protocol is OAuth or OIDC and model its distinct state,
   nonce, PKCE, signature, issuer, audience, time and verified-email rules
   without weakening another provider's contract.
4. Implement the adapter with the bounded HTTP client, strict payload schemas,
   stable subject selection and allowlisted normalized profile fields.
5. Add public enable/client-ID configuration and a separately injected secret;
   verify all config/error/log representations redact credentials and tokens.
6. Add a deterministic fake and run the shared contract for success, denial,
   malformed response, timeout, rate limiting and revoked credentials. Add
   provider-specific replay, claim, payload and endpoint negative tests.
7. Keep account creation/linking and session issuance in explicit Identity
   domain operations. Test email collision, recent-authenticated explicit
   linking, revocation and absence of organization/membership side effects.
8. Update integration, security, operations and source-reference documentation,
   then run eager loading, architecture, full Rails, lint and security checks.

Default tests use only deterministic fakes and sanitized synthetic payloads;
they never contact Google or GitHub.

## Google authorization initiation

`POST /auth/google` is the only Google sign-in initiation endpoint. Keeping the
state-changing start behind a POST preserves Rails CSRF protection. It creates
independent 256-bit state and nonce values plus a 512-bit PKCE verifier, derives
the S256 challenge, and returns a `303 See Other` to the immutable Google
authorization endpoint. The query contains the exact configured client ID and
callback, `response_type=code`, `scope=openid email profile`, state, nonce,
challenge and `code_challenge_method=S256`. A caller-supplied callback is never
read.

The PostgreSQL transaction stores keyed state/nonce/verifier digests and an
authenticated verifier ciphertext; only state, nonce and the derived challenge
leave in the Google authorization URL. Raw values, the raw initiator address
and the complete authorization URL are excluded from pages and structured
events. OAuth responses set `Cache-Control: no-store`, `Pragma: no-cache`, an
expired `Expires`, `Referrer-Policy: no-referrer`, `nosniff` and frame denial.

`return_to` passes the shared local `/dashboard` allowlist. `link=1` is an
explicit intent and is accepted only with an active local session authenticated
in the last 15 minutes; the transaction stores a restrictive foreign key to that
exact session. An authenticated request without explicit link intent is
rejected rather than silently switching accounts. The callback implementation
must revalidate this binding before any identity mutation.

Initiations are serialized with PostgreSQL transaction advisory locks and
bounded by keyed canonical-IP and, for linking, session dimensions. Defaults
allow 20 starts per IP and 10 per link session within five minutes, with at
most five open attempts per IP and two per link session. These values are
runtime configuration, and every denial returns the same public `rate_limited`
response. Expired or consumed transaction records older than the configured
24-hour retention are opportunistically deleted under the same lock.

The callback route exists so the configured URI is exact, but its protocol
exchange intentionally remains closed until Prompt 018 implements state,
nonce, PKCE and ID-token validation.
