# Authentication and first-run UI

The sign-in screen renders only configured Google and GitHub POST actions. An
unavailable provider is plain status copy, not a disabled form that appears to
work. No password control exists. The page distinguishes provider identity
verification from SearchOps' application-owned revocable session and explains
that provider observations do not grant organization access.

OAuth callback errors use the stable public error catalog and never render
callback state, authorization code, provider response, token, exception message
or provider-owned account details. Safe presentation varies only by broad action:
cancelled consent can be restarted, expired/consumed/invalid attempts must start
again, a collision requires an already-linked sign-in before Account security,
provider availability suggests a later retry, and internal failures show the
Request ID for support. HTTP status and `X-SearchOps-Error-Code` remain the
canonical machine contract.

## Local account profile

`GET/PATCH /dashboard/account/profile` edits only the local `display_name`,
allowlisted locale and Rails time-zone name. It never edits provider profile,
provider subject, provider email observation or primary email authority. Rails
escapes display values, validates lengths/enumerations and protects the form
with CSRF. No live provider request is made to render or update this page.

## First-run routing boundary

Dashboard entry asks `Tenancy::Public.first_run_status` for one explicit state:

- `no_organization` routes to organization-first guidance;
- `invited` routes to invitation-first guidance and explicitly avoids creating
  an organization;
- `returning` permits the normal dashboard.

Prompt 022 precedes the Tenancy schema. Its default boundary therefore returns
`no_organization` for an active user and never fabricates a membership or
invitation. Prompt 024 must replace this with real membership-backed returning
status, and prompt 028 must add the pending-invitation decision. The controller
contract is covered now with deterministic status fakes so those integrations
cannot silently reverse the routing semantics.

All screens use semantic headings, labelled native forms, visible focus through
the shared shell, status/alert roles and ordinary Rails links or form submits.
Hotwire enhances these controls but is not the authorization boundary.
