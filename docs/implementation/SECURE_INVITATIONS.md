# Secure organization invitations

Organization owners can issue, revoke, and resend invitations. The create response is neutral
about account existence. A resend terminates any pending token as `superseded` and sends a new
one; mail is delivered synchronously so a raw token is never serialized into Solid Queue.

## Token and browser boundary

Invitation tokens contain 256 random bits with a versioned `so_i1_` prefix. PostgreSQL stores
only a versioned HMAC-SHA-256 digest. The public entry endpoint checks token shape without a
database lookup, writes the raw token to a two-hour encrypted `HttpOnly`, `SameSite=Lax` cookie,
and redirects to sign-in with `/dashboard/invitations/review` as the fixed return path. Protected
environments use a `Secure` `__Host-` cookie. Token-bearing URLs are not copied into OAuth
transactions, forms, application logs, or database jobs.

Review and acceptance return `Cache-Control: no-store` and `Referrer-Policy: no-referrer`.
Invalid, expired, revoked, used, and wrong-email tokens share one accessible denial response.

## Acceptance policy

The authenticated user must have an active, non-revoked provider identity whose provider
asserted the exact normalized invitation email as verified. A local primary email or unverified
provider observation does not qualify. Acceptance locks the invitation, rechecks all state, and
creates at most one `(organization_id, user_id)` membership. Existing active or invited rows are
made active, and suspended rows are reactivated by this explicit acceptance. Removed rows are
retained and rejected for owner-reviewed recovery.

The optional initial role columns hold only an allowlisted organization-scoped intent. The RBAC
assignment prompt is responsible for converting that intent to an effective grant after its own
policy checks; an invitation never grants permissions merely by naming a role.

## Abuse controls and operations

HMAC-keyed fixed-window counters limit issue actor, destination email, and acceptance IP without
retaining their raw values. Structured events record successful and denied issue, acceptance,
revocation, expiration, and rate-limit outcomes without tokens or email addresses.

`Tenancy::InvitationMaintenanceJob` runs hourly on the maintenance queue. It expires pending
rows and deletes elapsed rate-limit buckets. The migration creates only new tables, indexes, and
constraints, so it does not rewrite existing product tables; it still takes brief schema locks
while adding foreign keys and should be deployed before web code that writes invitations.

Operational checks:

```bash
bin/rails runner 'p Tenancy::Invitation.group(:status).count'
bin/rails runner 'p Tenancy::InvitationRateLimitBucket.group(:scope).count'
bin/rails runner 'p Tenancy::InvitationMaintenanceJob.perform_now'
```
