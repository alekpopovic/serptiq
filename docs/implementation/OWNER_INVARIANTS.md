# Owner and member lifecycle invariants

SearchOps ownership is one explicit current `organization_ownerships` relationship, not a role assignment or a
team-derived grant. `Tenancy::OwnerInvariant` locks the organization, current ownership and active owner
membership in one canonical order. Membership suspension/removal uses that locked state and returns the
`last_owner_transfer_required` conflict when the target is the current owner. Owners must complete the dedicated
recent-authenticated transfer first.

Role and team changes verify the same owner state but cannot grant, revoke or derive ownership. Removing a role
or team membership from the current owner therefore removes only that additive grant; implicit owner permissions
remain. Organization lifecycle transitions also require the locked current owner and retain the ownership
history relationship.

The schema-dump-safe composite foreign keys and checks installed by migration `20260904082000` validate at
transaction commit that every organization points to its own current unended ownership and that the referenced
membership is active. The existing unique partial index permits only one unended ownership. Deferral permits
atomic organization creation and transfer while rejecting an ownerless committed state. Marker columns are
bounded internal FK projections maintained together with ownership lifecycle changes; they do not replace the
canonical timestamps or membership status.

Suspension and removal revoke every active identity session for the affected user. Existing role assignments and
team membership rows remain for attribution, but permission resolution requires an active membership and grants
nothing. Suspension followed by an explicit reactivation restores those recorded grants; removal is terminal.
Queued user-context work is not trusted or silently executed: jobs reload the explicit user/organization/resource
IDs and fail authorization when the membership is no longer active. No serialized `Current` state is used.

Future issues, reports and audit records must retain their historical membership foreign keys. Removal never
rewrites the actor who performed historical work. A later workflow may reassign open work items separately, but
that is not an ownership or attribution rewrite.

Operators run `bin/rails tenancy:ownership:check`. A healthy result is exactly zero issues. Any nonzero result is
an incident: stop owner/member lifecycle writes, preserve the reported organization IDs and database evidence,
and repair only through a reviewed migration or the normal transfer service. Direct ad-hoc SQL is not a normal
recovery path.

## Migration operations

The migration adds nullable projection columns first, backfills the low-volume ownership-history table, then
adds defaults/nullability. Supporting composite indexes use `CONCURRENTLY`; check constraints and foreign keys
are installed unvalidated and validated separately. The backfill briefly takes row locks on ownership history,
so deploy it outside an active ownership-maintenance batch. No membership, session or high-volume analytical
table is rewritten.
