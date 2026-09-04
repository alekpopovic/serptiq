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
```

Sync is idempotent and writes drafts only. A changed definition with an existing non-draft key/version fails
closed. A successful non-empty sync records a system audit event; dry-run performs no writes or audit.

## Publishing and retiring

The `/dashboard/admin/plans` catalog is not tenant administration. Access requires an active
`plan_catalog_access_grants` row for the current user. `plan_catalog.publish` includes read access, while a
read-only grant cannot mutate. Grants are provisioned outside the customer application by reviewed platform
operations; there is intentionally no organization-owner path that can grant one.

Publish and retire require a recent authenticated session and an exact confirmation phrase. The domain
operation rechecks its signed-in-user decision, locks the selected version, performs a compare-and-update and
writes the audit event in the same database transaction. The PostgreSQL trigger rejects snapshot changes,
invalid reverse transitions and deletion after a version leaves draft, including direct SQL attempts.
The repository uses PostgreSQL `structure.sql` as its schema source so this trigger is also installed by a
clean test or production database setup; `schema.rb` cannot represent this integrity rule.

## Subscription history and roll-forward

A subscription references one `plan_version_id` and also copies its key, version, display name, currency,
pricing kind and selected interval price. Creating version N+1 never changes an existing reference. To change
commercial behavior:

1. increment the affected plan version in the YAML source;
2. validate and dry-run sync;
3. sync to create the draft;
4. review and publish it through the controlled administration path;
5. migrate explicitly selected subscriptions in a separately audited workflow, or leave them grandfathered.

Detailed scheduled activation, diff review, batch grandfathering and migration tooling is introduced by the
next catalog-governance prompt. Provider mapping remains a Billing adapter concern.
