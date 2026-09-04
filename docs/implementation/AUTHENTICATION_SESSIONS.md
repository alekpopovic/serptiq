# Native authentication and session foundation

SearchOps owns its authentication boundary. Provider adapters return verified
identity observations but do not own browser sessions. Google OIDC and GitHub
OAuth callbacks resolve their local user through the same explicit account
transition. The public domain boundary is `Identity::Public`:

- `issue_session` creates the first session after successful authentication;
- `authenticate_session!` resolves an opaque browser token from PostgreSQL;
- `rotate_session!` revokes the prior record before returning a new token;
- `revoke_session` performs an idempotent server-side revocation.

There is no password store and no Devise, OmniAuth or Doorkeeper middleware.
Provider protocol validation remains outside this foundation.

## Token and metadata handling

Session tokens contain 256 random bits and a version prefix. Only a keyed
SHA-256 digest is stored in `sessions`; the raw value exists transiently in an
`Identity::IssuedSession` and in the browser cookie. Its object inspection is
redacted. IP address and user-agent inputs are also stored only as keyed
digests, so the session table cannot reproduce those request values.

Sessions have a 30-day absolute lifetime and a 24-hour idle timeout. Last-seen
and metadata writes are limited to once every five minutes. Prompt 021 owns the
later device-management UI and any product-level timeout configuration.
`authenticated_at` records credential-backed session issuance/rotation
separately from database creation time, allowing explicit link flows to enforce
a deterministic 15-minute recent-authentication window.

`Current.user` and `Current.session` are populated only after a live session and
active user are resolved. The controller wrapper resets both before and after
every request, including exceptional responses. A malformed, expired, revoked
or inactive-user cookie is deleted and the request continues anonymously.

## Browser cookie policy

The cookie is `HttpOnly`, `SameSite=Lax`, scoped to `/`, and host-only (there is
no `Domain` attribute). Staging and production use the `__Host-` prefix and
always set `Secure`; development and test use a separate non-production name so
local HTTP remains usable. Deletion repeats the same scope attributes.

The application must continue to terminate public traffic over TLS with Rails
`force_ssl` and HSTS enabled in protected environments. The cookie contains no
user, organization, role or entitlement data.

## Request guards, redirects and logout

`Identity::LoginRequired` redirects anonymous HTML requests to `/sign-in` and
returns the stable `authentication_required` response for JSON. The
`Identity::AnonymousOnly` concern keeps authenticated users out of sign-in
screens. Return destinations pass through `Identity::SafeReturnPath`, which
accepts only local paths beneath explicitly allowlisted roots and discards query
strings and fragments. Absolute, protocol-relative, malformed and unlisted
paths fall back to `/dashboard`.

Logout is a `DELETE` request protected by Rails CSRF behavior. It revokes the
server record and expires the browser cookie. Authentication completion and
future privilege-sensitive operations call the protected controller helpers,
which always issue or rotate the token to prevent session fixation.
Provider sign-in issues a fresh opaque session only after its state, PKCE and
provider-specific identity validation plus account resolution. Explicit
provider linking rotates the exact bound recent session after the identity
mutation succeeds. Unlinking is a single database transaction that locks the
exact recent session and all of the user's provider identities, revokes the
selected identity, revokes the old session and issues its replacement. A
failure in any step rolls the entire unlink transition back.

The account-security workflow treats authentication as recent for 15 minutes.
Its link confirmation is signed, five minutes long and bound to one allowlisted
provider plus the exact server-side session. It contains no provider token and
cannot substitute a callback. Changing provider, browser session, signature or
expiry rejects the request before a new OAuth transaction is created.

## Security events and operations

The foundation emits allowlisted structured events named `session.issued`,
`session.rejected`, `session.rotated` and `session.revoked`. They contain only
outcome and stable reason codes; tokens and raw request metadata are never event
attributes. Durable user-visible audit records arrive with the Auditing module.

The migration creates new UUID `users` and `sessions` tables, indexes and check
constraints. On a new installation this has no table-rewrite or backfill cost.
Apply it with the normal bounded PostgreSQL migration lock timeout. Rollback
drops identity/session data and is therefore safe only before real accounts
exist; after deployment, use a reviewed forward migration.
