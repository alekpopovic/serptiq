# Deployment and Operations

## 1. Operating model

The MVP deploys one versioned Rails application image into independently scalable process roles:

```text
web
scheduler
worker-default
worker-crawl
worker-render
worker-analysis
worker-report
```

All roles come from the same commit, lockfile and container image. This keeps the product a modular monolith while isolating resource-heavy workloads operationally.

The recommended first production shape is Docker plus Kamal on virtual machines, managed PostgreSQL, S3-compatible object storage, a container registry, DNS/TLS, email delivery and an error/observability provider. Kubernetes is intentionally outside the MVP.

## 2. Environment separation

Use distinct production and staging resources for:

- application/queue/cache/cable databases;
- object-storage buckets and keys;
- OAuth/OIDC clients and callback URLs;
- billing stores/products/variants and webhook secrets;
- Search Console and app-store credentials where possible;
- Slack applications/webhooks;
- API key encryption and Rails credentials;
- domains and email senders.

Development credentials must never be accepted in production.

## 3. Database topology

All persistence technologies are PostgreSQL, but production may use separate logical databases or managed instances:

| Database | Purpose | Notes |
|---|---|---|
| primary | transactional application state | strongest backup/PITR requirements |
| queue | Solid Queue and recurring execution | high write/churn; monitor table growth |
| cache | Solid Cache | disposable but bounded and vacuumed |
| cable | Solid Cable | ephemeral message/state workload |

A small launch deployment may colocate these in one managed PostgreSQL cluster with separate databases. Scale or failure-domain separation only after measurements justify it.

Required operational controls:

- encrypted connections and storage;
- least-privileged database users per process;
- automated backups and point-in-time recovery;
- tested restore;
- connection pool per process role;
- query and lock monitoring;
- autovacuum monitoring;
- statement timeouts for user-facing paths;
- retention/partition strategy for high-volume rows;
- safe migration workflow.

## 4. Object storage

Store large or immutable artifacts outside PostgreSQL:

- original and rendered HTML;
- screenshots;
- Lighthouse JSON;
- extracted manifests and association files when retention permits;
- generated reports;
- optional network traces.

Use private buckets, server-side encryption, blocked public access, lifecycle expiration and short-lived signed downloads issued only after authorization. Object keys include opaque tenant/project identifiers and content hashes, not raw customer URLs or secrets.

## 5. Production container

The multi-stage image should:

- pin Ruby, system packages, Chromium and Node/Lighthouse versions;
- install only production dependencies in the final stage;
- precompile assets;
- run as a non-root user;
- use a read-only root filesystem where practical;
- write only to explicit temporary paths;
- include a minimal health-check path;
- expose no development tools or credentials;
- record build metadata and source commit;
- produce an SBOM and vulnerability scan in CI.

Use an init process or equivalent correct signal handling. Browser workers may use a dedicated image derived from the same application release when Chromium dependencies materially enlarge or weaken the web image; both images must carry the same release ID.

## 6. Kamal topology

Illustrative roles:

```yaml
servers:
  web:
    hosts:
      - web-1.example.internal
      - web-2.example.internal
  job:
    hosts:
      - jobs-1.example.internal
    cmd: bin/jobs
  crawl:
    hosts:
      - crawl-1.example.internal
    cmd: bundle exec rails runner "Workers::Crawl.run"
  render:
    hosts:
      - render-1.example.internal
    cmd: bundle exec rails runner "Workers::Render.run"
```

The actual configuration is generated during the deployment prompts. Do not place real hostnames, keys or secrets in source control.

Kamal Proxy terminates/forwards traffic according to deployment configuration and checks the Rails health endpoint. Use rolling deployment behavior, explicit readiness, drain time and rollback documentation.

## 7. Health and readiness

Provide separate semantics:

- `/up`: process is alive and Rails booted; inexpensive and unauthenticated.
- `/ready`: process is able to serve its role; may check critical dependencies with tight timeouts.
- `/version`: release identifier, build timestamp and safe runtime metadata.

Do not make liveness dependent on every third-party provider. Provider health is tracked separately.

Worker health includes:

- last heartbeat;
- currently leased job;
- queue latency;
- browser pool state;
- graceful-shutdown state.

## 8. Secrets

Production secrets are injected by deployment/runtime mechanisms, not baked into images or committed files.

Classify and rotate:

- Rails master/encryption keys;
- session/signing secrets;
- OAuth client secrets;
- token-encryption keys;
- billing webhook secret and API key;
- provider credentials;
- object-storage credentials;
- database credentials;
- outgoing webhook signing secrets;
- deployment/registry credentials.

Support overlapping key versions for safe rotation where data must be decrypted after rotation. Logs show key identifiers, never key material.

## 9. Safe deployment sequence

1. CI passes and produces immutable tagged image(s).
2. Review schema and data migration risk.
3. Confirm backup/PITR and current rollback image.
4. Deploy backward-compatible code before destructive schema changes.
5. Run pre-deploy migrations with lock/statement safeguards.
6. Roll out web and workers with readiness checks.
7. Verify `/up`, `/ready`, `/version`, login redirect, database access and one synthetic job.
8. Verify webhook ingress and object-store operation without creating customer impact.
9. Observe error rate, latency, queue depth, database locks and resource use.
10. Complete post-deploy migration/cleanup only after old code is drained.
11. Record release outcome and anomalies.

Use expand/migrate/contract for schema changes. Avoid adding a non-null column with an immediate full-table rewrite on a large table.

The provider-identity lifecycle migration builds its active user/provider unique
index concurrently. Before running it on existing data, query for duplicate
rows where `revoked_at IS NULL`, group by `user_id, provider`, and resolve every
result through an audited account review. Do not automatically retain or move a
provider subject. The revocation-time check is added without validation first
and then validates existing rows; monitor that validation and the concurrent
index build. The migration is reversible without deleting identity rows.

## 10. Rollback

Rollback means restoring the previous image/configuration while preserving data compatibility. Every migration must state one of:

- safely reversible;
- forward-fix only;
- requires restore;
- requires an explicit data repair.

Do not roll application code back across a schema boundary it cannot understand. Keep at least the prior known-good image and configuration reference.

A rollback runbook includes:

```text
trigger
decision owner
customer impact
commands/actions
data compatibility
verification
communications
follow-up
```

## 11. Backups and disaster recovery

### Back up

- primary PostgreSQL with PITR;
- queue database according to acceptable job-loss policy;
- encrypted secrets/key custody metadata;
- configuration and infrastructure code;
- object storage with versioning where justified;
- billing/provider external IDs required for reconciliation.

Cache and cable data do not require recovery.

### Restore tests

At least quarterly before scale, then at a risk-appropriate cadence:

1. restore production-like backup into isolated environment;
2. validate schema and row counts;
3. decrypt representative encrypted records;
4. regenerate/find artifact references;
5. run tenant-isolation and billing reconciliation checks;
6. record actual recovery time and data-loss window;
7. update RTO/RPO assumptions.

Initial business targets may be:

```text
RPO: <= 15 minutes for primary transactional data
RTO: <= 4 hours for an early-stage production service
```

These are targets, not guarantees, until demonstrated by exercises and contractualized.

## 12. Observability

### Structured event fields

```text
timestamp
severity
event_name
release
environment
request_id
trace_id
job_id
organization_id_hash
project_id
scan_id
provider
duration_ms
outcome
error_category
retry_count
```

Do not log credentials, raw OAuth codes, webhook secrets, page bodies, full query strings containing sensitive values or customer PII.

### Metrics

- HTTP request rate/error/latency;
- authentication callback failures by category;
- authorization denials;
- webhook receipt, signature failure, lag and projection failures;
- subscription reconciliation drift;
- queue depth and oldest-job age;
- crawl fetch rate/status/bytes;
- DNS and destination-policy denials;
- host throttling;
- render startup/run/crash/timeout;
- scan completion/cancellation/failure;
- credit reservation/consumption/refund;
- rule execution duration/failure;
- report generation and delivery;
- provider rate limit and credential-refresh failures;
- database connections, locks, slow queries, bloat and replication/PITR health;
- object-storage errors and retained bytes.

### Tracing

Trace user request → domain operation → job enqueue → job execution → provider call where correlation is safe. Sampling must retain errors and important billing/security paths.

## 13. SLOs and alerts

Initial internal objectives:

| Service path | Initial objective |
|---|---|
| Authenticated dashboard availability | 99.9% monthly |
| Non-render API p95 | < 500 ms under planned launch load |
| Webhook durable acceptance | 99.95% when application is reachable |
| Default job start latency p95 | < 2 minutes |
| Scheduled crawl start p95 | < 15 minutes from schedule |
| Critical alert delivery | < 5 minutes after confirmed detection |
| Artifact authorization correctness | zero known cross-tenant disclosure |

Alert on symptoms and customer impact, not every transient provider response. Every page-worthy alert links to a runbook.

## 14. Capacity and cost controls

Enforce at admission time:

- per-plan monthly credits;
- maximum URLs per scan;
- maximum scan concurrency per organization;
- global HTTP/render concurrency;
- per-host politeness;
- browser wall time, memory and network-request limits;
- provider import quotas;
- report size and frequency;
- object retention.

Track unit economics:

```text
HTTP fetch cost
rendered page cost
Lighthouse run cost
GB-month artifact cost
report generation cost
provider API cost
support/incident cost
```

Feature pricing and credit weights are revised from measured p50/p95 resource use.

## 15. Scheduled work

Solid Queue recurring tasks may trigger:

- scheduled scans;
- expired reservation cleanup;
- stale lease recovery;
- webhook replay/reconciliation;
- provider token refresh;
- report generation;
- retention deletion;
- aggregate refresh;
- integration health checks.

Recurring definitions are version-controlled. Tasks are idempotent and use database/advisory locks where only one execution is allowed.

Identity session cleanup runs daily at 03:17 on the maintenance queue. Each run
is bounded to twenty batches of 500 rows and retains expired/revoked sessions
for 90 days before deletion. Monitor retained row count, cleanup duration and
foreign-key skips; referenced rotation/OAuth rows are intentionally deferred.
The session metadata migration adds constant-default bounded columns, validates
allowlist checks, and builds the revoked-time index concurrently. Its first
attempt may be safely rerun because each addition is existence-guarded.

## 16. Incident response

Severity example:

- SEV-1: cross-tenant disclosure, active compromise, unrecoverable billing corruption, broad outage.
- SEV-2: major workflow unavailable, scan fleet failure, large webhook backlog.
- SEV-3: degraded provider integration, delayed reports, bounded customer impact.
- SEV-4: minor defect or internal operational issue.

For SEV-1/2:

1. appoint incident commander;
2. contain risk and preserve evidence;
3. communicate verified facts;
4. restore safe service;
5. reconcile jobs/billing/data;
6. document timeline and root causes;
7. create corrective actions with owners;
8. test the regression.

Security incidents follow legal and contractual notification obligations appropriate to deployed markets; obtain qualified counsel before launch.

## 17. Core runbooks

Create and maintain:

- failed deployment/rollback;
- database connection exhaustion;
- blocking migration/lock;
- queue backlog;
- stuck scan leases;
- runaway crawler or render workload;
- suspected SSRF bypass;
- Chromium crash loop;
- object-storage outage;
- OAuth provider outage/key rotation;
- billing webhook backlog or drift;
- leaked credential/key rotation;
- cross-tenant incident;
- backup restore;
- provider rate-limit exhaustion;
- customer data export/deletion.

## 18. Production release checklist

- dependency versions and advisories reviewed;
- production domains and TLS configured;
- OAuth callback allowlists exact;
- billing signatures verified in staging;
- database backups/PITR and restore tested;
- artifact bucket private and lifecycle configured;
- egress policy blocks internal networks;
- browser worker isolated;
- plans, prices, tax/legal text and support process approved;
- privacy policy, terms, retention and deletion behavior reviewed;
- dashboards, alerts and runbooks active;
- on-call ownership named;
- pilot organizations and rollback criteria documented.
