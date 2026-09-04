# Scoped role assignments

## Contract

`Authorization::Public.assign_role` and `revoke_role` are the only ordinary mutation entry points.
They authorize the active actor again from persisted tenancy state, require an active same-organization
membership or team principal, validate the role and full scope chain, reject the `Owner` template, and
apply grant-subset/self-escalation rules. The database accepts only `allow`; the MVP has no arbitrary deny.

Assignments may target Organization, Project, or Property. Organization grants flow down to all active
descendants, project grants flow only to that project and its active properties, and a property grant never
flows upward or sideways. Only project-safe permissions survive at Project or Property scope. Effective
permissions are the union of active direct and active-team assignments, plus implicit current ownership.

Expired/revoked assignments, suspended or removed memberships, archived teams, archived scopes, archived
parent projects, inactive permissions, and archived custom roles contribute nothing. Effective resolution
uses one joined assignment/role/permission query after bounded tenancy and scope lookups; it does not load
each role or assignment separately.

## Scope projection

Project and Property aggregates arrive in later prompts. `authorization_scope_references` is therefore a
minimal Authorization-owned projection containing only opaque IDs, `organization_id`, property parent
project ID, and active/archive state. Future aggregate lifecycle operations call
`Authorization::Public.register_scope`. Composite foreign keys enforce the typed same-tenant hierarchy and
bind every assignment to its scope.

## Invitation bridge

`Authorization::Public.accept_invitation` composes Tenancy acceptance with the ordinary role assignment
operation. A bounded `initial_role_key` is resolved from the immutable system catalog and granted by the
original inviter under current authority. Membership activation, invitation consumption, and the role
assignment share one transaction; any role failure rolls all three back.

## Audit and operations

Assignment and revocation events carry keyed digests for organization, actor, principal, role, and scope,
plus low-cardinality principal/scope types. Raw UUIDs are not logged. Duplicate assignment uses a
fingerprint-specific PostgreSQL advisory transaction lock and a partial unique index; revocation uses a row
lock and is idempotent.

Migration `20260904080000_create_scoped_role_assignments.rb` creates two new tables and one small unique
role-catalog index. It rewrites no tenant data and has a verified automatic rollback/forward path.
