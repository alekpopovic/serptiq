# PostgreSQL crawl frontier

Prompt 064 introduces `crawl_urls` as the durable source of crawl work. Solid Queue may wake workers, but it does
not own URL availability or lease state. Every frontier row repeats the exact organization/project/property/
environment/scan identity and uses a bigint primary key as its monotonic discovery sequence.

## URL identity and discovery

`Crawling::FrontierEntry` passes candidate HTTP(S) values through the versioned canonical normalizer and records
the first normalized fetch URL separately from the query-policy identity URL, its version-prefixed SHA-256 digest
and a version-2 host digest over scheme, IDNA hostname and effective port used for scheduling and pressure control.
The explicit `normalization_version` prevents later rules from
silently changing existing scan identities. The full contract is in
[`URL_NORMALIZATION_AND_SCOPE.md`](./URL_NORMALIZATION_AND_SCOPE.md).

Discovery accepts at most 500 items per transaction. `INSERT ... ON CONFLICT DO NOTHING` makes repeated and
concurrent batches safe under unique `(scan_id, normalized_url_digest)`. The operation then compares every stored
URL and normalization version to detect a digest collision instead of silently treating different text as the
same resource. A composite self-reference permits `discovered_from_id` only inside the same scan. First discovery
source and URL identity are immutable in both Rails and a PostgreSQL trigger.

## Fair leasing and ownership

One SQL statement ranks eligible work in host and scan rounds, then in an organization round, locks the bounded
candidate set with `FOR UPDATE SKIP LOCKED`, and changes it to `leased`. Higher priority wins within a lane, then
shallower depth and bigint discovery sequence. This prevents one organization, scan or host from consuming the
entire first scheduling round while keeping priority meaningful inside each lane.

Prompt 071 retains this query as the fair selector, then requires a separate exact-owner fetch permit before each
network attempt. Frontier ownership and pressure capacity are intentionally distinct; see
[`CRAWL_PRESSURE_CONTROLS.md`](./CRAWL_PRESSURE_CONTROLS.md).

Each claim has a bounded worker identifier, lease start/expiry and 256-bit random token. Only the token's SHA-256
digest is stored. Heartbeat, success, rejection and failure require the exact current worker and raw token while
the lease is unexpired. Completion keeps only the last token digest and outcome so identical delivery retries are
idempotent; conflicting completion payloads fail closed. Retry clears ownership and schedules an exponential,
one-hour-capped delay. The per-row maximum-attempt snapshot is immutable, so a configuration change cannot move an
existing item's exhaustion boundary.

The minute maintenance job selects expired leases in bounded `SKIP LOCKED` batches. It returns eligible items to
pending, exhausts items at their attempt limit, and rejects stranded work for canceled/terminal scans. Multiple
recovery workers may run concurrently without handling one lease twice.

## Aggregate progress

Discovery, lease, completion, retry and stale recovery update the Scan counters in the same application-data
transaction as their frontier changes and append one progress checkpoint per affected scan/batch. The projection
reads those Scan columns only. No customer request or worker progress query counts `crawl_urls`; individual row
states remain operational evidence, while the Scan aggregate remains the customer-visible observation.

## Query plan and scale evidence

`test/performance/crawl_frontier_query_plan_test.rb` loads 10,500 rows (10,000 terminal and 500 eligible across 25
hosts) on PostgreSQL 17.10 in the 12-vCPU local test container, runs `ANALYZE`, and explains the production fair
lease update. The captured non-executing plan uses an `Index Only Scan` on
`index_crawl_urls_on_pending_eligibility`, `LockRows` for candidate ownership and primary-key index scans for the
locked update; estimated startup/total costs were 76.24/92.62 in that environment. Costs are environment-specific,
so the automated contract asserts plan shape and index use rather than those exact values.

The table starts unpartitioned because each scan must retain one enforceable URL identity. At sustained scale,
prefer hash partitioning by `scan_id`: the partition key remains part of the unique identity and exact-scan foreign
key, while per-scan cleanup stays localized. Time-range partitioning would weaken `(scan_id, digest)` uniqueness
unless creation time became part of the key, so it must not be introduced as a retention shortcut. Retention follows
the owning scan/project deletion workflow; frontier rows are deleted before scan history under the same leased
database-authorized stage. Track eligible-row cardinality, lease latency, stale rate, index size and vacuum debt
before choosing partition count.

## Migration and operations

Migration `20260904149000_create_crawl_frontier.rb` creates one empty high-volume table, its exact/self foreign
keys, partial eligibility/fairness/stale indexes, lifecycle checks and immutable-provenance trigger. There is no
data backfill or existing-table rewrite. Adding the scan foreign key takes a brief metadata lock; deploy under the
configured migration lock and statement timeouts. Rollback drops all frontier evidence and is safe only before
workers rely on it.
