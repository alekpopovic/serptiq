# ADR 0008 — Provider-neutral billing with Lemon Squeezy first

- Status: Accepted
- Date: 2026-09-04
- Owners: Billing
- Last reviewed: 2026-09-04 (Prompt 044)

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
