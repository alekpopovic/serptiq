# Solid Queue, Cache and Cable operating contract

SearchOps uses the Rails Solid stack on the dedicated PostgreSQL connections
defined in `config/database.yml`. Queue rows are durable operational work;
cache entries and cable messages are disposable. Solid Cable is only Turbo/UI
fan-out and must never be treated as the domain event bus.

## Queue and process topology

Every job class calls `runs_on` with one of the registered queues. Smaller
numeric values are higher priority within one queue; worker queue order takes
precedence across queues. Domain jobs must not invent queue strings.

| Queue | Default priority | Process role | Default concurrency |
|---|---:|---|---:|
| `billing` | 0 | `worker_default` | 3 shared threads |
| `mail` | 10 | `worker_default` | 3 shared threads |
| `default` | 20 | `worker_default` | 3 shared threads |
| `integrations` | 30 | `worker_default` | 3 shared threads |
| `maintenance` | 50 | `worker_default` | 3 shared threads |
| `crawl` | 20 | `worker_crawl` | 3 threads |
| `render` | 20 | `worker_render` | 1 thread |
| `analysis` | 20 | `worker_analysis` | 2 threads |
| `reports` | 20 | `worker_report` | 2 threads |

The exact queue allowlists live in `Shared::JobTopology`. No worker polls `*`.
The default worker cannot claim crawl, render, analysis or report jobs, and the
render worker can claim only `render`. Render concurrency is fixed at one
thread per worker process; scale it with isolated `worker-render` processes,
never by widening its thread pool.

`SEARCHOPS_JOB_THREADS` and `SEARCHOPS_JOB_PROCESSES` tune a deployed role
within its registered bounds. The queue database pool needs at least worker
threads plus two connections per fork for execution, polling and heartbeat.
Include the supervisor, dispatcher, worker forks and replica count when setting
the database process count/budget from the database contract.

`Procfile` defines the deployable roles. `bin/jobs` requires an explicit role
in staging/production, gives development/test a `worker_default` convenience,
and enforces one ownership rule: `scheduler` runs recurring work only; all
worker roles skip the recurring scheduler. The only in-Puma mode is an opt-in
development convenience and has the safe default queue allowlist.

Validate every role before deployment:

```bash
SEARCHOPS_PROCESS_ROLE=worker_default bin/jobs check
SEARCHOPS_PROCESS_ROLE=worker_crawl bin/jobs check
SEARCHOPS_PROCESS_ROLE=worker_render bin/jobs check
SEARCHOPS_PROCESS_ROLE=worker_analysis bin/jobs check
SEARCHOPS_PROCESS_ROLE=worker_report bin/jobs check
SEARCHOPS_PROCESS_ROLE=scheduler bin/jobs check
```

## Retry and terminal errors

`ApplicationJob` retries explicit `Shared::JobErrors::Transient` failures and
PostgreSQL deadlock/lock-wait failures at polynomial backoff with jitter, at
most five executions. It discards deserialization failures and explicit
terminal job errors. It does not retry every network exception or every
`StandardError`: the integration/domain boundary must classify a failure after
considering idempotency and provider semantics.

A domain job overrides a handler when it must persist a terminal aggregate
state, use a provider-specific delay, or apply a stricter attempts limit.
Quota, cancellation and security rejections do not become automatic retry
loops. Exhausted/unhandled failures remain in `solid_queue_failed_executions`
for inspection; do not bulk retry until the job's idempotency and root cause
are established.

## Recurring work

`config/recurring.yml` contains only executable Solid Queue finished-job and
finished-batch cleanup operations. Later prompts add real idempotent tasks when
their job classes exist; placeholder class names are forbidden. Finished jobs
are retained for 24 hours, which preserves recurring de-duplication during
that window. The scheduler owns schedule creation and the default worker owns
the `maintenance` executions.

## Cache and cable bounds

Solid Cache uses only the `cache` database. Entries expire after seven days and
the store is bounded to 256 MiB; expiry runs in batches of 500 on the
`maintenance` queue. Cache loss, truncation or eviction must change performance
only, never authorization, billing, quota or workflow correctness. Cache and
cable databases are intentionally excluded from disaster recovery.

Solid Cable uses only the `cable` database in development, staging and
production. It polls every 100 ms, retains messages for one hour, autotrims in
batches of 200 with `SKIP LOCKED`, and uses bounded reconnect delays. Test uses
the Action Cable test adapter for deterministic assertions. Cable payloads are
short-lived UI notifications; durable facts use the documented outbox/event
path added by later prompts.

## Operations and incidents

Monitor queue depth and oldest ready/scheduled age per exact queue, failed
execution count, process heartbeat age, PostgreSQL connections/locks and table
growth. The launch SLO is default-job start p95 below two minutes and scheduled
crawl start p95 below fifteen minutes. Alert on sustained customer-impacting
latency, not a single transient sample.

On shutdown send `TERM` and allow more than the configured 30-second Solid
Queue grace period before the container runtime sends `KILL`. A hard-killed
job becomes inspectable after its process heartbeat is stale; automatic replay
is deliberately disabled because the job itself may have crashed the process.

For a backlog:

1. identify exact queues, oldest age and whether dispatching is healthy;
2. check database saturation/locks and current worker heartbeats;
3. pause admission or the affected producer before scaling consumers;
4. add only the matching isolated role and stay inside database capacity;
5. verify age falls, then remove temporary capacity gradually.

For failures, inspect `SolidQueue::FailedExecution` class/error metadata without
copying customer arguments into tickets or logs. Retry one proven-idempotent
job first, then a bounded reviewed set. `discard` permanently removes that job
and requires an operator decision.

The supervisor prunes processes older than the three-minute alive threshold
and marks their claimed jobs failed. Before manual stale cleanup, prove that
the process is gone from the orchestrator and preserve the failed execution for
diagnosis; use `SolidQueue::Process.prune`, not direct SQL deletion. A process
with a current heartbeat but one stuck job needs a job-specific timeout or
watchdog rather than heartbeat deletion.

`Shared::SolidQueueSmokeJob` is a side-effect-free maintenance job for deploy
verification. A successful enqueue, claim and finished queue record proves the
adapter/database path without touching tenant data or an external provider.
