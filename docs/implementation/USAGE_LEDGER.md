# Immutable usage ledger and metering windows

`Usage` records variable-cost observations without mutating history. It does not authorize a product action
or reserve capacity: prompt 040 adds the reservation lifecycle, and the later access-decision composition must
still require permission, entitlement, quota and valid resource state independently.

## Governed meter catalog

`config_blueprints/usage_meters.yml` owns seven stable logical meters: HTTP fetches, rendered pages,
Lighthouse page runs, app-listing locale snapshots, deep-link validations, URL Inspection imports and report
generation. Each definition fixes raw and billing units, pool, quota-entitlement reference and either a UTC
calendar-month or explicit provider-billing-period policy. Effective rate rows are versioned and immutable;
each event retains the exact rate ID, applied weight and weighted quantity. The six credit weights must match
the governed values in `plans.yml`.

```bash
bin/rails usage:catalog:validate
DRY_RUN=1 bin/rails usage:catalog:sync
bin/rails usage:catalog:sync
```

Synchronization creates missing definitions/rates only. A changed existing row is a conflict: publish a new
sequential rate version and effective instant instead of rewriting history.

## Windows and time policy

UTC calendar windows always use `[00:00:00Z on day 1, 00:00:00Z on day 1 of the next month)`, regardless of
an organization's display timezone or DST. Provider windows require a typed `Usage::BillingPeriod` containing
explicit start/end instants, an IANA/Active Support timezone name and an opaque provider reference. Only the
SHA-256 digest of that reference is stored. Provider-policy meters also require an active subscription
projection. Every window snapshots the subscription ID, immutable plan version and revision when available.

Windows are immutable and non-overlapping per organization/meter. PostgreSQL advisory locking in the insert
trigger makes the overlap check safe under concurrent creators. Adjacent half-open windows are valid.

## Events, corrections and reads

Callers pass a same-organization `Usage::SourceReference`; future aggregate owners must construct it only
after resolving their source row inside that tenant. The public recorder stores no raw idempotency key—only a
SHA-256 digest—and returns the existing event only when its canonical request checksum also matches. Metadata
is a small hostile-input boundary: sensitive key names, floats, excessive depth/count/strings and payloads
over 2 KiB are rejected.

PostgreSQL and the model reject event update/delete. A correction is a new signed event referencing an
original event in the same organization/window/meter. It reuses the original rate/source, must have the
opposite sign and cannot cumulatively pass zero. Manual adjustments require a platform plan-catalog publisher
who is also an active member of the target organization; the mutation and `usage.manual_adjusted` audit event
commit atomically.

`Usage::Public.summary` exposes `used`, `reserved`, `limit`, `remaining` and `unlimited`; `used` includes every
compatible meter window in the same pool and exact period/subscription snapshot. In this prompt,
`reserved` is an explicit non-negative read input and normally zero; prompt 040 replaces that seam with the
durable reservation aggregate. A report meter with no quota entitlement is explicitly unlimited. A malformed
or missing numeric plan snapshot limit resolves to zero, never unlimited.

## Scale, retention and operations

`usage_events` uses bigint IDs and covering indexes for organization/window, organization/source and
meter/occurrence queries. Keep events for the contractual billing-dispute and statutory period; do not delete
individual corrections separately from originals. Before sustained volume makes the primary/index set large,
partition by `recorded_at` month, create future partitions ahead of time and detach whole expired partitions
only after exports, disputes, corrections and legal holds are reconciled. Because correction FKs can cross
recording months, a partition rollout needs an explicit reference-integrity design and production query-plan
evidence; this prompt intentionally documents rather than prematurely enables partitioning.

Migration `20260904091000` creates four tables and their indexes/FKs/checks, then installs catalog, window and
event triggers. It does not rewrite an existing high-volume table. Trigger/function installation takes brief
DDL locks on the newly created tables only. Deploy the migration before catalog synchronization.

Customer-facing terminology is strict: an event is an application-recorded observation, a provider period is
provider-supplied context, a configured weight is a commercial hypothesis, and append-only/constraint behavior
is the database-backed guarantee. None of these claims proves provider billing accuracy without reconciliation.
