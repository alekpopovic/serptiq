# Property environments and canonical origins

`Properties::CanonicalOrigin` is the single admission parser for environment origins. It stores lowercase
ASCII IDNA host/origin values for network identity and derives normalized Unicode display values. HTTP port 80
and HTTPS port 443 collapse from the canonical string while remaining explicit effective-port fields. A root
slash and one DNS trailing dot collapse; credentials, other path/query/fragment content, invalid labels,
ambiguous authority syntax, IP literals, single-label names and internal naming suffixes are rejected.

An exact-origin comparison uses the full scheme, ASCII host and effective port. A host is in a domain boundary
only when it equals the boundary or ends in `.` plus that boundary. Parsing does not perform DNS, does not
classify resolved addresses and is never sufficient for crawler admission; every actual connection and
redirect remains subject to ADR 0006's resolver/connection policy.

`property_environments` belongs to the property aggregate and repeats organization/project/type/version only
for enforceable composite relationships. Keys and kinds are immutable. Active web properties have exactly one
active primary production row through a partial unique index plus deferred constraint triggers. Service
mutations lock the property before changing primary selection, mirror the selected origin to the typed website
configuration and invalidate the coarse property verification summary.

Environment routes require `properties.read` or `properties.manage` against the already tenant-scoped parent
project/property. Audit and outbox events retain stable IDs, lifecycle/type classifications and changed field
names but no origin, host, key or display label.
