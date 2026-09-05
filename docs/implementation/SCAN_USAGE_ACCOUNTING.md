# Scan usage accounting

Prompt 072 turns the admission hold into operation-level, append-only usage without charging for queueing or
failed work. An admitted scan snapshots the governed usage-catalog checksum and the exact definition checksum,
rate version, rate checksum, effective instant, weight, database rate ID and usage-window ID for HTTP fetch,
rendered-page and Lighthouse work. Workers resolve only these immutable facts; a later catalog rate cannot
change an in-flight scan's cost.

## Two-phase operation protocol

Workers use one stable source key per real provider/internal attempt:

1. `Crawling::Public.start_usage_operation` locks the scan and shared PostgreSQL quota pool. For a metered
   operation it creates a `usage_quota_allocation` for exactly one snapshotted unit before work starts.
2. Capacity already held by admission is assigned first. If concurrent or expanded work exceeds the unused
   estimate, the same transaction extends the reservation by only the deficit before returning to the worker.
3. `Crawling::Public.finish_usage_operation` converts an accepted/completed allocation to one immutable usage
   event, or releases it for a failed, canceled or rejected attempt.

The source key is stored only as SHA-256. Reusing it with the same input returns the existing attempt and event;
reusing it with different input fails closed. A provider retry is a new attempt only when it has a new stable
attempt key. Re-delivery of the same worker/provider attempt must reuse the original key.

HTTP billing counts every response accepted by the safe transport, including accepted redirect responses and
accepted 4xx/5xx responses. DNS/TLS/connect/timeout failures, unsafe destinations, policy rejection and
cancellation are attempts but are not billable. Render and Lighthouse work is billable only after completed
navigation/run processing. Artifact persistence is observed with the `artifact` operation kind but has no
standalone meter: HTTP/render artifacts are bundled into their parent meter and Lighthouse artifact processing
is included in `performance.lighthouse_page`. Artifact upload retry therefore cannot add credits.

## Capacity, terminal state and recovery

An active reservation may have partial consumption. Pool balance is always:

```text
append-only billed usage + (held quantity - already consumed quantity)
```

Held operation allocations divide the remaining scan hold but do not add another pool charge. Allocation,
incremental extension and operation creation share one transaction and the pool advisory lock, so parallel
workers cannot overcommit the last credit. A denied extension creates no attempt/allocation/event and records a
customer-visible `quota_exhausted` throttle observation until the window reset; the orchestrator must pause and
may cooperatively cancel.

Every terminal scan transition releases unfinished allocations as non-billable `abandoned` observations,
finalizes consumed credits and releases the unused reservation. A minutely bounded maintenance job retries this
for terminal scans left with a held reservation after a crash. Generic reservation expiry also releases held
allocations before expiring the remaining hold. Uncertain crash remnants are never silently charged.

Prompt 073 applies this protocol to every static page request, redirect and retry, and to every robots/sitemap
request hop. Page work also requires its independent PostgreSQL pressure permit. A control-fetch quota denial
occurs before DNS/transport and ends initialization as a partial crawl; a page-fetch quota denial releases its
pressure permit and halts remaining durable frontier work as skipped observations.

## Projections and corrections

The scan detail projection reports attempts, accepted observations, billable/non-billable/pending counts and
gross/net credits per operation. Net values come from the usage ledger, so compensating corrections are visible.
Organization usage remains derived across compatible meter windows in the shared `crawl.credits` pool.

Support correction requires an active same-organization membership plus platform `plan_catalog.publish`
authority, must target an original scan usage event and appends an opposite-sign correction. It never edits an
operation, reservation, event or aggregate counter. The action emits `usage.corrected` audit evidence against
the scan with the original bigint event ID in bounded metadata.

## Deployment notes

Migration `20260904155000_integrate_scan_usage_accounting.rb` creates the allocation and scan-operation tables,
adds one small tenant identity index to `usage_events`, and replaces reservation lifecycle triggers/checks to
permit partial consumption. It does not rewrite existing usage events or reservations. Foreign keys and checks
are validated during the migration and briefly lock the touched tables; for a mature high-volume ledger, create
the `(organization_id, id)` unique index concurrently in a pre-deploy migration and add/validate the new foreign
keys separately. Rollback requires no partially consumed active reservations or allocation rows.
