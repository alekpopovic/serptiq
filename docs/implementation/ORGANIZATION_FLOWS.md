# Organization Flows

Prompt 025 exposes the tenant foundation through server-rendered Rails routes that
remain useful without JavaScript.

## Creation and settings

Any authenticated active user may create an organization. Name, normalized slug,
default language and time zone pass through the tenancy domain operation; the
organization, owner membership and ownership assignment still commit atomically.
The identity session rotates after successful creation because the user gained a
new privilege boundary.

General settings require the verified active owner membership in the route's
organization. The route slug is never accepted as authority, and submitted forms
contain no organization ID. Billing and organization-security sections are honest
placeholders with no active control until their permission and entitlement flows
exist.

## Slug and redirect policy

Slugs are canonical lowercase route segments. `account`, `billing`, `invitations`,
`members`, `new`, `projects`, `roles`, `security`, `settings`, `switch`, and `teams`
are reserved in Ruby validation and PostgreSQL checks.

A successful rename stores the previous canonical slug in
`organization_slug_aliases`. Old links resolve to the organization only after the
same active-user and active-membership checks as a current slug, then return a 301
redirect to the canonical server-generated route. Missing, foreign and inactive
organizations retain the generic authorization response.

Current slugs and historical aliases live in separate tables. Every supported
create/rename operation therefore takes one transaction-scoped PostgreSQL advisory
lock before validating or changing that shared namespace. Case-insensitive indexes
protect each table, model validation checks the other table, and the lock prevents
cross-table application races. Direct SQL writers must use the same lock.

## Switcher and lifecycle presentation

The organization menu is built only from active memberships. Active organizations
have links; suspended and deletion-pending organizations have labelled, disabled
entries and cannot establish `Current` context. Deleted organizations are omitted.
Switcher links carry only an allowlisted destination key (`dashboard` or `settings`),
which is mapped to a local route on the server. Arbitrary URLs fall back to the
selected organization's dashboard.

Organization-scoped breadcrumbs and navigation paths are generated from verified
`Current.organization`. Project creation remains visibly unavailable until its own
authorization boundary is implemented.

## Migration operations

The migration adds a new empty alias table and a check constraint to organizations.
Adding that constraint briefly locks the existing organizations table and validates
all rows; deploy in the normal migration phase and confirm no pre-existing slug is
reserved. Alias indexes are created inline while the new table is empty.
