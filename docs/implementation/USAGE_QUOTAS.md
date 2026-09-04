# Atomic quota reservations and finalization

Quota is an independent admission control. A caller must already have authenticated the user, validated active
membership and permission, resolved the feature entitlement and checked resource state. `Usage::Public.reserve`
then atomically checks the applicable billing pool and creates the hold; a successful hold is not itself a
charge. No cache counter is authoritative.

## Admission and snapshots

Callers provide a persisted usage window, positive raw estimate, bounded idempotency key, same-organization
`Usage::SourceReference`, explicit expiry and admission time. The service applies the effective immutable meter
rate and stores requested/held values in the meter's billing unit. Expiry must follow admission, remain in the
same window and initially be no more than 24 hours away.

For a quota-backed meter, admission resolves the current typed entitlement and stores a `capped` snapshot with
its concrete non-negative limit, state, provenance, definition checksum, override ID and matching active
subscription/plan/revision context. Missing, malformed and `custom` values fail closed. A meter that explicitly
has no quota entitlement stores `unlimited`, a `NULL` limit and no sentinel arithmetic. The governed plan
catalog currently defines no unlimited credit plan; future unlimited commercial capacity must produce this
explicit state rather than overload a large or negative number.

The snapshot and meter rate govern that reservation after a plan change. New reservations use the newly
effective entitlement. An extension cannot cross the reservation's original window, cannot move expiry
backward and cannot exceed seven days from admission.

## PostgreSQL concurrency contract

Reserve, extend, finalize, release, expire and every usage-event insert acquire the same transaction-scoped
advisory lock derived from organization, logical pool, billing unit, quota entitlement and exact half-open
window. While holding it, admission sums immutable billed usage plus unexpired held reservations across all
compatible meters in the pool. The comparison is exact and inclusive at the limit. A failed admission writes
neither a reservation nor a usage event.

Quota denial raises `Usage::QuotaExceeded` with a safe immutable `denial` value containing meter/pool/unit,
limit, used, reserved, requested and reset instant. It never includes an idempotency key, provider reference,
source ID or entitlement override details.

## Retry, finalization and cancellation

Reservation idempotency is tenant-scoped. Raw keys are never persisted; SHA-256 digests and canonical request
checksums distinguish a valid retry from a conflicting reuse. Extend, finalize, release and automatic expiry
also append an immutable operation row with their own idempotency identity.

Finalization records one append-only usage event at the reserved rate, stores actual billed consumption and
releases unused held quantity in the same transaction. Zero-consumption cancellation creates no ledger event.
If actual usage exceeds the estimate, finalization atomically acquires the difference against the admission
snapshot; producers should still estimate conservatively or extend before consuming work because a denied
late expansion leaves the original hold available for a safe retry. Explicit release returns the whole hold
without a charge. Terminal reservations cannot transition again.

## Recovery and operations

`Usage::QuotaReservationMaintenanceJob` runs at minute 57 each hour on `maintenance`. It processes no more
than twenty batches of 500 expired holds, changing each to `expired` and preserving held/released history, then
checks up to 10,000 finalized reservations against their linked immutable event. Request-time balance reads
exclude elapsed holds even if maintenance is delayed. Repeat maintenance is a no-op.

The migration creates two new tables, composite tenant FKs, checks, partial indexes, lifecycle/append-only
triggers and one small PostgreSQL lock function. It replaces the existing usage-event trigger function so event
inserts join the same quota lock; it does not rewrite events or add an index to the high-volume event table.
Function/trigger replacement takes a brief DDL lock, so deploy outside an ongoing long usage-event transaction.
Rollback restores the pre-reservation event trigger before removing the new tables and lock function.
