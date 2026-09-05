# Private artifact storage and lifecycle

Prompt 070 implements the large-artifact boundary from ADR 0005. PostgreSQL holds only bounded metadata;
HTML, rendered DOM, screenshots, performance output and report bytes belong in private object storage.

## Data ownership and deduplication

`artifacts` is the logical source reference. Every row has an exact organization, project, property,
environment and scan foreign key plus a bounded source type/identifier, kind, media type, sanitized download
filename, retention class and expiry. `artifact_blobs` is the physical object record with byte count, SHA-256,
opaque key, storage service, encryption mode/key version and storage lifecycle timestamps.

The database permits one live physical blob for a content hash only within the same
organization/project/property/encryption-key-version tuple. It never deduplicates across organizations,
projects or properties, so existence and timing cannot become a cross-tenant content side channel. Multiple
logical sources may reference that blob independently. Source identifiers must be stable IDs or digests;
raw URLs and query strings are rejected by the capture boundary.

Keys have this shape:

```text
organizations/<organization UUID>/projects/<project UUID>/properties/<property UUID>/objects/<shard>/<random UUID>
```

They contain no URL, customer name, filename, content hash or credential. The prefix remains compatible with
the existing exact-resource deletion workflow.

## Adapter contract and access

Both adapters stream through bounded chunks and verify caller-supplied byte count/SHA-256 before metadata is
activated. The local adapter writes a private temporary file, fsyncs it and atomically renames it with mode
`0600`; its root is `0700`. Failed partial files are removed and the same metadata/key can be retried. The S3
adapter uses streaming SDK bodies, checksum metadata, `AES256` server-side encryption and no ACL field.

Retrieval first reloads the artifact by its opaque application ID and exact tenant hierarchy, verifies active
project/property state and `scans.read`, and only then issues a URL valid for at most 15 minutes. S3 uses a
provider presigned GET. Local mode uses an authenticated-encrypted bearer token; the download endpoint reloads
server-side metadata before streaming. Responses use sanitized ASCII filenames, `private, no-store` and
`X-Content-Type-Options: nosniff`. The bearer URL is sensitive until expiry and must not be logged.

## Retention and repair

- The hourly sweep locks at most 250 expired, non-held references with `SKIP LOCKED`, marks them
  `deletion_pending`, and enqueues one idempotent deletion job per artifact.
- A physical blob is removed only when no retained logical reference remains. Provider failures leave the
  reference pending and restore the blob to an active retryable state.
- The daily reconciliation checks at most 250 active blob records. Missing objects become explicit `missing`
  metadata rather than silently appearing downloadable.
- Exact-property orphan reconciliation is available to an operator-owned workflow. It deletes keys that have
  no database row; `uploading` rows reserve their keys before transport, preventing a concurrent upload from
  being mistaken for an orphan.
- Every reconciliation also removes active physical blob rows that still have no logical reference after a
  one-hour grace period. This repairs the narrow crash window between a completed provider upload and the
  transactional source-reference insert without racing a live capture.
- `legal_hold` and its timestamp are a deliberately non-customer-facing placeholder. Held references do not
  expire, and a resource-deletion workflow pauses before scan metadata is removed. A future compliance prompt
  must define who may place/release a hold and add audited UI/API behavior.

Resource deletion removes artifact metadata during `scans_and_findings` only after the legal-hold check. The
later `object_artifacts` stage deletes and reconciles the exact opaque prefix, so large bodies never enter a
database transaction.

## Metrics and operations

`Crawling::ArtifactStorageMetrics` attributes unique active object count/bytes and retained logical reference
count by organization, project and storage service. Use bytes for GB-month allocation and reference count to
explain deduplication. Structured storage events contain only bounded outcome/operation/provider labels; they
exclude keys, URLs, hashes, filenames, credentials and body content.

Before production rollout verify bucket public-access blocking, encryption, version/lifecycle settings,
least-privilege IAM, restore behavior and deletion permissions with sanitized objects. Migration
`20260904153000` creates two empty tables and adds the required exact property identity index concurrently.
Because it disables the migration transaction for that production-safe index, a failed deploy may leave a
partial new table/index; inspect schema state and rerun the idempotent index step before retrying rather than
dropping populated objects.

S3 authentication may use the runtime's default IAM role/identity chain. If static compatibility credentials
are required, the access-key ID and secret access key must be supplied together through the secret settings;
configuration errors and adapter telemetry never include either value.
