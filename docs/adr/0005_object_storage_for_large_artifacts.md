# ADR 0005 — Store large scan artifacts in object storage

- Status: Accepted
- Date: 2026-09-04
- Owners: Platform, Crawling
- Last reviewed: 2026-09-05 (Prompt 070)

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

Prompt 070 implements the provider-neutral private artifact store independently
of Active Storage. S3 uploads use server-side encryption and no public ACL;
development and test use a private local streaming adapter. Logical artifact
metadata and physical blob metadata are separate so content is deduplicated
only inside an exact organization/project/property boundary. Authorized reads
receive URLs valid for at most 15 minutes. Hourly expiry and daily reconciliation
jobs own deletion and missing-object detection.
