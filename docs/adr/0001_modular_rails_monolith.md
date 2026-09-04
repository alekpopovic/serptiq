# ADR 0001 — Start with a modular Rails monolith

- Status: Accepted
- Date: 2026-09-04

## Context

The product needs identity, tenancy, billing, workflows, crawling, integrations, reporting and background processing. Premature services would multiply deployment, contracts, observability and consistency problems before workload boundaries are measured.

## Decision

Build one Rails application and repository with explicit domain modules. Deploy independent process roles from the same immutable release image. Modules communicate through public domain operations and an outbox/event boundary where asynchronous coordination is justified.

## Consequences

- One transactional boundary simplifies billing, quota and workflow correctness.
- Teams can navigate and refactor the product rapidly.
- Crawl/render roles scale separately without becoming services.
- Boundary tests and ownership rules are required to prevent a tangled monolith.
- Extraction is allowed only after measured scaling, isolation, deployment or team-ownership need.
