# Typed entitlement resolution

`Entitlements` answers one question: which typed feature or limit value applies to an organization, and why?
It does not grant RBAC permission, count usage or reserve quota. `Authorization::AccessBoundary` composes
those independent decisions in the order required by ADR 0004.

## Governed catalog and synchronization

`config_blueprints/entitlements.yml` defines the exact 47 stable keys from
`config_blueprints/plans.yml`. Every definition includes type, unit, category, validation metadata, safe
default, security sensitivity and customer description. Validation checks every one of the five plan rows
has exactly those keys and that each value is valid for its definition.

```bash
bin/rails entitlements:catalog:validate
DRY_RUN=1 bin/rails entitlements:catalog:sync
bin/rails entitlements:catalog:sync
```

`plans:catalog:sync` also runs the entitlement synchronization after plan drafts exist. Initial sync creates
47 definitions and 235 plan values; repeat runs are idempotent. Definition identities/revisions are immutable.
Plan values may change only while their plan version is a draft, enforced by a PostgreSQL trigger as well as
the domain workflow.

The supported logical types are boolean, integer, decimal, enum and string. Inputs are exact: booleans are not
parsed from text, integer definitions reject floats and numeric strings, decimals require `BigDecimal`, enums
require an exact allowlisted string and strings retain explicit length/whitespace rules. Decimals are stored
as canonical strings to avoid binary floating-point ambiguity. The YAML `custom` marker becomes the separate
`custom_required` state and never an arithmetic sentinel.

## Resolver precedence and states

`Entitlements::Public.resolve(organization_id:, entitlement_key:, at:)` resolves:

1. an unrevoked organization override inside its `[starts_at, ends_at)` window;
2. the materialized value on the organization's active subscription plan version;
3. the definition's fail-closed system default when there is no subscription context.

A known key missing from an active plan version returns `misconfigured`; it does not silently fall back. An
unknown or malformed key returns `unknown`. Both are disabled for admission and produce only a bounded
operational reason code. Configured false/zero/`none` values return `disabled`; positive/true/other configured
values return `enabled`; a contract marker returns `custom_required`.

Billing installs the active subscription projection in the same PostgreSQL transaction as the subscription.
The projection's composite FK verifies the organization, subscription and plan version relationship. Resolver
cache entries live only in `Current`, are cleared at request/job boundaries, and include organization/key,
definition checksum, plan-value checksum, subscription ID/revision and override ID/revision. This cache is
never a source of truth.

## Organization overrides

Override creation/revocation is intentionally not a customer route. The public operation requires an active
membership in the exact target organization plus a global `plan_catalog.publish` decision bound to that
member's user. Custom and system organization roles cannot satisfy this requirement. Values are strictly
typed, reasons are bounded, validity is explicit, creator/revoker FKs are tenant-consistent and audit metadata
contains only the entitlement key, source and lifecycle status—not the reason or value.

Rows cannot be deleted or rewritten. Revocation is a one-way timestamped transition; replacement revokes the
previous row and creates a new row in one transaction.

## Diagnostics and deployment

`/dashboard/organizations/:organization_slug/entitlements` requires verified tenant context and
`plans.read`. It shows all effective values, states and application provenance. It intentionally contains no
provider variant IDs, billing credentials or claims about live provider state.

Migration `20260904090000` creates new definition/value/context/override tables, adds `lock_version` plus a
composite identity index to the small initial subscriptions table, backfills active subscription contexts and
installs integrity triggers. On a mature subscriptions table, add/backfill/validate the non-null revision in
phases; this MVP migration is safe for the currently small pre-launch table. Trigger creation and the
composite index briefly acquire PostgreSQL DDL locks, so deploy outside peak subscription writes.
