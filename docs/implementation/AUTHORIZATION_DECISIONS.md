# Authorization decisions

`Authorization::AccessRequest` is the immutable input contract. It contains the actor membership identity,
permission key, organization, optional project/property scope, and an optional typed `ResourceContext`.
The resource context exposes only opaque identity, tenant/scope linkage and availability; customer content
never enters authorization logs.

`Authorization::Decision` evaluates in fail-closed order:

1. authenticated actor and actor/organization agreement;
2. active organization and active persisted membership;
3. known active permission key;
4. existing, matching and active scope hierarchy;
5. permission/scope compatibility and resource linkage/state;
6. protected current-owner-only permission rules;
7. effective direct/team permission union.

The immutable `DecisionResult` returns `allow?`, a stable internal reason code and only the assignment IDs
that contributed the requested permission. Current ownership is reported as the non-record source
`organization_ownership`. Unknown keys fail closed. `organization.transfer` and `organization.delete`
remain current-owner-only even if unsafe custom-role data is inserted.

There is intentionally no decision cache: privilege and lifecycle changes affect the next evaluation within
the same request and across processes without an invalidation race. Representative multi-team resolution
has a bounded query test and uses the joined effective-permission query from prompt 030.

`Authorization::PolicyAdapter` is the UI/job/domain adapter. It returns decisions for capability hints and
raises `Authorization::AccessDenied` for enforcement. `Authorization::ControllerPolicy` exposes private
controller helpers and is included globally. Tenant controllers declare every public action with
`permission_required`, or use `authorization_exempt` with a bounded reason for entry points that cannot yet
have tenant context. Declarations run after verified tenant context establishment and before any tenant record
lookup. `permission_hint` evaluates extra UI capabilities before rendering; `allowed_to?` only consumes those
prior decisions and fails closed when a hint was not loaded. View visibility never replaces the required action
callback.

Organization-scoped actions declare the catalog permission directly:

```ruby
permission_required "organization.update", only: :update
permission_hint "organization.update", only: :show
```

Project- and property-scoped controllers pass their already tenant-scoped records to the enforcement call. A
property decision also carries its parent project so the registered hierarchy must match:

```ruby
authorize_permission!("projects.update", project: @project)
authorize_permission!("properties.manage", project: @project, property: @property)
```

The governed inventory is `config/authorization_inventory.yml`. It maps current tenant controller actions,
tenant domain operations and job policies to permission keys. `script/check_authorization_coverage`, included
in `bin/quality`, fails when a tenant controller action or job lacks a matching declaration, or when an
inventory permission is absent from the governed catalog.

Tenant domain services accept only the `DecisionResult` previously produced for the same active actor,
organization and organization-scoped permission. Calls without a decision retain the stricter owner-only
fallback for trusted maintenance and existing internal flows. This lets organization administrators use their
catalog permissions without weakening direct domain calls.

User-context jobs declare `requires_permission`, accept scalar user, organization and resource IDs, then call
`authorize_job!`. That helper reloads the active user/membership/organization, resolves the registered resource
scope, re-authorizes current privileges and resets `Current` after execution. Global maintenance jobs must
instead declare `system_authorization` with a specific name and reason; system policy is not an implicit bypass.

JSON authorization failures use `Authorization::ApiErrorContract`: a fixed `authorization_denied` code, stable
reason code and request ID. Permission, tenant and resource identifiers are intentionally omitted.

The core RBAC decision does not call Plans, Entitlements, Usage or Billing. `Authorization::AccessBoundary`
composes its result with the public Entitlements and Usage APIs without moving either responsibility into
RBAC. Every decision emits bounded structured metadata; denied high/critical-risk
permissions use `authorization.denied_high_risk` with hashed actor, organization and scope identifiers.

See [`ACCESS_BOUNDARY.md`](./ACCESS_BOUNDARY.md) for the protected billable operation contract, evaluation
order, controller/job/API adapters, reservation cleanup and feature-operation mapping.
