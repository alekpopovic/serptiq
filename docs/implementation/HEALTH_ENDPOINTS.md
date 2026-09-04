# Liveness, readiness and release endpoints

The three unauthenticated operational endpoints deliberately answer different
questions. Their responses are point-in-time observations, not uptime or
provider guarantees. Every response is JSON and carries `Cache-Control:
no-store, max-age=0`, `Pragma: no-cache` and `Expires: 0` so a proxy cannot
reuse stale health or release data.

## Public endpoints

| Endpoint | Success | Failure | Purpose |
| --- | --- | --- | --- |
| `/up` | `200 {"status":"up"}` | Connection/boot failure | Cheap process liveness only |
| `/ready` | `200` with PostgreSQL `ok` | `503` with PostgreSQL `unavailable` | Traffic admission for the current role |
| `/version` | `200` with release/build/runtime | Application boot failure | Deployment provenance verification |

`/up` executes no SQL and calls no OAuth, billing, search, storage, mail or
other provider. Kamal Proxy and load-balancer liveness checks use `/up`; a
third-party outage must not cause a restart loop.

`/ready` issues only transaction-local timeout-bounded `SELECT 1` statements.
It does not inspect tables, schema versions, job counts or provider health.
The role dependency map is intentionally small:

| Process role | Readiness PostgreSQL connections |
| --- | --- |
| `web` | primary and queue |
| `scheduler` | queue |
| all `worker_*` roles | primary and queue |

Solid Cache loss is a performance degradation and Solid Cable loss affects
ephemeral UI delivery, so neither makes the web process unready. The current
timeout defaults to one second per check and is bounded by the database health
contract. A readiness failure exposes no logical database name, URL, latency,
exception, host or credential.

`/version` returns the configured release ID/commit, normalized UTC build time,
Rails environment, Ruby version and Rails version. It never reads PostgreSQL
or exposes hostname, container ID, database/object-storage configuration,
credentials or environment variables. Malformed provenance is replaced by
`unknown` or `null`, never echoed.

## Deployment use

Configure Kamal Proxy or the platform liveness probe to request `/up`. During a
rolling deployment, wait for `/ready` before adding a web instance to traffic.
After rollout, compare `/version` with the intended immutable image commit and
build timestamp. Then verify one synthetic queue operation separately; do not
inflate `/ready` into a deployment test suite.

Suggested behavior:

- liveness interval: 10 seconds, short HTTP timeout, several failures before
  restart;
- readiness interval during rollout: 2–5 seconds with no shared proxy cache;
- remove an instance from traffic on sustained `503`, then investigate the
  named process role and database connection internally;
- do not automatically restart every instance for a provider, cache or cable
  incident.

The CI production smoke script builds the real image, checks its non-root UID,
waits for `/up`, requires `/ready`, verifies `/version` against the build
arguments and rejects prohibited version fields.

## Internal worker health

Worker heartbeat state is not public. An authenticated administration surface
added later may call `Shared::WorkerHealthSnapshot`; until then operators can
invoke it through an access-controlled Rails console or runner:

```bash
bin/rails runner 'puts Shared::WorkerHealthSnapshot.call.to_h.to_json'
```

The snapshot queries only process kind and last-heartbeat time and returns
aggregate healthy/stale counts by bounded Solid Queue process kind. It omits
hostnames, PIDs, process names, queue/job arguments and tenant data. `inactive`
means no registered process, `healthy` means every heartbeat is inside the
Solid Queue alive threshold and `degraded` means at least one is stale. Use the
full privileged Solid Queue tooling only during diagnosis under the operational
access policy.
