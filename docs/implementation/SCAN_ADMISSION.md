# Scan admission and dispatch

Prompt 063 makes admission the single boundary for manual, scheduled and release-triggered scans. No entry point
may construct queued work directly. Each request carries an opaque idempotency key, source, exact tenant/project/
property/environment tuple and scan inputs; only SHA-256 digests of the key and canonical request are stored.

## Ordered access and safety checks

Admission first re-resolves the exact active tenant resource and requires the `scans.run` permission. It then
evaluates the `crawl.manual` entitlement and valid resource state through the unified authorization boundary.
These checks happen before duplicate lookup, DNS, HTTP or database effects, so an unauthorized caller cannot use
idempotency or preflight behavior as an oracle.

The selected policy is revalidated against current global and entitlement limits. Admission requires an active,
unexpired verification for the exact origin and workload freshness class. A bounded preflight fetches only the
environment root through the Shared safe HTTP client. Every DNS answer and redirect remains subject to the public
network policy; cross-origin redirects, unacceptable content types and unavailable origins fail closed. The scan
stores only the check time, status and a digest of the final origin, never headers or response bodies. Workers
must repeat network-safety checks for every later request.

## Atomic capacity and quota decision

PostgreSQL transaction-scoped advisory locks serialize the global, organization and project admission domains.
Within the same application-data transaction, admission checks active scan counts, resolves the billing window,
holds the policy's maximum weighted credit estimate, creates the requested scan and policy snapshot, transitions
the scan to `admitted`, and appends audit/outbox evidence. The quota reservation uses the scan's deterministic ID
as its tenant-bound source. A failure rolls back the reservation, scan and outbox together.

Admission also resolves all three crawl-credit meter windows and freezes the governed catalog plus exact
HTTP/render/Lighthouse definition and rate facts in the entitlement snapshot. The HTTP window remains the shared
pool's anchor reservation; Prompt 072 operation allocations can consume any compatible snapshotted meter without
re-reading a mutable current rate.

The organization cap comes from the `crawl.concurrent_scans` entitlement. Project and installation caps come
from `SEARCHOPS_CRAWLER_PROJECT_CONCURRENT_SCANS` and `SEARCHOPS_CRAWLER_GLOBAL_CONCURRENT_SCANS`. Active work is
`admitted`, `queued`, `running` or `cancel_requested`. Duplicate requests are checked under the locks before
capacity, so an exact replay returns its existing scan even when all slots are occupied. Reusing a key for a
different canonical request fails with a stable conflict code.

## Post-commit dispatch and recovery

Solid Queue enqueue happens only after the admission transaction commits. A successful dispatch job locks the
scan, confirms its exact quota reservation is still held and unexpired, and performs the `admitted -> queued`
transition. A queue outage leaves the admitted scan and quota hold intact with a safe attempt category. The
minute recovery sweep retries a bounded batch of admitted scans without a recorded enqueue, making the
database-backed admission record the durable source of truth.

If the reservation is unavailable when a worker claims the job, the scan fails with a bounded category instead
of running unmetered. Enqueue and dispatch are idempotent under row locks; queue implementation identifiers and
raw adapter exceptions are not exposed through product APIs.

## Migration and operations

Migration `20260904148000_add_scan_admission_provenance.rb` adds nullable immutable admission provenance,
dispatch-attempt metadata, exact verification/quota references and admission/capacity/recovery indexes. Legacy
requested scans remain valid with an entirely null admission shape. Constant defaults are metadata-only on
supported PostgreSQL versions, but foreign-key validation and ordinary index creation can take locks proportional
to existing scan history; deploy with the configured migration timeouts and schedule during low traffic if the
table is already large. Rollback removes admission provenance and must not be used after admitted work is relied
upon.
