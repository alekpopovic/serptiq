# ADR 0010 — Docker and Kamal for initial production deployment

- Status: Accepted
- Date: 2026-09-04

## Context

The system needs repeatable production deployments and independently scalable process roles, but a Kubernetes control plane is unnecessary for the MVP.

## Decision

Build immutable Docker images and deploy to virtual machines using Kamal. Use managed PostgreSQL and S3-compatible storage. Operate web and worker roles independently while retaining one release identity.

## Consequences

- Small-team operations and rollback remain understandable.
- Host provisioning, patching and monitoring still require automation/runbooks.
- Kubernetes remains a future option only if scheduling, scale or organizational needs justify it.
- Images, migrations, health checks and rollback behavior are release gates.
