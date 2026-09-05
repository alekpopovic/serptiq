# Static crawl orchestration

Prompt 073 connects admitted scans, robots and sitemap discovery, the durable frontier, safe HTTP transport,
private artifacts and scan usage accounting into the first executable static crawl. Solid Queue wakes workers;
PostgreSQL remains the source of truth for initialization, frontier ownership, fetch observations, extraction
leases, progress and terminal state.

## Execution flow

`Crawling::ScanDispatchJob` revalidates admission and queues an exact organization/scan pair, then schedules
`StaticCrawlOrchestratorJob` on the `crawl` queue. One orchestrator delivery performs at most one frontier unit:

1. transition a queued scan to `running`;
2. claim the one-per-scan initialization lease;
3. cache robots, discover bounded sitemaps and seed allowed start URLs exactly once;
4. lease one exact-tenant frontier row with its opaque owner token;
5. evaluate the cached robots decision and fetch through the pinned, bounded HTTP transport;
6. persist normalized response metadata and an optional private response-body artifact;
7. finish or retry the frontier row and enqueue an HTML snapshot for bounded link discovery;
8. reconcile the terminal scan state, publish a throttled live update and enqueue another unit only when
   eligible durable frontier work exists.

The crawl job carries organization and scan IDs, never a raw frontier lease token. The lease token exists only
inside one worker delivery and is stored as a SHA-256 digest. Each redirect or safe retry gets a fresh network
decision, pressure permit and pre-work usage allocation. Robots and sitemap retrieval use the same pre-request
usage observer: a quota denial stops before DNS or transport, while every accepted redirect/final response is
accounted separately.

## Durable records and idempotency

`crawl_scan_executions` owns the initialization lease, bounded attempt count and live-update checkpoint. A
unique `scan_id` permits concurrent delivery without duplicate initialization. Expired initialization leases
return to `pending`; exhaustion fails the scan after releasing the execution-row lock so all code retains the
scan-before-child lock order.

`crawl_fetch_results` is an immutable bigint observation for one frontier attempt and lease-token digest. It
stores only bounded allowlisted headers, status, final URL, response sizes/hash/type, retry/redirect counts and
an exact optional artifact reference. It never stores the response body. Unique scan/source and
scan/frontier/attempt identities make delivery replay deterministic; conflicting replay fails closed.

`crawl_page_snapshots` links one successful static HTML fetch to its exact frontier row and private artifact.
The analysis worker downloads at most the configured decompressed-byte ceiling, parses with Nokogiri HTML5
without executing JavaScript and inspects at most 5,000 anchor elements. URLs are resolved against the observed
final URL, passed through the immutable scan scope, deduplicated and inserted through the capped frontier API.
This is deliberately link discovery only. Full normalized page facts, canonical trust, structured data and
link-edge evidence belong to Prompt 074.

All three tables repeat organization/project/property/environment/scan identity. Composite foreign keys reject
cross-tenant, cross-scan, frontier, fetch and artifact substitution. Database checks bound states, attempts,
sizes and metadata; triggers protect execution identity, immutable fetch rows and snapshot provenance. Authorized
resource deletion clears the frontier result pointer and removes snapshots, results and execution state before
artifacts, frontier rows and the scan.

## Limits, cancellation and terminal state

Frontier discovery locks the scan and inserts no more than its immutable `max_urls`; URL scope enforces scheme,
host, port, path, query and depth. Pressure admission enforces global, organization, scan and host limits before
each page network attempt. Usage admission enforces the scan's exact snapshotted credit meter before every HTTP
hop. Initialization stops immediately when robots or sitemap work observes `quota_exhausted`.

Cancellation is cooperative and checked before initialization stages, page fetches, extraction and between
bounded sitemap/link units. A running cancellation request schedules an orchestrator acknowledgement. Halting
expires active permits, rejects pending/leased frontier work, skips pending/processing snapshots and updates scan
counters transactionally. Quota exhaustion and scan-deadline exhaustion produce `partially_completed`; explicit
cancellation produces `canceled`.

A scan cannot complete while pending/leased frontier rows, pending/processing page snapshots, or
pending/initializing execution state remains. Otherwise, any failed/skipped URL, snapshot or partial/failed
sitemap observation yields `partially_completed`; a clean durable set yields `completed`. Individual URL failures
remain observations and do not crash the entire scan. Retryable poison URLs consume the bounded frontier attempt
budget, and the minute maintenance sweep recovers expired initialization/extraction leases and re-enqueues due
work.

## Progress and operations

The scan detail page subscribes to an organization-and-scan-specific Turbo stream and presents persisted queued,
running, succeeded, skipped, HTTP-observation and page-snapshot counts. Refresh broadcasts are limited to one per
two seconds per scan except for a forced terminal update. Structured events contain only low-cardinality outcome
and checkpoint/terminal operation fields; URLs, lease tokens and response data are excluded.

`recover_static_crawl_work` runs every minute on `maintenance`. Alert on old `initializing` executions, old
`processing` snapshots, growing due frontier work without crawl jobs, repeated extraction exhaustion, scan
deadline/quota partial completion, and a divergence between active scan counters and durable work states.

Migration `20260904156000_create_static_crawl_execution.rb` creates empty execution, result and snapshot tables,
adds their checks/composite foreign keys/triggers, and builds the exact artifact identity index concurrently. It
does not backfill or rewrite existing rows. Table and foreign-key creation still take brief metadata locks; use
the configured migration lock/statement timeouts. Rollback drops all new crawl observations and the concurrent
artifact identity index, so it is appropriate only before workers or retained scan evidence depend on them.
