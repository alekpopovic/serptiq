# PostgreSQL crawl pressure controls

Prompt 071 places a mandatory pressure-admission boundary in front of every
general crawler HTTP attempt. A frontier lease authorizes ownership of work;
it does not by itself authorize network pressure. `Crawling::Public.fetch_http`
therefore requires an exact `FetchPermitContext`, and every redirect or retry
acquires a new short-lived PostgreSQL permit before DNS resolution or transport.

## Effective limits

Each decision applies global, organization, scan and normalized-host concurrency
and request-rate limits. The first exhausted scope wins, so a larger customer
allowance never bypasses a stricter host or fleet safety cap. Organization limits
are derived from the immutable admitted `crawl.concurrent_scans` entitlement
snapshot and operator-configured per-scan multipliers; domain code never branches
on a plan name. Scan concurrency/rate come from the immutable scan settings
snapshot and remain bounded by configuration.

Host identity is `SHA-256("crawl-host:v2:" + scheme + "://" + IDNA-hostname +
":" + effective-port)`. Paths, queries and raw hostnames are not coordination
keys or telemetry labels. HTTP and HTTPS, non-default ports and distinct IDNA
names therefore remain separate pressure scopes.

## Atomic admission and recovery

`crawl_pressure_states` retains scheduled next-fetch clocks, bounded host failure
streak/backoff and platform emergency state. `crawl_fetch_permits` retains exact
tenant/scan/frontier provenance, only a digest of its 256-bit token, and a bounded
active/released/expired lifecycle. Composite foreign keys, checks, partial indexes
and an immutable-provenance trigger reinforce the application boundary.

Acquisition runs in one primary-database transaction under a fixed PostgreSQL
transaction advisory lock. It validates the current frontier owner/token, locks
the scan and all four pressure-state rows, ignores/reaps expired capacity, checks
the hard scan deadline and active permit counts, advances every applicable rate
clock and creates the permit atomically. The intentionally fleet-wide lock keeps
launch semantics exact and short; monitor acquisition wait/lock time and revisit
with a reviewed sharding design only if it materially affects the crawler SLO.

The maintenance job runs every minute and expires stale permits in batches of at
most 500 with `FOR UPDATE SKIP LOCKED`. Multiple recovery workers may run without
recovering a permit twice. Permits also stop counting immediately at expiry, so a
delayed maintenance job cannot leak concurrency indefinitely.

## Fairness, backoff and bounded duration

The frontier's organization/scan/host round-robin lease query remains the fair
selector before pressure admission. Pressure permits preserve the selected
work's exact lease identity and cap each organization and host, preventing one
lane from consuming all fleet capacity. A pressure denial performs no DNS or
HTTP activity and reports the earliest observed retry time to orchestration.

HTTP 429/503, transient DNS/connect/TLS/timeout failures and a valid numeric or
HTTP-date `Retry-After` update durable host backoff. Provider delay is clamped
between the configured base and maximum; repeated transient failures use capped
exponential backoff. Every scan also has an absolute configured maximum duration,
so backoff at or beyond that deadline becomes `scan_deadline_exceeded` rather
than infinite rescheduling. Cancellation and terminal scan state deny new permits.

## Customer and operator surfaces

The scan projection exposes only a live throttle observation: bounded reason,
observation time and earliest eligible time. The UI explicitly says that this is
not a guaranteed resume time and never exposes a hostname or URL. A successful
permit or terminal/cancellation transition clears the observation.

Operator snapshots expose counts for active/stale permits, throttled scans,
backed-off/disabled hosts, global-switch state and maximum observed wait. Global
and host emergency switches require a dedicated active platform grant for
`crawler_control.manage`; they are not tenant permissions. Changes and denials
are audited using only fixed scope/operation/reason fields and opaque state IDs.

## Configuration and operations

The `SEARCHOPS_CRAWLER_*` inventory defines global/organization/host concurrency,
global/organization/host rates, permit duration, maximum scan duration, host
backoff bounds and throttle poll interval. Boot fails if a permit can expire
before the configured HTTP total timeout or if maximum backoff is below its base.

Migration `20260904154000_create_crawl_pressure_controls.rb` creates empty tables,
indexes, constraints and triggers, then adds nullable throttle-observation columns
and a `NOT VALID` check to `scans`. There is no row backfill or table rewrite for
existing scans. Adding the columns/check takes brief metadata locks; validate the
scan check separately after deployment under the configured lock/statement limits.
Rollback removes pressure evidence and must occur only after fetch workers no
longer require permits.

Incident order: enable the global switch for fleet-wide danger, or the opaque
host scope for a localized incident; verify its audit event and pressure metric;
let active permits expire or finish; inspect stale recovery and database lock
health; resolve the cause; resume through the same audited operation. Never edit
tenant rows or delete permits directly as an emergency control.
