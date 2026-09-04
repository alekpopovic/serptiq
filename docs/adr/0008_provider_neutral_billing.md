# ADR 0008 — Provider-neutral billing with Lemon Squeezy first

- Status: Accepted
- Date: 2026-09-04

## Context

The product needs hosted checkout and subscription lifecycle now, but core access decisions must not depend directly on a provider payload or product/variant ID.

## Decision

Define an internal billing interface and canonical subscription model. Implement Lemon Squeezy as the first adapter. Persist signed webhook events durably, project them idempotently and reconcile periodically. Map provider variants to immutable internal plan versions.

## Consequences

- A later Stripe or other adapter does not rewrite entitlement logic.
- Webhook ordering and reconciliation remain explicit.
- Provider-specific checkout/tax/invoice UX can still differ behind the adapter.
- Billing state is provider-informed; access state is determined by canonical application policy.
