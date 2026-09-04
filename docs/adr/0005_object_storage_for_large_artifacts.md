# ADR 0005 — Store large scan artifacts in object storage

- Status: Accepted
- Date: 2026-09-04
- Owners: Platform, Crawling
- Last reviewed: 2026-09-04 (Prompt 005)

## Context

HTML, rendered DOM, screenshots, Lighthouse output and reports are large, immutable or retention-bound. Keeping them in PostgreSQL would increase backup size, vacuum pressure and query risk.

## Decision

Store large artifacts in private S3-compatible object storage. PostgreSQL stores metadata, content hash, byte count, media type, retention state and opaque object key. Downloads use short-lived signed access after application authorization.

## Consequences

- Database remains optimized for metadata and workflow queries.
- Object lifecycle and deletion reconciliation become required operations.
- Tenant-safe keys and authorization tests are mandatory.
- Provider portability is maintained through an artifact-store adapter.

## Implementation status

Prompt 003 added typed S3-compatible settings and requires bucket/region in
protected environments. The generated Rails production environment still uses
local Active Storage until the private artifact-store work in Prompt 070; this
is a documented pre-production gap, not a change to the decision.
