# PostgreSQL topology and operating contract

SearchOps uses PostgreSQL for primary application data, Solid Queue, Solid
Cache and Solid Cable. `config/database.yml` defines all four connections in
development, test, staging and production. Development/test place four logical
databases on one local PostgreSQL server; staging/production accept independent
`DATABASE_URL`, `QUEUE_DATABASE_URL`, `CACHE_DATABASE_URL` and
`CABLE_DATABASE_URL` values so workloads can move without domain-code changes.

## Clean setup

Install PostgreSQL and the pinned Ruby/Bundler dependencies, then run:

```bash
bin/setup --skip-server
```

The underlying repeatable database command is:

```bash
bin/rails db:prepare
```

It creates/loads the primary schema and the checked-in Queue, Cache and Cable
schemas. CI supplies four explicit test URLs and runs `bin/rails db:prepare`
before tests. To prove recovery from zero in a disposable environment, point
all four URLs at explicitly named empty test databases, then use `db:drop`,
`db:create`, and `db:prepare`; never aim `db:drop` at shared/staging/production
URLs.

The primary database uses `db/structure.sql`, because PostgreSQL functions,
triggers and deferrable integrity constraints are executable parts of the data
contract. Queue, Cache and Cable keep their upstream Ruby schema files. Local
and CI database setup therefore require PostgreSQL client tools compatible
with the server major version (`psql` for loading and `pg_dump` for refreshing
the primary structure dump).

Local default names are:

| Environment | Primary | Queue | Cache | Cable |
|---|---|---|---|---|
| development | `searchops_development` | `searchops_development_queue` | `searchops_development_cache` | `searchops_development_cable` |
| test | `searchops_test` | `searchops_test_queue` | `searchops_test_cache` | `searchops_test_cable` |

Production/staging boot accepts either all four URLs or a shared host,
username/password and the four conventional database names. Partial URL sets
fail clearly; SearchOps never silently sends Queue/Cache/Cable tables to the
primary URL.

## Connection capacity

Each runtime declares primary, queue, cache and cable maximum pools plus the
number of same-shaped process replicas. Boot validates:

```text
(primary_pool + queue_pool + cache_pool + cable_pool)
× database_process_count
+ reserved_connections
<= database_connection_budget
```

This is deliberately conservative for a colocated cluster. Set the process
count to the total deployment count sharing that budget and leave capacity for
migrations, consoles, monitoring and failover. When databases use independent
managed clusters, capacity-plan each cluster separately as an operational
release check; the application guard remains a safe upper bound. A web primary
pool may not be smaller than `RAILS_MAX_THREADS`.

Every connection uses a bounded connect/checkout timeout, PostgreSQL
`statement_timeout`, `lock_timeout`, and
`idle_in_transaction_session_timeout`. Application names have the form
`searchops-<environment>-<process-role>-<database>` for `pg_stat_activity`.
Migration runs may deliberately override the statement timeout, but keep a
bounded lock timeout and document the production lock risk.

Rails migration advisory locks are enabled by default to prevent concurrent
migrators. Disable them only for a reviewed adapter/proxy limitation; a
PgBouncer transaction-pooling deployment needs a separate direct migration URL
and operational review.

## Keys and extensions

Application aggregate roots use UUID primary keys by generator default. This
includes identity, tenancy, billing, plan/version, entitlement/usage, project,
property, scan/workflow, integration, release, reporting and externally
referenced records. Foreign keys use the same UUID type and database constraints.

High-volume internal append-only/detail rows may opt into bigint explicitly
when index locality and storage justify it: crawl frontier/fetch/link rows, page
snapshot metadata, finding occurrences, usage/audit events and delivery
attempts. The migration must state the exception; tenant reachability and
foreign keys remain mandatory. Solid Queue/Cache/Cable retain their upstream
bigint/internal key design.

The foundation migration enables `pgcrypto`, which supplies the accepted UUID
generation/cryptographic database functions needed by later UUID migrations.
The identity model also enables `citext` for normalized contact/provider email
columns. These migrations are reversible before dependent objects or identity
data exist. Once application data depends on them, production rollback must be
a reviewed forward fix, not an automatic extension drop. No extension is
enabled in queue/cache/cable.

Domain `datetime` columns use PostgreSQL `timestamptz` through the application
adapter initializer. Values still surface as Rails `:datetime`, but PostgreSQL
stores instants with time-zone-aware semantics as required by the ERD.

## Readiness query

`Shared::DatabaseHealthCheck.call(database: :primary)` executes exactly
`SELECT 1` inside a transaction with a stricter local statement timeout
(default 1000 ms, allowed 50–5000 ms). It returns a small result with `ready?`,
latency and a stable `timeout`, `unavailable`, or `unexpected_result` reason;
database messages and URLs are not exposed. The same query accepts `:queue`,
`:cache`, or `:cable` and is the database primitive for the later `/ready`
endpoint. It does not inspect tables, run migrations or call third parties.
