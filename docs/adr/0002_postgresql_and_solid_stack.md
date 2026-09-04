# ADR 0002 — PostgreSQL and the Rails Solid stack

- Status: Accepted
- Date: 2026-09-04

## Context

The MVP should minimize infrastructure while supporting transactions, locking, jobs, cache and realtime UI updates. Redis/Sidekiq would add another operational dependency.

## Decision

Use PostgreSQL for transactional data and Solid Queue, Solid Cache and Solid Cable for their respective Rails functions. Production may use separate databases while retaining PostgreSQL as the only database technology.

## Consequences

- Operations, backup skills and local development are simpler.
- Queue and cache workloads must be capacity-planned and vacuumed.
- High crawl volume may later justify a different queue/frontier service, but only from evidence.
- Concurrency-sensitive quota/frontier tests run against real PostgreSQL.
