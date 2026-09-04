# Unified permission, entitlement and quota access boundary

`Authorization::AccessBoundary` is the only application-level admission path for a protected billable
operation. It composes, but does not merge, the existing RBAC, Entitlements and Usage responsibilities.
Callers provide one immutable `Authorization::AccessRequest` with the actor membership, permission, tenant
scope, optional typed resource state, optional entitlement key, and the complete optional quota-reservation
context.

## Stable evaluation order

The boundary always evaluates:

1. authentication, active membership, tenant/scope linkage and RBAC permission;
2. the optional typed entitlement and its provenance;
3. the opaque resource's tenant/scope linkage and availability;
4. the optional atomic quota reservation.

The RBAC probe deliberately defers the supplied resource context to step three. A foreign actor or missing
permission therefore cannot trigger an entitlement lookup, inspect resource state or consume quota. A failed
entitlement or resource decision creates no hold. Unknown, malformed and `custom_required` entitlements fail
closed.

The immutable result exposes internal `stage`, `reason_code`, component decisions and provenance to trusted
application code. Clients receive only its bounded `public_error_code`: `authentication_required`,
`authorization_denied`, `entitlement_required`, `resource_conflict` or `quota_exceeded`. Resource linkage
mismatches use `authorization_denied`; they never disclose whether a foreign resource exists.

## Call sites and reservation ownership

Controllers use `authorize_access!` for synchronous work or `with_authorized_access` around the single job
enqueue. Domain/API entry points call `Authorization::Public.authorize_access!` or
`Authorization::Public.with_access`. User-context jobs re-establish the tenant from scalar user and
organization IDs through `Authorization::Public.authorize_job_access!`; they normally re-authorize without
creating a second reservation and receive the original reservation ID separately.

```ruby
with_authorized_access(
  "scans.run",
  project: project,
  resource: resource_context,
  entitlement_key: "crawl.manual",
  metered_quantity: estimated_urls,
  idempotency_key: command_id,
  usage_window: usage_window,
  usage_source: source_reference,
  reservation_expires_at: 1.hour.from_now,
  evaluated_at: Time.current
) do |decision|
  ScanJob.perform_later(scan_id: scan.id, reservation_id: decision.reservation.id)
end
```

If the block raises before enqueue ownership transfers, the boundary releases the hold with its own derived,
idempotent release key and re-raises the original error. A successful block leaves the hold for the worker to
finalize or release. Repeating the same admission request returns the same reservation; raw idempotency keys
are never stored or logged.

`script/check_access_boundary`, included in `bin/quality`, rejects commercial plan-name branching in feature
modules, direct quota public mutations outside this boundary, and direct quota model mutation outside the
Usage owner. This is a static guardrail; code review must still verify operation mapping and resource state.

## Feature operation registry

These are stable capability keys, not plan names or provider identifiers. Quantity is the raw operation count;
Usage applies the immutable effective weight before admission.

| Feature operation | Permission | Entitlement | Meter |
|---|---|---|---|
| Manual HTTP crawl work | `scans.run` | `crawl.manual` | `crawl.http_fetch` |
| Rendered crawl page | `scans.run` | `crawl.javascript_rendering` | `crawl.rendered_page` |
| Lighthouse page analysis | `scans.run` | `performance.lighthouse` | `performance.lighthouse_page` |
| Store listing locale snapshot | `properties.manage` | `app_discovery.store_audit` | `app_listing.locale_snapshot` |
| Deep-link validation target | `properties.verify` | `app_discovery.deep_links` | `deep_link.validation` |
| URL Inspection import | `integrations.manage` | `url_inspection.enabled` | `url_inspection.import` |
| HTML report generation | `reports.generate` | `reports.html` | `reports.generated` |

Non-metered operations use the same boundary while omitting the five metering attributes. Limits such as
`projects.max`, per-scan URL caps and concurrency are evaluated as resource/domain state by the owning module;
they are not usage-ledger reservations unless the meter catalog explicitly defines them.

## Observability and safety

Every terminal allow or deny emits `access.decision_evaluated`; successful holds also emit
`access.quota_reserved`. Labels contain only governed permission/reason codes and keyed tenant/scope context.
They never contain resource IDs, entitlement values, source IDs, raw idempotency keys or provider data.
