# Project aggregate and lifecycle

Projects are organization-owned authorization and reporting roots. The immutable, normalized
`(organization_id, slug)` is the customer route identity. `external_release_key` is a random globally unique
public lookup identifier for future deployment integrations; it is deliberately not an authentication secret.
Incoming release authentication will use separately managed keyed credentials.

## Authorization and tenant isolation

Creating a project requires `projects.create` at organization scope, allowed subscription access, and an
enabled positive `projects.max` value with remaining active capacity. The count check and create/reactivate
operation share a PostgreSQL advisory transaction lock, so concurrent requests cannot exceed the effective
limit. The limit is a resource cap rather than a usage-ledger meter.

Creation registers the same UUID and organization in `authorization_scope_references` before inserting the
project. A composite foreign key makes that hook mandatory. It does not create a role assignment: current
organization grants flow down normally, and project grants must be assigned explicitly through Authorization.
List queries bulk-resolve whether the actor has an organization-wide read grant or a bounded set of active
project grants before loading tenant rows. Foreign and inaccessible projects are never used to build response
content.

Archived project-scoped assignments remain inactive. Retained archived history, restoration, and deletion
requests are available only through current organization-scope grants that contain the corresponding project
permission. This exception does not reactivate property grants or allow updates/scans.

## Lifecycle and history

The central operations allow:

- `active → archived`, which immediately disables new scans;
- `archived → active`, after the active-project cap is rechecked;
- `active|archived → pending_deletion`, with `projects.delete`, recent session authentication and an exact
  durable deletion workflow;
- `pending_deletion → archived`, when an authorized cancellation arrives before the workflow hold expires.

Projects are never physically removed by the web request. Archive/request set a work-cancellation cutoff,
make admission unavailable and allow jobs that started earlier to stop cooperatively. Pending rows remain
read-only for a 30-day hold, then Administration performs resumable ordered cross-domain cleanup. Final
database deletion requires the exact leased workflow stage; minimized tombstones plus audit/outbox history
retain security identity without retaining the customer project row.

Every successful create, editable-setting change and lifecycle attempt appends a tenant-bound audit event.
Successful state changes also commit a versioned Project outbox event in the same transaction. Queue enqueue
failure cannot lose the committed event and is reported for the normal outbox recovery path.

## Read models and user-visible semantics

Project pages are bounded to 25 entries and search at most 80 characters across name and slug. The initial
operational read-model loader returns explicit `not_observed` health, zero property count and
`not_available` latest-scan state in one bulk call. These values are placeholders for absent source records,
not fabricated SEO measurements or guarantees. Property and scan prompts replace the bulk loader with grouped
queries while preserving the immutable summary contract.

## Migration operations

Migration `20260904130000` creates a new empty `projects` table, indexes, checks, one composite authorization
scope foreign key and a stable-identity trigger. It rewrites no existing tenant rows. Index creation and
foreign-key installation take ordinary PostgreSQL DDL locks; deploy before application code starts creating
projects. Rollback drops the trigger/function with the new table and removes project data, so it is suitable
only before production project history exists.

Migration `20260904146000` adds nullable cancellation/workflow columns and replaces the lifecycle check without
rewriting existing projects. It adds the exact-target workflow foreign key and guarded-delete trigger described
in [`RESOURCE_DELETION.md`](./RESOURCE_DELETION.md). Ordinary catalog locks apply.
