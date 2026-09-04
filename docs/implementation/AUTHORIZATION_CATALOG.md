# Authorization catalog

`config_blueprints/permissions.yml` is the governed source for 57 stable permission keys and
eight system-role templates. Each permission declares a non-empty category and description,
risk (`low`, `medium`, `high`, or `critical`), and scope. `organization` permissions are never
effective from a future project-scoped assignment; `project` permissions may be narrowed to a
project or inherited from an organization assignment.

The eight reserved templates are Owner, Organization Admin, Billing Admin, SEO Lead, Developer,
Content Editor, Analyst, and Viewer. Owner includes every customer permission, but ownership is
still represented by the dedicated tenancy ownership record. Code must authorize by effective
permission, never by a role name.

## Validate, synchronize, and review

```bash
bin/rails authorization:catalog:validate
bin/rails authorization:catalog:sync
bin/rails authorization:catalog:report
```

`db:seed` runs the same sync. Validation rejects duplicate permission/role keys, duplicate or
unknown grants, missing category/description/scope, invalid risk/scope values, a partial Owner
grant, or a change to the reserved role set.

Sync validates before opening a transaction, takes a PostgreSQL advisory transaction lock,
preserves stable row IDs, updates metadata, reconciles catalog-managed grants, and records the
exact YAML SHA-256 once in `authorization_catalog_revisions`. A second identical sync performs
zero writes. If any existing permission or system-role key disappears, sync fails before adding
or changing rows. Renames therefore require an explicit reviewed data migration; YAML removal
never silently deletes or deactivates an in-use permission.

The report prints checksum, permission scope/risk, and the complete role matrix for development
or administrative review. It is deliberately a command rather than a public web page while the
full authorization decision and administration layers are not yet available.

## Immutability and deployment

System roles have `organization_id = NULL`, `system = TRUE`, `mutable = FALSE`, a catalog
checksum, a reserved key, and no archive timestamp. Database constraints reject any other
ownership shape. Persisted system roles, their grants, and catalog revision rows are read-only
through models; only the catalog sync uses constrained bulk writes. Organization custom roles
use the opposite ownership shape and cannot claim reserved keys.

The migration creates four new empty tables with inline indexes, foreign keys, and CHECKs; it
does not rewrite an existing table. Deploy the migration before running sync, then run sync
before processes depend on permission lookups. Every catalog edit should include the generated
matrix comparison test and a review of removed or reduced grants.
