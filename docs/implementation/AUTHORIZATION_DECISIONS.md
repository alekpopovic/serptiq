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
controller helpers and is included globally, but prompt 032 owns replacing existing owner-only controller,
view, job and API checks with explicit permission policies.

RBAC does not call Plans, Entitlements, Usage or Billing. Those independent results are composed only at the
later unified access boundary. Every decision emits bounded structured metadata; denied high/critical-risk
permissions use `authorization.denied_high_risk` with hashed actor, organization and scope identifiers.
