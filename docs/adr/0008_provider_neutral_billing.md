# ADR 0008 — Provider-neutral billing with Lemon Squeezy first

- Status: Accepted
- Date: 2026-09-04
- Owners: Billing
- Last reviewed: 2026-09-04 (Prompt 047)

## Context

The product needs hosted checkout and subscription lifecycle now, but core access decisions must not depend directly on a provider payload or product/variant ID.

## Decision

Define an internal billing interface and canonical subscription model. Implement Lemon Squeezy as the first adapter. Persist signed webhook events durably, project them idempotently and reconcile periodically. Map provider variants to immutable internal plan versions.

## Consequences

- A later Stripe or other adapter does not rewrite entitlement logic.
- Webhook ordering and reconciliation remain explicit.
- Provider-specific checkout/tax/invoice UX can still differ behind the adapter.
- Billing state is provider-informed; access state is determined by canonical application policy.

## Implementation status

Prompt 043 defines immutable normalized adapter values, bounded failure categories and operation transport
policies; supplies a deterministic development/test fake; adds tenant/provider/environment customer mappings;
and expands the local subscription into separately constrained canonical status and access state. Provider raw
status is bounded metadata, hosted links and identifiers redact themselves, and the access/entitlement domains
remain provider-free. Prompt 044 supplies the first production adapter and later prompts own webhook projection
and reconciliation workflows.

Prompt 044 implements the Lemon Squeezy JSON:API adapter, exact store/product/variant and environment mapping,
bounded TLS transport, short safe-GET retries, redacted request metrics and sanitized fixtures. Lemon Squeezy
does not document provider-side mutation idempotency, so the adapter deliberately performs no automatic
mutation retries and treats the hashed local key as correlation only.

Prompt 046 persists verified exact bodies before enqueue. Prompt 047 projects those records through the
provider-neutral event value: provider/customer/plan/environment mappings and signed checkout custom data are
revalidated, canonical subscription rows are locked, provider timestamps plus a deterministic restrictive
tie-break prevent stale downgrade, and entitlement context changes only with canonical access inputs. Order
and subscription-invoice events are observations because Lemon Squeezy also emits an authoritative
`subscription_updated` snapshot for lifecycle changes.

The canonical lifecycle is an explicit transition matrix rather than a direct provider-status assignment.
Billing records exact provider periods and cancellation deadlines, applies a seven-day local delinquency grace
policy, and evaluates deadline expiry at request time. Plan changes are durable local intents submitted
asynchronously, but only a validated provider event may switch the immutable plan version. Subscription and
entitlement context move atomically, usage reservations retain their admission snapshot, and durable lifecycle
notifications use the shared PostgreSQL outbox.
