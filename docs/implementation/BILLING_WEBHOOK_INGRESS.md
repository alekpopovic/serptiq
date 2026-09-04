# Billing webhook ingress

Checked against the official Lemon Squeezy webhook and signing documentation on **2026-09-04**.
The public endpoint is `POST /webhooks/billing/lemon_squeezy`. It is a small Rack endpoint rather than an
`ActionController` action so Rails does not parse the JSON body for parameter logging before SearchOps reads
and verifies the exact bytes.

## Request boundary

The endpoint reads at most 524,289 bytes and rejects anything above the 512 KiB contract before signature
verification or JSON parsing. Only `application/json` and `application/vnd.api+json` are accepted. It verifies
the lowercase or uppercase 64-character hex value from `X-Signature` against HMAC-SHA256 of the exact received
body using constant-time comparison.

`SEARCHOPS_BILLING_WEBHOOK_SECRET` is the current secret.
`SEARCHOPS_BILLING_WEBHOOK_PREVIOUS_SECRET` may temporarily contain exactly one previous secret during a
controlled rotation. Both comparisons are calculated for every well-formed signature. Remove the previous
secret after Lemon Squeezy has been changed and the bounded provider retry window has elapsed. Never put either
secret in logs, records, support exports or request diagnostics.

Response policy:

| Condition | HTTP response | Durable effect |
|---|---:|---|
| verified new event | 200 | encrypted pending record and projection job |
| byte-identical duplicate | 200 | duplicate counter and idempotent projection enqueue when actionable |
| same logical event identity with different bytes/type | 409 | conflict counter; original evidence preserved |
| missing/invalid signature | 401 | none |
| malformed/unsupported signed payload | 422 | none |
| unsupported media type | 415 | none |
| oversized body | 413 | none |
| queue enqueue unavailable after commit | 503 | pending record remains for provider retry/replay |

All responses are empty and `no-store`. Metrics contain only provider, operation, low-cardinality outcome,
reason and HTTP status. The signature, payload, provider resource IDs, query values and user-agent are never
logged; only a SHA-256 user-agent digest is retained in the bounded header subset.

## Durable evidence and idempotency

`billing_webhook_events` retains the provider/environment, canonical event type, stable event identity,
SHA-256 checksum, encrypted exact body, safe header facts, receipt times, counters and processing lifecycle.
Lemon Squeezy does not currently send a distinct delivery identifier, so SearchOps derives the stable identity
from signed `event_name`, resource type/ID and provider update timestamp. A changed payload with the same
identity is therefore a visible conflict rather than an overwrite.

The payload uses application-key-derived AES-256-GCM authenticated encryption and is checksum-verified after
decryption. Only Billing code can request decryption. Normal inventory projections deliberately omit the event
reference, raw body and ciphertext. States `pending`, `processing`, `processed`, `retryable` and `dead_letter`,
plus replay/failure counters and timestamps, provide the foundation for Prompts 047 and 049.

The event transaction commits before `Billing::WebhookProjectionJob` is enqueued. If enqueue fails, the
endpoint returns 503 and a retry can enqueue the still-pending record. Projection/replay code must lock the
record, verify the protected payload again and remain idempotent.

## Operations and migration impact

Alert on elevated signature failures, 413/422 responses, enqueue failures, old pending records, retryable age,
dead letters and any conflicting duplicate. A conflict requires comparing provider dashboard evidence and the
encrypted original through a tightly controlled support workflow; never copy the raw body into tickets.

`20260904100000_create_billing_webhook_events.rb` creates a new empty table. It does not rewrite application
rows. Its indexes and validated checks take only brief catalog locks before webhook traffic is enabled. At
material scale, retention cleanup must delete processed encrypted payloads in bounded batches while retaining
the minimum audit metadata required by policy; the final retention period must be approved before production
webhook activation.

Sources:

- <https://docs.lemonsqueezy.com/guides/developer-guide/webhooks>
- <https://docs.lemonsqueezy.com/help/webhooks/signing-requests>
