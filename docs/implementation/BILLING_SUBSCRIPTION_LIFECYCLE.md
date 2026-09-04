# Billing Subscription Lifecycle and Access

Prompt 048 turns provider-neutral subscription observations into an explicit local access contract. Provider
payloads remain untrusted: the signed webhook pipeline correlates exact environment, customer, subscription and
immutable plan mappings before invoking the transition service.

## Canonical lifecycle

Canonical states are `pending`, `incomplete`, `trialing`, `active`, `past_due`, `paused`, `canceled` and
`expired`. `Billing::SubscriptionLifecycle` owns the complete transition matrix. Self-transitions support
idempotent corrections; recovery to `active` is allowed from delinquent, paused, canceled and expired states.
Impossible regressions such as `active` to `trialing` become terminal projection failures rather than inferred
repairs.

| Status/access | Request-time behavior |
|---|---|
| pending or incomplete / pending | billing and remediation only |
| trialing or active / full | ordinary RBAC, entitlement, resource and quota checks |
| past_due / grace | reads and interactive entitled work; scheduled work paused |
| past_due / read_only | reads, export, billing and remediation only |
| paused / read_only or suspended | retention-safe reads when read-only; otherwise remediation only |
| canceled / full | ordinary access until exact `access_expires_at` |
| canceled or expired / read_only | retention-safe reads, export, billing and remediation only |

Past-due grace lasts seven days from the authoritative provider observation unless the adapter already reports
read-only access. Cancellation access expires at the exact provider end. These deadlines are checked on every
access decision, so session age or delayed cache invalidation cannot extend access. Evaluation order is active
membership, RBAC, subscription access, entitlement, resource state and quota.

Subscription and entitlement context changes occur in one PostgreSQL transaction. The context stores canonical
status/access/deadlines and subscription lock revision. Expired contexts remain available to enforce
retention-safe reads rather than silently granting a free plan or deleting data.

## Plan changes and reservations

`billing_subscription_changes` records one active intent per subscription with tenant-bound requester,
source/target plan versions, hashed idempotency evidence, exact policy/time and lifecycle timestamps. Upgrades
dispatch immediately; downgrades dispatch at the confirmed period end. Provider operations use the mapped
opaque variant and are not automatically retried inside the adapter. A submitted mutation is not proof of
access: only a later canonical provider event can confirm the exact target mapping and change plan/access.

Usage windows and quota reservations keep the plan version, subscription revision, entitlement provenance and
limit captured at admission. Their independent tenant/subscription and plan-version constraints allow a live
subscription to move plans without rewriting those immutable snapshots.

## Audit, outbox and UI

Requests, provider submissions and applied transitions create bounded audit evidence. Lifecycle and plan-change
facts are inserted into `outbox_events` in the canonical transaction. The publisher locks a row, instruments a
versioned envelope, marks successful delivery and stores a bounded failure category for retry. Hashed keys and
bounded payloads exclude provider raw bodies and credentials.

The plan page describes the latest confirmed local observation and exact locally recorded effective time. It
directs payment, invoice and tax questions to the provider portal. The browser requests intent but cannot
mutate canonical subscription state.

## Migration and operations

Migration `20260904102000` adds access deadlines and constrained subscription-change/outbox tables. It replaces
foreign keys, so it briefly acquires PostgreSQL DDL locks and should run outside peak subscription/quota writes.
For mature tables, split column addition, backfill and validation into staged deploys. Rollback after a real plan
change can be unsafe: the former composite usage foreign key required every historical reservation plan to equal
the subscription's current plan. Reconcile snapshots or restore from backup before attempting that downgrade.
