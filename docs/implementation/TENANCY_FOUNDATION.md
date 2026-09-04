# Tenancy Foundation

Prompt 024 establishes the first customer-owned aggregate. Tenant access is never
derived from possession of an organization UUID or slug.

## Durable data invariants

- Organizations, memberships and ownership assignments use UUID primary keys.
- Slugs are transliterated, lowercased and hyphenated, then protected by a
  case-insensitive unique index while the organization is not deleted.
- Database checks constrain organization and membership lifecycle timestamps.
- A membership belongs to exactly one organization and one identity user. The
  unique organization/user pair is the durable history that later lifecycle
  operations reactivate.
- An ownership assignment uses a composite foreign key so its membership must
  belong to the same organization.
- Every organization has a non-null `current_ownership_id`. Its deferred foreign
  key permits all three initial records to be inserted in one transaction while
  rejecting an ownerless state at commit.

Ownership is deliberately distinct from ordinary RBAC. The owner membership and
dedicated ownership assignment created here establish the non-removable authority;
the permission catalog and scoped role assignments are introduced by prompts 029
and 030.

## Context boundary

Tenant routes authenticate first and resolve the route selector only through an
active membership. Missing, foreign, suspended and malformed selectors share the
same public authorization denial. `Current.organization` and `Current.membership`
are assigned as one verified pair and Rails clears them after every request.

Background jobs receive explicit user and organization identifiers. The tenancy
boundary reloads both records, rechecks active membership and supplies the pair
inside a bounded `Current` scope. `ApplicationJob` resets all current attributes
before and after execution, including failures.

Tenant domain models have no `default_scope`. Callers use the public context
resolver or explicit organization predicates. The switcher returns immutable
summaries for active organization/membership joins only.

## Audit and privacy

Creation, rename/slug change and lifecycle attempts emit structured outcome and
operation fields. Customer names and slug values are not included in event fields.
Unauthorized selectors receive the same response shape and cannot reveal foreign
organization names or switcher counts.

## Migration operations

The migration creates three new empty tables, so it does not rewrite existing
customer rows. The active-slug and membership indexes are built inline and take
ordinary DDL locks; deploy during the normal migration phase before application
processes depend on these tables. Rollback removes the circular ownership foreign
key before dropping tables. Future ownership transfer code must update the current
pointer and assignment history in a single transaction.
