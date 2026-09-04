# Typed property aggregate

Properties are immutable-child identities below one organization-owned project. Version 1 supports
`website`, `web_application`, `android_app` and `ios_app`. Adding or changing a type is an explicit domain and
database migration; the generic property table does not contain an arbitrary settings JSON object.

## Typed configuration

Website and web-application rows have exactly one `website_property_configs` record containing scheme, host,
effective port and canonical HTTP(S) origin. Android rows have one normalized package-name record. iOS rows
have one normalized bundle/Team identifier record. Composite foreign keys bind every configuration to the
same organization, project, property kind and configuration schema version.

The initial website value rejects credentials, paths, queries, fragments, IP literals and unqualified hosts.
Prompt 052 owns complete IDNA/network normalization and the multi-environment aggregate. Creating a property
never proves ownership; verification remains an explicit observed, expiring and revocable state.

## Authorization and limits

Creation and mutation require `properties.manage` at the active parent project or exact property scope;
reads use `properties.read`. Organization grants inherit through the project. Project grants inherit to all
children. Property grants expose only the exact active property. Creating the authorization scope does not
create an assignment.

`website_properties.max` counts active website plus web-application properties per organization.
`mobile_properties.max` counts active Android plus iOS properties. Create and reactivate operations use a
group-specific PostgreSQL advisory transaction lock before counting, preventing concurrent limit overflow.
Archived rows retain names and normalized identifiers and do not consume active capacity or permit scans.

## History and read models

Create, material configuration updates, archive and restore append tenant-bound audit events and durable
Property outbox events. Audits contain classifications only, never configured identifiers. A configuration
change clears the verification summary to `unverified` so stale proof cannot authorize future work.

Lists search bounded display/type fields, paginate at 25 records and bulk-preload typed configurations.
Property project-rollup counts use one grouped query and retain explicit `not_observed` health and
`not_available` scan states until their owning modules provide evidence.

## Migration operations

Migration `20260904131000` creates four new empty tables, typed composite foreign keys, check constraints,
unique indexes and a stable-property-identity trigger. It also adds one unique index to the existing
authorization scope projection so the full child hierarchy can be referenced. This additive DDL takes
ordinary PostgreSQL catalog/index locks. Rollback deletes all property/configuration data and is safe only
before retained customer property history exists.
