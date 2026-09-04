# Membership Lifecycle

Prompt 026 makes membership state explicit and durable.

## Data contract

One row represents a user's history in one organization. A unique
`(organization_id, user_id)` index prevents simultaneous invited/active rows and
preserves one attribution identity after removal. States and timestamps are:

- `invited`: no acceptance, suspension or removal timestamp;
- `active`: `accepted_at` is present;
- `suspended`: acceptance and suspension timestamps are present;
- `removed`: `removed_at` is present; acceptance remains null only when an
  invitation membership was removed before acceptance.

PostgreSQL checks enforce those combinations and a trimmed, 1–160 character
`display_name`. The display name is a membership attribution snapshot; list/detail
screens do not expose identity email. Membership records are never deleted by
lifecycle operations, so future issue/comment/audit foreign keys can retain their
authors after access removal.

## Operations and locking

Creation and status changes are centralized tenancy operations. Creation locks the
organization before checking the durable unique key. Status changes lock the actor,
organization and organization-scoped target before applying the allowlisted graph:

```text
active -> suspended -> active
active|suspended|invited -> removed
removed -> terminal
```

Only the active current owner may manage members until scoped RBAC is introduced.
The current ownership membership cannot be suspended or removed; the model also
rejects direct ordinary saves that deactivate it. Ownership transfer remains the
only path to changing that protected principal.

## Immediate access effects

Suspension and removal update the membership and revoke every active identity
session for the target user in the same primary-database transaction. Sessions are
global rather than tenant-bound, so revoking all is the conservative response to a
privilege change. Reactivation never restores a revoked token; the user signs in
again. Every request and job then reloads and reauthorizes the active membership.

Membership transition events carry keyed 24-character actor and subject hashes in
the bounded observability context. They never place raw membership IDs, names or
emails in structured logs. Rejected transitions—including last-owner and foreign
target attempts—emit stable denial reasons.

## UI and pagination

Owner-only member list and detail pages use explicit organization routes and a
server-side page size of 25. Invalid page inputs normalize to page one and page
numbers are bounded. Removed members remain visible with their safe attribution;
the UI offers no silent reactivation action. Invitation controls remain deferred to
the secured invitation prompt.

## Migration operations

The migration renames `joined_at`/`left_at`, backfills display names from the local
user record, rewrites legacy `left` to `removed`, then validates new checks and adds
the organization/status listing index. These operations take DDL locks and the
backfill updates every existing membership row, so production rollout must size the
maintenance window to membership volume. Rollback retains all rows: new `invited`
and `removed` states degrade to legacy `left` with bounded timestamps rather than
being deleted.
