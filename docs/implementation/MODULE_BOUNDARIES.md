# SearchOps module boundaries

This document is the enforceable layout contract for the SearchOps modular
monolith. All modules run in the same Rails process and use the same PostgreSQL
database. A boundary expresses code ownership and dependency direction; it is
not a network or deployment boundary.

This contract implements [ADR 0001](../adr/0001_modular_rails_monolith.md) and
is governed by the [ADR index and lifecycle](../adr/README.md).

The machine-readable dependency graph is in `config/architecture.yml`. Run
`script/check_architecture` (or `bin/rails architecture:check`) before merging a
change that adds or changes a cross-module reference.

## Layout and ownership

Domain behavior belongs under `app/domains/<module>/`. Module-owned jobs,
policies and provider adapters use the same module directory below `app/jobs/`,
`app/policies/` and `app/adapters/`. Files immediately below those roots are
application infrastructure and must stay small. Controllers and views are
delivery code: they may invoke public operations and policies, but must not
contain domain decisions.

| Directory | Namespace | Responsibility |
|---|---|---|
| `identity` | `Identity` | Users, identities, authentication and sessions |
| `tenancy` | `Tenancy` | Organizations, memberships, invitations and teams |
| `authorization` | `Authorization` | Permissions, roles and access decisions |
| `billing` | `Billing` | Provider adapters, customers, subscriptions and webhook projections |
| `plans` | `Plans` | Plans and immutable published plan versions |
| `entitlements` | `Entitlements` | Typed organization feature values and overrides |
| `usage` | `Usage` | Usage windows, events, reservations and finalization |
| `projects` | `Projects` | Projects, environments and project settings |
| `properties` | `Properties` | Project properties and ownership-verification state |
| `verification` | `Verification` | Ownership challenges, evidence and verification lifecycle |
| `crawling` | `Crawling` | Scans, frontier, fetch policy, robots, sitemaps, links and artifacts |
| `analysis` | `Analysis` | Versioned rule registry, execution and evidence contracts |
| `auditing` | `Auditing` | Append-only security and domain audit records |
| `findings` | `Findings` | Finding identity, occurrences, evidence, priority and trends |
| `issues` | `Issues` | Workflow, assignment, comments, suppressions and verification |
| `app_discovery` | `AppDiscovery` | Android/iOS associations and store-listing audits |
| `integrations` | `Integrations` | External connections, encrypted credentials and provider imports |
| `search_data` | `SearchData` | Search Console, URL Inspection, CrUX and Lighthouse source data |
| `releases` | `Releases` | Releases, baselines, comparisons, gates and status publication |
| `reporting` | `Reporting` | Immutable report snapshots and deliveries |
| `notifications` | `Notifications` | Notification rules, endpoints and delivery attempts |
| `administration` | `Administration` | Privileged cross-domain operational workflows |
| `shared` | `Shared` | The small, platform-owned primitives listed below |

`Properties` is separated from `Projects` so verification and crawler policy do
not expose project internals. `Auditing` is the code namespace for the `Audit`
capability named in the architecture blueprint. `Administration` may compose
public APIs from all modules but does not own their business rules.

This combined catalog preserves both the foundational architecture capabilities
and the explicit boundaries established by Prompt 002. Unrecognized module
directories are not an approved extension mechanism; add a reviewed catalog
entry and dependency rules before adding code.

Do not create a module directory merely as a placeholder. Its first class must
have a documented owner and purpose. Database tables remain under Rails'
standard migration and schema locations; ownership is stated in the owning
model and the migration name.

## Public APIs and allowed dependencies

Cross-module callable code lives under
`app/domains/<target>/public/` and uses `<Target>::Public::*`. This surface may
contain operations, immutable inputs/results, stable identifiers, read-model
interfaces and event contracts. Everything else in a module is internal.

For example, Projects may call `Tenancy::Public::ResolveMembership`; it may not
refer to `Tenancy::Membership`, even though Tenancy is an allowed dependency.
Identity may not call Billing at all. The complete allowlist is maintained in
`config/architecture.yml`; dependencies are one-way, and an omitted edge is
prohibited.

The checker determines the source module from the first directory below one of
its configured source roots, extracts Ruby constant paths, and enforces both the
dependency allowlist and the `Public` namespace. Adding another owned source
root or module is a configuration change accompanied by checker tests.

The following access is always prohibited:

- reaching another module's models, internal operations or persistence details;
- invoking a controller, view or mailer from domain code;
- using callbacks to initiate a cross-module workflow;
- depending on a provider SDK outside the owning adapter;
- reading another module's table as an undocumented substitute for its public
  query/read model;
- introducing a circular dependency to make orchestration convenient.

Cross-module state changes use a target module public operation or a documented
outbox event. Reporting and Notifications consume stable read models/events.
Auditing consumes shared event envelopes and never makes business decisions.

Identity, Tenancy, Authorization and Plans may call the narrow `Auditing::Public.record!` append-only sink with
validated scalar identifiers and bounded metadata. Auditing never calls back into those modules; its
operator consistency report uses database relationship projections only and does not authorize customer
behavior.

Billing owns subscription persistence and obtains immutable commercial snapshots only through
`Plans::Public`. Plans owns the provider-neutral catalog and must not depend on Billing or store provider
price/variant identifiers. Platform catalog grants are distinct from organization RBAC: an organization owner
does not gain authority to publish global pricing. `Administration` composes the Plans catalog diff with
Billing subscriber counts and mapping summaries for review, consistency checks and subscriber-aware
retirement; neither domain reads the other's tables directly.

Entitlements owns typed definitions, materialized plan values, organization overrides and the request-scoped
resolver. Billing calls `Entitlements::Public.bind_subscription` in the subscription transaction; a composite
database FK makes that projection tenant/plan-consistent without Entitlements reading Billing models.
Entitlements may consume immutable plan snapshots through `Plans::Public` and append override/catalog events
through `Auditing::Public`. It never calls Authorization or treats a role as a feature grant. Override
operations accept only an already-approved global plan-catalog publication decision tied to the creating
organization member; ordinary or custom organization roles are insufficient.

Usage owns logical meter/rate definitions, immutable period windows, append-only events, compensating
corrections, atomic quota reservations and aggregate read models. It consumes plan credit weights through
`Plans::Public`, current admission context and immutable subscription/plan snapshots through
`Entitlements::Public`, and writes catalog/manual-adjustment evidence through `Auditing::Public`. Manual
adjustments reuse the platform publication authority contract and require same-organization active
membership; tenant domains never receive a public counter-mutation API. Quota callers use only
`Authorization::Public.with_access` for initial quota admission and pass a source already resolved within the
same tenant. Workers use `Usage::Public` extend/finalize/release operations against the already authorized,
tenant-bound reservation ID.

Customer-facing pricing reads published immutable versions through `Plans::Public`, while entitlement labels
come from `Entitlements::Public`. Billing exposes only tenant subscription summaries and boolean checkout
availability; provider variant identifiers are never presentation data. Organization usage pages call the
`Usage::Public` dashboard with a matching organization-scoped `billing.read` authorization proof.

## Shared primitives

`app/domains/shared/` is owned platform domain code, not a general utilities
folder. It has no domain dependencies. Its permitted locations are:

| Path | Purpose |
|---|---|
| `shared/identifiers/` | Validated, immutable typed IDs; not Active Record models |
| `shared/money/` | Currency-aware immutable money values and arithmetic |
| `shared/clocks/` | Injected wall/monotonic clocks used by domain operations |
| `shared/encryption/` | Application encryption interfaces and key-version metadata |
| `shared/idempotency/` | Idempotency keys and execution-result contracts |
| `shared/errors/` | Domain error base types and stable error codes |
| `shared/events/public/` | Versioned event envelopes and outbox-facing contracts |

Generic framework configuration remains in `config/`; repository tooling stays
in `script/support/`; Rake entry points stay in `lib/tasks/`. Code must not be
placed in `lib/` merely because no owner was chosen. A shared primitive must
serve at least two named modules, remain free of their business logic, and have
tests at its own boundary.

## Naming conventions

- Commands and state-changing operations use an imperative verb and domain
  object, such as `Projects::Public::CreateProject`. They expose one explicit
  entry point (`call`) and immutable input/result values.
- Queries describe the returned question or collection, such as
  `Projects::Public::VisibleTo`. Read models end in `View`, `Summary` or
  `Snapshot` and are immutable.
- External adapters live in `app/adapters/<module>/<provider>/` and end in
  `Adapter` or implement a named port such as `Billing::Provider`. Provider DTOs
  never escape the adapter boundary.
- Jobs live in `app/jobs/<module>/`, end in `Job`, accept explicit scalar/typed
  IDs, re-authorize tenant records, and delegate business work to a public or
  same-module operation.
- Policies live in `app/policies/<module>/`, end in `Policy`, and return explicit
  decisions. Views may display those decisions but never provide the only
  enforcement.
- Domain events use past tense (`ProjectCreated`), include an event version and
  tenant identifier, and are published only through the documented outbox.

Avoid the suffix `Service`; name an object for the operation, decision, adapter
or value it owns.

## Exception process

Prefer changing the design or adding a narrow public API. If a temporary
exception is unavoidable, the pull request must explain why, identify an owner,
include a removal issue and expiry date, and receive architecture-owner and
target-module-owner approval. Add a narrow entry to `exceptions` in
`config/architecture.yml` with all of:

`source`, `target`, `path_pattern`, `constant_pattern`, `reason`, `owner`, and
`expires_on`.

Wildcards must cover the smallest possible path and constant. The checker
rejects incomplete and expired entries. Exceptions authorize only a static code
reference; they never waive tenant isolation, authorization, entitlement,
quota, encryption or network-safety rules.
