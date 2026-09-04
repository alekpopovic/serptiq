# Provider-neutral billing contract

Billing owns provider identities, hosted links and lifecycle observations. Plans remains the source of stable
commercial versions, Entitlements consumes only the local subscription projection, and Authorization never
imports a provider class or variant/customer/subscription identifier. Provider availability is not a
synchronous prerequisite for ordinary access decisions; the last trusted local projection remains the input.

## Normalized boundary values

Adapters accept and return immutable Billing values:

| Value | Purpose |
|---|---|
| `Customer` | Provider customer reference correlated to exactly one organization and environment |
| `CustomerRequest` | Redacted provider-customer creation input bound to one local organization |
| `CheckoutRequest` / `CheckoutResult` | Exact internal plan target, opaque mapped variant and hosted checkout handoff |
| `SubscriptionSnapshot` | Canonical status/access state plus provider timing and bounded provider facts |
| `InvoiceTransactionLink` | Short-lived invoice or transaction document handoff |
| `PortalLink` | Short-lived hosted customer-portal handoff |
| `VerifiedWebhook` / `ProviderEvent` | Exact verified body followed by a payload-free canonical event |
| `ReconciliationResult` | Bounded aggregate outcome with no customer identifiers |

Opaque customer, subscription, variant, event and checkout references are identifiers, not credentials. They
stay inside Billing. Hosted URLs can contain bearer material and all normalized values therefore provide
redacted `as_json`/`inspect` representations. Email, raw webhook bodies, metadata and idempotency keys are
also absent from diagnostic serialization. Metadata accepts only bounded nested scalar data (4 KiB maximum);
raw provider payloads never cross the adapter boundary.

`SubscriptionSnapshot#metadata["raw_status"]` preserves the exact provider observation. Application
`status` and `access_state` are separate canonical facts, so customer UI must say “reported by the billing
provider” for raw status and must not present it as an access guarantee.

## Operations and transport policy

`Billing::Provider` defines checkout creation, portal link creation, subscription fetch/change/cancel/resume,
bounded reconciliation pages, webhook verification and canonical event parsing. Change/cancel/resume may return `unsupported_operation` for
a provider that cannot support the requested transition; capability checks remain explicit.

| Operation | Method | Open/read timeout | Response cap | Safe retries | Idempotency |
|---|---|---:|---:|---:|---|
| create customer | POST | 2s / 5s | 512 KiB | 0 | required local key |
| create checkout | POST | 2s / 5s | 512 KiB | 1 | required provider key |
| customer portal | POST | 2s / 5s | 512 KiB | 0 | required request key |
| fetch subscription | GET | 2s / 5s | 512 KiB | 2 | naturally safe |
| change subscription | PATCH | 2s / 5s | 512 KiB | 1 | required provider key |
| cancel subscription | DELETE | 2s / 5s | 512 KiB | 1 | required provider key |
| resume subscription | PATCH | 2s / 5s | 512 KiB | 1 | required provider key |
| reconciliation page | GET | 2s / 5s | 512 KiB | 2 | naturally safe |
| verify/parse webhook | local | bounded by 512 KiB ingress | 512 KiB | 0 | provider event/fingerprint |

Retries are the maximum additional attempts after the first call. A mutation may be retried only after its
provider idempotency key is attached and the adapter confirms equivalent provider semantics. Lemon Squeezy
does not currently document mutation idempotency, so its adapter uses zero mutation retries and only a
one-way local correlation digest. Timeouts are
categorized as retryable but do not prove the first request failed; reconciliation resolves uncertainty.
Authentication, authorization, signature and malformed-response failures are terminal. Rate limits carry a
bounded `retry_after` when the provider supplies one.

## Persistence and lifecycle

`billing_customers` maps one organization/provider/environment to one immutable provider customer identity.
The reverse provider identity is unique in that environment. A composite foreign key requires a provider-backed
subscription to reference a customer with the exact same organization, provider and environment.

`billing_plan_provider_mappings` remains the exact internal plan-version/currency/interval to opaque provider
catalog mapping. Lemon Squeezy rows additionally require numeric store, product and variant coordinates.
Missing, inactive, wrong-store, wrong-product, wrong-environment or wrong-interval mappings fail closed; all
provider coordinates are redacted from projections.

Hosted checkout orchestration creates or reuses the exact tenant customer mapping without searching provider
customers by email. A local `billing_checkout_sessions` row reserves one active handoff per organization before
any provider mutation. It stores only a one-way request digest and opaque checkout reference—never the hosted
URL. Ready and uncertain sessions block duplicates until expiry. Checkout custom data contains the
organization, exact plan version, local session ID and an HMAC correlation value for later verified webhook
processing; the browser return page cannot mutate the subscription projection.

`20260904095000_create_billing_checkout_sessions.rb` creates a new empty table, so it does not rewrite
existing rows. Its foreign keys, checks and indexes are created and validated in the same migration; this
briefly takes catalog locks on the new table and referenced identity/catalog tables. No long-lived checkout
write traffic exists before this table is deployed, so a phased constraint or concurrent-index rollout is
not required for this migration.

Canonical subscription statuses are `pending`, `trialing`, `active`, `past_due`, `paused`, `canceled` and
`expired`. Access states are independently constrained:

| Canonical status | Allowed application access state |
|---|---|
| pending | pending |
| trialing / active | full |
| past_due | grace or read_only |
| paused | read_only or suspended |
| canceled | full until effective end, or read_only |
| expired | read_only |

Provider-backed rows require complete customer/subscription/environment references, provider update/sync
times and bounded metadata containing `raw_status`. Period endpoints are both absent or ordered; trial,
cancellation and terminal timestamps are constrained. Exactly one non-ended subscription may exist per
organization, including a scheduled cancellation. Existing `inactive` rows migrate to `expired/read_only`.

The migration creates a new small mapping table, adds nullable provider columns and constant defaults to the
pre-launch subscriptions table, backfills the old terminal status, replaces the partial current-subscription
index and validates new checks/FKs. Constraint validation and index creation scan/lock the current table; deploy
outside peak subscription writes. A large mature table should add unvalidated constraints and concurrent
indexes in phases.

## Fake and adding a second provider

`Billing::FakeProvider` is available only in development/test. It deterministically exercises every operation,
timeout/rate-limit/auth/malformed/signature failures and unsupported capabilities without network access.

To add a second real provider:

1. subclass `Billing::Provider` under `app/adapters/billing/<provider>/` and declare unsupported transitions;
2. translate only validated provider responses into the normalized values above, retaining required
   provider-specific facts in bounded metadata;
3. enforce the shared operation policies, TLS, size limits, redaction and provider idempotency semantics;
4. implement exact raw-body webhook verification before parsing and map only governed canonical event names;
5. register the adapter key and protected-environment configuration;
6. create environment-specific customer and plan mappings and run the shared adapter contract suite;
7. add provider fixtures/reconciliation tests without changing Plans, Entitlements or access code.

The entitlement resolver continues to read only its tenant-consistent local subscription context. No provider
addition changes entitlement keys, plan-name logic or quota admission.
