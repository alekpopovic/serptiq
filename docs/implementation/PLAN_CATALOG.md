# Plan catalog operations

SearchOps stores the five stable commercial families (`free`, `starter`, `growth`, `agency`, `enterprise`) in
`plans` and each commercial revision in `plan_versions`. Application behavior consumes entitlement keys; it
must never branch on display names or use a mutable plan row as a subscription contract.

## Governed synchronization

The source is `config_blueprints/plans.yml` (schema version 1). The loader rejects unknown or missing root and
plan fields, unexpected plan order/keys, incomplete entitlement matrices, invalid price shapes and malformed
credit weights before opening a write transaction.

```bash
bin/rails plans:catalog:validate
DRY_RUN=1 bin/rails plans:catalog:sync
bin/rails plans:catalog:sync
bin/rails plans:catalog:consistency
```

Sync is idempotent and writes drafts only. A changed definition with an existing non-draft key/version fails
closed, and a new definition must use exactly the next per-plan integer version. A successful non-empty sync
records a system audit event; dry-run performs no writes or audit. The consistency task fails when YAML and
database revisions drift, published changes lack a bump, YAML omits a draft, or a current paid interval lacks
matching active provider metadata for the current Rails environment.

## Publishing and retiring

The `/dashboard/admin/plans` catalog is not tenant administration. Access requires an active
`plan_catalog_access_grants` row for the current user. `plan_catalog.publish` includes read access, while a
read-only grant cannot mutate. Grants are provisioned outside the customer application by reviewed platform
operations; there is intentionally no organization-owner path that can grant one.

Before publication the screen shows field/entitlement additions, changes and removals, database drift and the
number of active subscriptions on the previous version. Publish requires the exact phrase
`PUBLISH <key> VERSION <n> AFTER <previous>`, the reviewed source checksum and previous version, plus an
optional effective time from now through one year ahead. These values are rechecked after locking the stable
plan and selected version, so stale or concurrent attempts fail closed. Retire requires
`RETIRE <key> VERSION <n>`.

Both actions require a recent authenticated session. The domain operation rechecks its signed-in-user
decision, performs a compare-and-update and writes the audit event in the same database transaction. Retiring
with active subscribers moves the version to `grandfathered`; a later retirement after the active count is
zero moves it to `retired`. The PostgreSQL trigger rejects snapshot changes, invalid reverse transitions and
deletion after a version leaves draft, including direct SQL attempts.
The repository uses PostgreSQL `structure.sql` as its schema source so this trigger is also installed by a
clean test or production database setup; `schema.rb` cannot represent this integrity rule.

## Checkout and plan changes

`Plans::Public.purchasable_version` selects the highest effective version for the exact plan key, currency and
billing interval. A future version is ignored until its activation time. Once the highest effective version
is retired or grandfathered, checkout is unavailable; selection never silently falls back to an older offer.
`Billing::Public.create_subscription_reference` rechecks that selection under lock before copying the
immutable subscription snapshot.

`Plans::Public.plan_change_target` classifies a higher display-order target as an immediate upgrade, a lower
one as a period-end downgrade and a same-family version change as an explicit migration. An unavailable,
wrong-currency, unsupported-interval, future, retired or grandfathered target raises a typed conflict. This
only selects policy; it does not migrate a subscription or call a provider.

## Subscription history and roll-forward

A subscription references one `plan_version_id` and also copies its key, version, display name, currency,
pricing kind and selected interval price. Creating version N+1 never changes an existing reference. To change
commercial behavior:

1. increment the affected plan version in the YAML source;
2. validate and dry-run sync;
3. sync to create the draft;
4. review and publish it through the controlled administration path;
5. migrate explicitly selected subscriptions in a separately audited workflow, or retire the old version and
   leave its active subscriptions grandfathered.

Provider mapping remains a Billing adapter concern. `billing_plan_provider_mappings` stores only bounded,
environment-specific metadata needed for consistency checks; provider synchronization and checkout contracts
remain owned by the later Billing provider work.

## Deletion and deployment safety

Stable plan rows cannot be deleted. Non-draft versions are permanently protected, and audit events also
protect reviewed drafts. Restrictive foreign keys from subscriptions, Billing provider mappings and the
append-only invoice/report snapshot reference registry preserve all linked commercial history.

The governance migration creates empty mapping/reference tables, then installs or replaces triggers on
`plans` and `plan_versions`. Trigger DDL briefly locks those tables; deploy outside peak catalog writes, run
the migration before synchronization, then run `plans:catalog:consistency`. No subscriber is automatically
migrated by either the migration or catalog sync.
