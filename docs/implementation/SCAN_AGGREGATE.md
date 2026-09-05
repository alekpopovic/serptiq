# Scan aggregate and lifecycle

Prompt 062 introduced the Crawling-owned scan aggregate and Prompt 063 adds its production admission boundary.
Requested work becomes admitted only after the checks and transaction documented in
[`SCAN_ADMISSION.md`](./SCAN_ADMISSION.md); execution remains worker-owned.

## Tenant and input boundary

Every scan repeats `organization_id`, `project_id`, `property_id` and `environment_id`. A composite foreign key
requires that tuple to identify one real property environment. Membership initiation has a second composite
foreign key to the same organization. Optional baselines must be a terminal successful scan for the same exact
target when created through the domain API; a composite self-reference prevents a cross-tenant or cross-target
baseline at the database boundary. `release_id` is a UUID-only immutable correlation until Releases introduces
its owning table and composite relationship.

`Crawling::Public.admit_scan` re-resolves the exact hierarchy and requires `scans.run`. It then applies the
effective `crawl.manual` entitlement and resource-state checks before performing a network preflight or any
persistent side effect. The lower-level requested-scan constructor remains an internal aggregate primitive.

Settings and entitlement inputs are canonical bounded JSON objects with SHA-256 digests. Keys that suggest
credentials, tokens, cookies, authorization headers or private keys are rejected. Snapshot structure, target,
initiator, scan type, release/baseline links and engine/rule/config versions are immutable in both the model and
a PostgreSQL trigger. Existing `crawl_policy_snapshots` now accept only an exact matching scan tuple; the new
foreign key is installed `NOT VALID` so deployment does not take a full validation lock on any pre-existing
snapshot history. Operators must first confirm there are no orphan rows and then validate the constraint.

## State machine

The aggregate state is one of:

```text
requested -> admitted -> queued -> running -> completed
                                      |       -> partially_completed
                                      |       -> failed
                                      -> cancel_requested -> canceled

requested/admitted -> canceled
active non-terminal state -> failed
```

Commands are explicit: `admit`, `queue`, `start`, `complete`, `complete_partially`, `fail` and
`acknowledge_cancel`. Cancellation is a separately authorized `scans.cancel` command. Requested/admitted work
cancels immediately because no worker owns it; queued/running work first records `cancel_requested`, allowing
workers to stop cooperatively. PostgreSQL row locks serialize commands. Repeating an already-applied command is
idempotent, contradictory commands fail, and terminal states cannot be reopened.

`failure_category` is a bounded safe category and exists only when the aggregate outcome is `failed`. Individual
URL failures remain counters/checkpoints; they do not silently determine or reopen the terminal business outcome.

## Progress and events

Scan counters obey these persisted invariants:

- all counts are non-negative;
- processed URLs equal succeeded plus failed plus skipped URLs;
- discovered URLs cover processed, queued and running URLs; and
- terminal scans retain no queued or running URL count.

Workers submit absolute batch checkpoints through `record_scan_progress`; the API rejects regressing totals and
uses a per-scan idempotency key. It updates the aggregate once per checkpoint rather than once per URL. Every
lifecycle transition and progress checkpoint appends a monotonic `scan_events` row with the exact counter
snapshot. Those rows support bounded detail reads and stable Turbo targets without reading Solid Queue tables.
The aggregate emits audit and transactional outbox evidence for request, start, cancellation and terminal
completion, as well as the intermediate lifecycle checkpoints.
The crawl frontier added in Prompt 064 applies equivalent additive checkpoints in the same transaction as each
discovery, lease, completion or recovery batch. Customer progress therefore remains an indexed Scan read and does
not aggregate the high-volume frontier table.

## Read and retention behavior

The scan index is limited to 25 rows per page and detail history to the latest 50 checkpoints. Both public read
operations re-authorize `scans.read` against the exact tenant/project. Customer views distinguish aggregate
outcome from individual failures and do not expose job IDs, leases, queue depth or raw failure exceptions.

Deletion is allowed only inside the existing leased `scans_and_findings` resource-deletion stage. Scan and event
triggers otherwise reject deletion; the workflow first records minimized Scan tombstones, removes policy
snapshots and events, then deletes all scans for the exact project/property in one statement so baseline
references remain consistent.

## Migration and operations

Migration `20260904147000_create_scan_aggregate.rb` creates `scans` and append-only bigint `scan_events`, their
checks, composite foreign keys and timeline/active-work indexes. Both new tables start empty. Creating the tables
does not rewrite an existing application table. Replacing the audit tombstone allowlist takes a brief metadata
lock. The unvalidated policy-snapshot foreign key enforces all new writes immediately; validate it in a later
low-traffic migration after running an orphan query. Rollback deletes scan history and is appropriate only before
the aggregate contains relied-upon product evidence.
