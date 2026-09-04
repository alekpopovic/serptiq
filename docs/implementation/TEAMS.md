# Teams

Prompt 027 introduces teams as organization-owned principals for future scoped role
assignments. It does not create roles or grant permissions.

## Database and domain boundaries

`teams` and `team_memberships` use UUID keys. Team names are case-insensitively
unique among active teams in one organization. Team membership rows denormalize
`organization_id`; composite foreign keys require the team, target membership and
adding actor to belong to that exact organization. A partial unique index permits
only one active association for a team/member pair while retaining removed history.

Create, rename, archive, add and remove operations lock the organization-scoped
records and require the current owner until RBAC decisions are implemented. Foreign
team/member identifiers receive the generic authorization denial. Add and remove are
idempotent under concurrent requests: repeated adds return the existing active row,
and repeated removals report no change.

## Archive and inactive-member semantics

Archiving is terminal for this prompt. The team becomes read-only, its membership
history remains intact and it contributes no future grants. Existing associations
are not rewritten on archive.

A suspended or removed membership never appears in the effective authorization
principal set. Suspension leaves the team association dormant; reactivation restores
it if neither the team nor association was archived/removed. Removed memberships are
terminal under the membership policy. New associations accept active organization
members only.

`Tenancy::Public.authorization_principals` is the boundary the Authorization module
can consume later. It returns an immutable direct membership ID and ordered active
team IDs only after exact organization/membership matching. It contains no role or
permission UI logic.

## UI and query bounds

Team list and member list pages use server-side pages of 25. Member search is trimmed
to 80 characters, escaped for `ILIKE`, capped at 20 results and always scoped to
active memberships in the verified current organization. Forms send team/member IDs
only to routes whose domain operations re-resolve the tenant relationships.

All lifecycle and association operations emit structured events with keyed actor and
subject hashes; customer names and raw UUIDs are absent from event fields.

## Migration operations

The migration creates two new empty tables, so its inline indexes do not rewrite
existing rows. It adds organization-consistency foreign keys and check constraints
under ordinary DDL locks. Deploy during the normal migration phase before processes
write team data. Rollback drops only these new tables; no pre-existing rows are
rewritten.
