# Project and property scoped access

Prompt 059 completes the access contract for the customer-facing project,
property, environment, verification and crawl-policy surfaces. The executable
action map is `config/authorization_inventory.yml`; its `scope` metadata is
validated against the governed permission catalog by
`script/check_authorization_coverage`.

## Action map

| Surface and actions | Permission | Decision scope |
|---|---|---|
| Project index | `projects.read` | filtered project collection |
| Project new/create and guided setup | `projects.create` | organization |
| Project show | `projects.read` | exact project |
| Project edit/update | `projects.update` | exact project |
| Project archive/reactivate | `projects.archive` | exact project |
| Project deletion request | `projects.delete` | exact project plus recent authentication |
| Property index | `properties.read` | filtered children of the exact project |
| Property new/create | `properties.manage` | exact active project |
| Property show | `properties.read` | exact property and registered parent project |
| Property edit/update/archive/reactivate | `properties.manage` | exact property and registered parent project |
| Environment index/show | `properties.read` | exact property and registered parent project |
| Environment create/update/archive/reactivate | `properties.manage` | exact property and registered parent project |
| Ownership challenge show/create/attempt/revoke | `properties.verify` | exact property and environment |
| Search Console proof | `properties.verify` plus `integrations.manage` | exact property plus organization connection |
| Crawl-policy edit/update/reset | `scans.configure` plus `crawl.manual` entitlement | exact property and environment |

The two filtered collection actions use governed exemptions from a single
resource decision because one request can contain several independently scoped
rows. They are not anonymous or permission-free: the visibility resolver first
validates the active organization, membership, principals and scope hierarchy.
A request with no visible scope is forbidden. For an allowed request, the
tenant and visible-ID relation is built before search, count, ordering,
pagination or read-model loading.

## Inheritance and lifecycle

Organization grants flow to registered descendant projects and properties.
Project grants flow only to that project's properties. Property grants apply
only to their exact property and do not authorize the parent project, a sibling
property, membership, billing or other organization administration. Active
direct and team-derived assignments are unioned. Suspended memberships,
archived teams, removed team members, expired/revoked assignments and archived
resource scopes contribute nothing.

Archived project history and project restoration/deletion can be reached only
through a current organization-scope grant. An archived property under an
active project can be read or restored only through a current organization- or
parent-project grant. Exact archived-resource grants remain inactive. These are
the same rules used by the central decision resolver; collection visibility
does not implement a second, weaker lifecycle model.

## Route, UI and audit rules

Controllers resolve every nested row with the verified organization and all
parent identifiers. Domain operations repeat those predicates and authorize
the resulting registered hierarchy, so substituting a real property,
environment or challenge ID under another parent fails closed without exposing
customer content.

Navigation and action controls are evaluated capability hints. A project-only
viewer sees the permitted project entry but no member, team, plan, usage or
organization-settings navigation. A property-only member is not shown the
parent project's name or link unless `projects.read` is independently allowed.
Destination controllers and domain services remain authoritative.

Mutation audits take the actor membership ID from the successful authorization
decision and the organization/target IDs from the authorized aggregate. Failed
or cross-scope attempts do not create success audits. Audit metadata remains
bounded to operations, lifecycle/type classifications and changed field names;
project/property names, origins, proof tokens and provider payloads are absent.

## Verification contract

`test/support/scoped_authorization_examples.rb` provides reusable project and
property scope assertions. The policy matrix uses two organizations, two
projects and two properties per project and covers direct grants, team grants,
inactive principals and archived resources. Request tests cover scoped
search/count behavior and nested identifier substitution. The browser test
proves the project-restricted Viewer experience and absence of organization
administration controls.

No schema migration is required. This prompt tightens query admission,
presentation hints, the executable authorization inventory and regression
coverage around existing constrained relationships.
