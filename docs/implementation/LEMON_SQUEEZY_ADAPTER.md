# Lemon Squeezy billing adapter

Checked against the official API documentation on **2026-09-04**. `Billing::LemonSqueezyProvider` is the
first production implementation of the provider-neutral contract. It uses the fixed
`https://api.lemonsqueezy.com` origin, JSON:API media type and Bearer authentication. Credentials are loaded
only from the application secrets contract and adapter diagnostics always redact them.

## Supported transport operations

| Application operation | Provider request | Automatic retries |
|---|---|---:|
| create checkout | `POST /v1/checkouts` | 0 |
| customer portal | `GET /v1/customers/:id` and `attributes.urls.customer_portal` | 0 |
| fetch subscription | `GET /v1/subscriptions/:id` | at most 2 |
| change plan | `PATCH /v1/subscriptions/:id` with `variant_id` | 0 |
| cancel at period end | `DELETE /v1/subscriptions/:id` | 0 |
| resume during grace period | `PATCH /v1/subscriptions/:id` with `cancelled: false` | 0 |
| reconciliation page | filtered `GET /v1/subscriptions` | at most 2 |

The API documentation does not declare a mutation idempotency header. SearchOps therefore never retries a
Lemon Squeezy mutation automatically. The required local idempotency key becomes a one-way `X-Request-ID`
correlation digest; checkout custom data receives the same kind of one-way operation identifier. This
supports webhook correlation but does not misrepresent provider-side deduplication. A timeout after a
mutation is an uncertain outcome and must be resolved by reconciliation.

Open, read and write timeouts are independently bounded. Net::HTTP implicit retries are disabled, TLS peer
verification is mandatory, request bodies are capped at 64 KiB and streamed response bodies default to
512 KiB. Only JSON:API responses are accepted. `429` responses retain a bounded `Retry-After`; safe GETs
retry only when the indicated delay is at most two seconds. Authentication, authorization, validation, not
found, response-shape and environment mismatches are terminal.

Each attempt emits `billing.provider_request` with provider, operation, outcome, duration, retry count,
status and safe error category. Headers, URLs, request/response bodies, customer identifiers, email, API key,
webhook secret and local idempotency key are never event attributes.

## Catalog and lifecycle mapping

Every active Lemon Squeezy plan mapping must contain a numeric store, product and variant ID alongside the
exact internal plan version, environment, currency and interval. The configured store, response store,
response product and response variant must match one active row. Test/live response mode must match the
application environment. Any mismatch fails closed before a normalized subscription is produced.

Provider status is retained as `metadata.raw_status` and mapped as follows:

| Lemon Squeezy observation | Canonical status | Access state |
|---|---|---|
| `on_trial` | `trialing` | `full` |
| `active` | `active` | `full` |
| `past_due` | `past_due` | `grace` |
| `unpaid` | `past_due` | `read_only` |
| `paused` (`free`) | `paused` | `read_only` |
| `paused` (`void`) | `paused` | `suspended` |
| `cancelled` | `canceled` | `full` until provider end |
| `expired` | `expired` | `read_only` |

Lemon Squeezy does not expose a dedicated cancellation timestamp on the subscription object. For a
`cancelled` observation, SearchOps records `updated_at` as the observation time and explicitly labels the
source in bounded metadata. `renews_at` is not treated as proof of the period start, so both normalized
period endpoints remain absent rather than inventing one.

## Webhook boundary and fixtures

The adapter verifies `X-Signature` as HMAC-SHA256 over the exact bounded raw body with constant-time
comparison. Parsing happens only after verification, accepts the required subscription/payment event names,
checks store/test mode, and retains an allowlisted correlation subset. Durable ingress, idempotent storage
and asynchronous projection belong to Prompts 046 and 047.

Default tests never call the provider. Sanitized JSON:API fixtures cover checkout, portal, active/cancelled/
expired subscriptions, reconciliation pagination, validation, authentication, not found, rate limit,
server failure and malformed responses. Fixture names and bodies contain no production IDs, credentials or
personal data.

## Migration impact

`20260904094000_add_lemon_squeezy_mapping_coordinates.rb` adds two nullable columns, two validated checks and
a partial unique index to the small mapping table. Existing provider-neutral mappings remain valid with both
coordinates absent; Lemon Squeezy rows require both. PostgreSQL validates the checks and builds the index
while writes may briefly wait. On a large mapping catalog, deploy the index concurrently and validate checks
in a separate maintenance step.
