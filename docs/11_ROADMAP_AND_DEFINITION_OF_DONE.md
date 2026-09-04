# Roadmap and Definition of Done

## 1. Delivery model

The 120 prompts are an ordered implementation program. Prompts are deliberately smaller than product phases so every step can be reviewed, tested and reversed without hiding a large speculative change.

```text
Phase 00  Governance and repository bootstrap       000–005
Phase 01  Rails and operational foundation          006–013
Phase 02  Identity and sessions                     014–023
Phase 03  Organizations, membership and RBAC        024–035
Phase 04  Plans, entitlements, usage and billing    036–049
Phase 05  Projects, properties and verification     050–061
Phase 06  Safe crawling and rendering               062–077
Phase 07  Rules, findings and issue workflow        078–089
Phase 08  Search/performance integrations           090–099
Phase 09  Mobile discovery and release guard        100–107
Phase 10  Reporting, API and administration         108–113
Phase 11  Production hardening and launch           114–119
```

Execution order is controlled by dependencies in `tracking/prompt_catalog.csv`; numeric order is the normal path.

## 2. Milestone A — runnable foundation

Prompts: `000–013`

Exit criteria:

- compatible Ruby/Rails patch versions are pinned after verification;
- application boots in development, test and production mode;
- PostgreSQL-backed Solid components are configured;
- CI runs lint, tests, security checks, assets and container boot;
- health/readiness/version endpoints exist;
- structured logging and error taxonomy exist;
- repository boundaries and ADRs are enforced/documented.

## 3. Milestone B — secure SaaS control plane

Prompts: `014–049`

Exit criteria:

- Google OIDC and GitHub OAuth sign-in work without OmniAuth/Devise/Doorkeeper;
- sessions rotate and revoke correctly;
- organization membership, invitations, teams and scoped RBAC are enforced;
- tenant-isolation negative-path suite passes;
- plans are immutable/versioned;
- typed entitlements and atomic quotas exist;
- provider-neutral billing interface and Lemon Squeezy adapter work;
- signed webhooks are durable, idempotent and reconciled;
- subscription lifecycle deterministically controls access.

This milestone can support internal/admin-only onboarding but is not yet an SEO product.

## 4. Milestone C — first useful web audit

Prompts: `050–089`

Exit criteria:

- authorized users create projects, properties and environments;
- domain ownership can be verified;
- safe static crawl runs with quotas, cancellation and recovery;
- SSRF and redirect safety regression suite passes;
- object artifacts remain private;
- sitemap/robots/canonical/metadata/link/image/schema/rendering rules run;
- findings deduplicate and preserve occurrences;
- issues can be assigned, discussed and verified;
- the first scan creates a reproducible baseline.

This is the earliest meaningful private alpha.

## 5. Milestone D — continuous SearchOps

Prompts: `090–099`

Exit criteria:

- baselines and scan diffs identify regressions;
- Search Console data is imported with freshness/coverage disclosure;
- URL Inspection is labelled as Google-known indexed state;
- CrUX field data and Lighthouse lab data are separate;
- priority incorporates evidence and available traffic;
- scheduled scans execute idempotently and fairly.

This is the recommended closed-beta boundary for web-only customers.

## 6. Milestone E — web/mobile differentiation

Prompts: `100–107`

Exit criteria:

- Android App Links and iOS Universal Links can be validated;
- app-store listing snapshots and change history exist;
- web routes can be mapped to Android/iOS destinations and fallbacks;
- incoming release events are authenticated/idempotent;
- configurable regression policies produce pass/fail results;
- status can be returned to CI/CD without claiming ranking guarantees.

## 7. Milestone F — commercial pilot and production

Prompts: `108–119`

Exit criteria:

- immutable reports and scheduled delivery work;
- notifications, public API keys and signed outgoing webhooks are controlled by RBAC/entitlements;
- admin tooling avoids direct database mutation for routine support;
- audit/retention/export/delete workflows are documented and tested;
- observability, indexes, retention and capacity controls are in place;
- immutable production images deploy through Kamal;
- backup restore, rollback and security drills pass;
- pilot acceptance criteria and launch decision are recorded.

## 8. Product definition of done

A customer-visible feature is done only when all applicable items are satisfied:

### Behavior

- acceptance criteria are implemented;
- empty, loading, success, forbidden, quota-exhausted and failure states exist;
- accessibility and responsive behavior are reviewed;
- user-facing terminology distinguishes fact, inference and recommendation;
- no ranking guarantee or unsupported causal claim is shown.

### Domain/data

- organization ownership is explicit;
- database constraints reinforce validations;
- lifecycle transitions are defined;
- idempotency and concurrency behavior are specified;
- retention and deletion behavior are known;
- migration safety is reviewed.

### Access/commercial

- permission key is defined and enforced;
- entitlement key is defined when plan-controlled;
- quota/usage event exists when consumption is variable;
- admin/support override behavior is audited;
- downgrade/cancellation behavior is tested.

### Security/privacy

- threat model is updated;
- secrets and personal/customer data are redacted;
- hostile input is bounded and escaped;
- rate/size/time limits exist;
- tenant-isolation and negative-path tests exist;
- relevant audit event is emitted.

### Reliability/operations

- retry and permanent-failure behavior are explicit;
- metrics/logs/traces identify outcomes;
- alert/runbook exists for material failure;
- feature can be disabled or rolled back safely;
- provider outage behavior is graceful;
- cost-driving operations are metered.

### Verification

- automated tests pass;
- manual exploratory checks are documented where needed;
- documentation and API schemas are updated;
- tracker summary names real files and actual test commands;
- no unrelated or unexplained diff remains.

## 9. Prompt definition of done

A prompt may be marked `completed` only when:

1. all dependencies are completed or explicitly superseded;
2. its objective is implemented;
3. required tests were executed and results recorded;
4. acceptance criteria are checked against the actual repository;
5. docs/ADRs/config blueprints are synchronized;
6. migrations and security consequences are reviewed;
7. the working tree has no accidental generated files or secrets;
8. `prompt_tracker.rb complete` records a factual summary.

`completed_with_followup` is not a status. Unfinished required work means `blocked` or the prompt remains `in_progress`.

## 10. Launch scope

### Included in production MVP

- social login;
- organizations, projects, members, teams and scoped roles;
- plan/version/entitlement/quota/billing lifecycle;
- verified website properties;
- static and selected rendered crawling;
- core technical SEO rule set;
- findings, issues, assignment and verified resolution;
- Search Console, CrUX and Lighthouse;
- scheduled scans and regressions;
- Android/iOS deep-link validation;
- listing snapshots and web–app route map;
- release events and policy result;
- reports, notifications, API/webhooks and admin operations.

### Explicitly excluded

- proprietary global backlink index;
- global keyword/SERP warehouse;
- automatic bulk content publishing;
- guaranteed ranking outcomes;
- autonomous production-site modifications;
- unrestricted authenticated/private-site crawling;
- native mobile device farm;
- custom-role builder before Agency/Enterprise need is validated;
- multi-region active-active;
- Kubernetes;
- extracted crawler microservices without measured need.

## 11. Commercial pilot acceptance

Recruit a small pilot cohort fitting the target:

- agencies managing several client properties;
- SaaS/product teams with marketing site and application;
- at least one product with Android or iOS deep links;
- teams willing to connect Search Console and CI/CD in staging.

Pilot acceptance measures:

```text
time to first completed scan
time to first verified issue
percentage of detected high/critical findings triaged
percentage of fixes automatically verified
scan failure and false-positive rate
cost per static/rendered URL
weekly active projects
report usefulness
trial-to-paid intent
support hours per organization
```

Do not interpret increased issue count as customer value. Value is resolution, prevention and measurable operational adoption.

## 12. Launch decision

Launch requires a written go/no-go review covering:

- security and privacy risk;
- data isolation;
- billing/reconciliation;
- crawler abuse controls;
- provider compliance;
- reliability and cost;
- customer support and incident ownership;
- legal documents and data-processing obligations;
- pilot evidence and known limitations.

Known limitations remain visible in product documentation and sales material.
