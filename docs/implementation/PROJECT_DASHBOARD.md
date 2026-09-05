# Project dashboard and baseline readiness

Prompt 061 turns the project detail page into a read-only operational overview without inventing scan or
finding metrics before those aggregates exist.

## Source boundaries

- `Projects::ProjectDirectory` supplies the authorized project summary.
- `Properties::PropertyDirectory` preloads typed configurations and environments for a bounded 25-row page;
  `Properties::ProjectReadinessQuery` derives active website, primary-environment and projected verification
  counts from the same authorized property visibility.
- `Usage::ProjectUsageReadinessQuery` accepts an exact `usage.read` project decision and reports the local
  crawl-credit ledger or the effective configured limit. The dashboard GET never reserves quota.
- `Integrations::DashboardReadinessQuery` accepts an organization-scoped `integrations.read` decision and
  reports only bounded Search Console connection health, never account identifiers or credentials.
- `Auditing::ProjectActivityQuery` accepts the exact `projects.read` decision and paginates append-only audit
  events whose target is that project. It returns no actor identifiers or metadata.

All authorization proofs are bound to the organization and exact project or organization scope. A proof
cannot be replayed for a sibling project or another tenant.

## Observation semantics

Dashboard observation values support `unavailable`, `loading`, `failed`, `stale`, `no_data`, and `ready`.
Each state has distinct copy. The scan card now reads the latest authorized persisted aggregate and maps active,
terminal-success, canceled and failed outcomes without consulting queue internals. A project with no scan shows
`no_data`; the finding card remains `no_data` until its owning aggregate arrives. Archived, pending-deletion, or
unauthorized observations show `unavailable`. Later prompts can update the values without changing the stable
Turbo targets:

- `project_scan_status_<public-project-slug>`
- `project_findings_status_<public-project-slug>`
- `project_properties_status_<public-project-slug>`

The page never reads Solid Queue internals and never enqueues work from a GET. The baseline button remains
disabled until the scan request workflow exists. Its explanation is derived from project lifecycle, property
and verification readiness, `scans.run`, `crawl.manual`, subscription access, and crawl-credit availability.

## Query and presentation limits

- Property pages contain at most 25 entries and retain independent `properties_page` navigation.
- Project activity pages contain at most 10 entries and retain independent `activity_page` navigation.
- Property configurations and environments are preloaded in a fixed number of queries; regression tests
  compare one-property and multi-property loads.
- Provider data, crawl evidence, finding evidence, and quota observations are labeled separately.
- Responsive tables use keyboard-focusable regions, status updates use `aria-live`, headings label sections,
  and the existing mobile navigation remains available at narrow widths.
