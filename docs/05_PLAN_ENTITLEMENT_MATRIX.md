# Plan, Entitlement, and Quota Matrix

## 1. Commercial hypothesis

Prices and limits are initial hypotheses, not immutable promises. Validate them against conversion, retained usage, gross margin, and support cost before public launch.

| Plan | Monthly | Annual | Positioning |
|---|---:|---:|---|
| Free | €0 | €0 | Evaluation and very small sites |
| Starter | €39 | €390 | Small teams and consultants |
| Growth | €129 | €1290 | Product teams and established agencies |
| Agency | €349 | €3490 | Multi-client operations and white-label reporting |
| Enterprise | custom | custom | Contracted capacity, controls, and SLA |

## 2. Entitlement matrix

An entitlement is a typed capability or configured limit. `custom` means contract-defined, not unlimited. `none` disables the capability.

| Key | Type / unit | Description | Free | Starter | Growth | Agency | Enterprise |
|---|---|---|---|---|---|---|---|
| `projects.max` | integer / projects | Maximum active projects | 1 | 3 | 15 | 75 | `custom` |
| `members.max` | integer / members | Maximum active organization memberships | 1 | 3 | 10 | 25 | `custom` |
| `teams.max` | integer / teams | Maximum active teams | 0 | 1 | 10 | 50 | `custom` |
| `roles.custom` | boolean | Custom organization roles | — | — | — | ✓ | ✓ |
| `website_properties.max` | integer / properties | Maximum active website properties | 1 | 5 | 30 | 150 | `custom` |
| `mobile_properties.max` | integer / properties | Maximum active Android+iOS properties | 0 | 0 | 4 | 25 | `custom` |
| `crawl.manual` | boolean | Manual scans | ✓ | ✓ | ✓ | ✓ | ✓ |
| `crawl.credits_monthly` | integer / credits | Weighted monthly analysis credits | 500 | 25,000 | 150,000 | 750,000 | `custom` |
| `crawl.max_urls_per_scan` | integer / urls | Maximum discovered/fetched URLs in one scan | 500 | 10,000 | 50,000 | 200,000 | `custom` |
| `crawl.concurrent_scans` | integer / scans | Concurrent running scans per organization | 1 | 1 | 3 | 10 | `custom` |
| `crawl.schedule` | enum | Fastest allowed recurring scan schedule | `none` | `weekly` | `daily` | `hourly` | `custom` |
| `crawl.javascript_rendering` | boolean | Chromium rendering | — | — | ✓ | ✓ | ✓ |
| `crawl.max_rendered_pages_per_scan` | integer / pages | Hard render-page cap in one scan | 0 | 0 | 1,000 | 10,000 | `custom` |
| `crawl.targeted_rescan` | boolean | Targeted URL verification rescans | ✓ | ✓ | ✓ | ✓ | ✓ |
| `crawl.custom_user_agent` | boolean | Organization/project custom crawler suffix | — | — | ✓ | ✓ | ✓ |
| `crawl.custom_rules` | boolean | Configurable thresholds for supported rules | — | — | ✓ | ✓ | ✓ |
| `data.normalized_retention_days` | integer / days | Normalized scan and finding occurrence retention | 7 | 90 | 365 | 730 | `custom` |
| `data.raw_artifact_retention_days` | integer / days | Raw HTML/DOM/screenshot/Lighthouse retention | 1 | 14 | 30 | 90 | `custom` |
| `data.export` | boolean | Organization data export | ✓ | ✓ | ✓ | ✓ | ✓ |
| `search_console.enabled` | boolean | Google Search Console connection | — | ✓ | ✓ | ✓ | ✓ |
| `search_console.history_months` | integer / months | Imported Search Analytics history retained | 0 | 3 | 16 | 24 | `custom` |
| `url_inspection.enabled` | boolean | Google URL Inspection imports | — | — | ✓ | ✓ | ✓ |
| `url_inspection.monthly_urls` | integer / urls | Monthly URL Inspection import allowance | 0 | 0 | 500 | 5,000 | `custom` |
| `performance.crux` | boolean | CrUX field data | — | ✓ | ✓ | ✓ | ✓ |
| `performance.lighthouse` | boolean | Lighthouse lab analysis | — | ✓ | ✓ | ✓ | ✓ |
| `performance.lighthouse_pages_per_scan` | integer / pages | Sampled Lighthouse page cap per scan | 0 | 5 | 50 | 250 | `custom` |
| `ai_crawlers.policy_matrix` | boolean | AI crawler robots/accessibility matrix | — | ✓ | ✓ | ✓ | ✓ |
| `app_discovery.deep_links` | boolean | Android App Links and iOS Universal Links validation | — | — | ✓ | ✓ | ✓ |
| `app_discovery.store_audit` | boolean | App Store and Google Play metadata audit | — | — | ✓ | ✓ | ✓ |
| `app_discovery.route_map` | boolean | Web-to-app route mapping | — | — | ✓ | ✓ | ✓ |
| `releases.enabled` | boolean | Release/deployment records | — | — | ✓ | ✓ | ✓ |
| `releases.regression_gate` | boolean | Automated release regression evaluation | — | — | ✓ | ✓ | ✓ |
| `releases.blocking_gate` | boolean | Allow explicit blocking CI status | — | — | — | ✓ | ✓ |
| `reports.html` | boolean | Immutable HTML reports | ✓ | ✓ | ✓ | ✓ | ✓ |
| `reports.pdf` | boolean | PDF report artifact | — | ✓ | ✓ | ✓ | ✓ |
| `reports.scheduled` | boolean | Scheduled report generation/delivery | — | — | ✓ | ✓ | ✓ |
| `reports.white_label` | boolean | White-label report branding | — | — | — | ✓ | ✓ |
| `notifications.email` | boolean | Email notification channel | ✓ | ✓ | ✓ | ✓ | ✓ |
| `notifications.slack` | boolean | Slack notification channel | — | ✓ | ✓ | ✓ | ✓ |
| `integrations.outgoing_webhooks` | boolean | Signed outgoing webhooks | — | — | ✓ | ✓ | ✓ |
| `api.access` | enum | Public API access level | `none` | `none` | `read` | `read_write` | `custom` |
| `audit.retention_days` | integer / days | Customer-visible audit log retention | 7 | 90 | 365 | 730 | `custom` |
| `audit.export` | boolean | Audit export | — | — | — | ✓ | ✓ |
| `security.sso_saml` | boolean | SAML SSO | — | — | — | — | ✓ |
| `security.ip_allowlist` | boolean | Organization IP allowlist | — | — | — | — | ✓ |
| `operations.dedicated_workers` | boolean | Dedicated crawl/render worker pool | — | — | — | — | ✓ |
| `support.level` | enum | Support level | `community` | `standard` | `priority` | `priority` | `contract` |

## 3. Weighted credit model

One monthly credit pool keeps pricing understandable while still reflecting infrastructure cost. Every operation creates immutable usage events with the operation-specific weight.

| Operation | Suggested weight | Notes |
|---|---:|---|
| `crawl.http_fetch` | 1 | One accepted HTTP response attempt, subject to failure policy |
| `crawl.rendered_page` | 10 | Isolated Chromium navigation and extraction |
| `performance.lighthouse_page` | 15 | Lighthouse lab run and artifact processing |
| `app_listing.locale_snapshot` | 2 | One platform listing locale snapshot |
| `deep_link.validation` | 5 | One complete hosted-association validation target |
| `url_inspection.import` | 2 | One bounded URL Inspection import in addition to provider quota |

Weights are configuration data with effective dates. Historical usage events retain the applied weight/version.

## 4. Access algorithm

```text
authorize member and scope
→ resolve typed entitlement with provenance
→ validate resource state and verification requirements
→ estimate weighted cost
→ atomically reserve quota in current usage window
→ enqueue idempotent work
→ finalize actual usage and release unused reservation
```

Never use plan-name conditionals in domain code. Use stable keys such as `crawl.javascript_rendering` and `crawl.credits_monthly`.

Prompt 057's guided project setup previews current resource counts and the effective `projects.max`,
`website_properties.max`, `mobile_properties.max`, `crawl.manual`, `crawl.max_urls_per_scan` and
`crawl.javascript_rendering` values before provisioning. It re-resolves them at completion, but creates no
usage event or quota reservation. A preview is an observation rather than a capacity hold; only a later
explicit scan request reaches quota admission.

## 5. Entitlement precedence

1. Platform emergency deny.
2. Time-bounded organization override.
3. Active subscription's immutable plan version.
4. Trial or default free plan version.
5. Definition-level safe default.

Prompt 038 implements organization override → active subscription projection → definition safe default. A
future platform-wide emergency deny composes above that result; a trial/free entitlement source must be an
explicit subscription projection and is never inferred from a missing subscription. The resolver returns the
strictly typed value, state and provenance. Unknown keys, a missing materialized plan value and malformed
security-sensitive data fail closed and emit a bounded operational event.

Values have explicit states: `enabled`, `disabled`, `custom_required`, `unknown` or `misconfigured`.
`custom_required` is not unlimited—it requires a concrete, audited organization override before admission.
Boolean strings, numeric strings, floats for integer definitions and symbols for enums are rejected rather
than coerced. Request caching includes definition checksum, plan-value checksum, subscription revision and
override revision, so a changed subscription or override cannot reuse the old decision.

## 6. Subscription access states

| Provider/business state | Application behavior |
|---|---|
| Pending/incomplete | Billing and remediation only; no reads, integrations or billable work |
| Trialing/active | Full effective plan access |
| Payment failed, first 7 days | Existing data and interactive entitled work remain available; scheduled work pauses |
| Past due after grace | Read-only except billing, export, and remediation required for account access |
| Paused | Read-only or suspended according to confirmed state; billing/remediation stays reachable |
| Canceled at period end | Full access until effective end; display exact date |
| Expired | Fall back to retention-safe read-only/free behavior; no silent data deletion |
| Fraud/security suspension | Block privileged actions; preserve audited support path |

Provider status and application `access_state` are separate fields.

Prompt 048 implements this matrix with a seven-day past-due grace deadline and exact cancellation deadline.
Deadlines are evaluated on every protected request, scheduled work pauses during grace, and retention-safe
reads remain available where specified. Immediate upgrades and period-end downgrades are durable, idempotent
intents; only mapped, validated provider events apply them. Entitlement projection changes, audit records and
outbox events share the canonical transaction, while existing quota reservations keep their admission snapshot.

## 7. Upgrade and downgrade rules

- Upgrade may become effective immediately after a verified provider event.
- Downgrade normally becomes effective at period end.
- A durable plan-change request does not change canonical access by itself; a mapped provider event confirms it.
- A running scan uses an entitlement and pricing snapshot taken when its quota reservation succeeds.
- Downgrade never truncates or silently deletes data immediately.
- Resources above the new limit become read-only/archived candidates; users choose what to archive.
- Existing customers remain on their exact plan version until an explicit migration.

## 8. Quota edge cases

- Duplicate request idempotency keys return the existing reservation/result.
- A canceled job finalizes actual consumed work and releases the rest.
- A worker crash leaves an expiring reservation that a recovery job can reconcile.
- Provider outage does not reset or grant unlimited quota.
- Administrative credits use audited adjustment events, never counter mutation.
- Usage counters are derived or transactionally maintained from immutable events and reservations.

Prompt 039 materializes the six weighted credit operations plus report generation as stable usage meters.
Weights have immutable effective versions, and each event retains its raw quantity, applied weight and billed
quantity. UTC-month meters always roll at UTC midnight; subscription meters require explicit provider period
instants. Usage history is corrected only with same-context compensating events. Prompt 040 materializes
durable pooled reservations. Admission stores requested and held values in billing units after the immutable
meter weight is applied; finalization appends actual usage and releases the difference. `capped` and
`unlimited` are distinct stored states with a nullable limit only for unlimited, while `custom` continues to
fail closed until an audited concrete override exists.

A successful reservation freezes the entitlement limit/provenance, override, subscription revision, plan
version and meter rate for that operation. Later upgrades or downgrades govern new reservations; an existing
hold may be extended and finalized only against its admission snapshot. Reservations never cross a usage
window, so a provider-period or UTC-month rollover starts with an independent balance.

Prompt 042 implements this access algorithm as `Authorization::AccessBoundary`. It evaluates RBAC before any
entitlement/resource observation, reserves only after all non-quota controls allow, and releases a hold when
the protected enqueue block raises. Feature-operation key mappings and caller APIs are documented in
`docs/implementation/ACCESS_BOUNDARY.md`.

Prompt 041 exposes only effective published offers on public pricing and includes an organization's exact
subscribed version on authenticated comparison, including grandfathered status. The organization-wide usage
screen derives used and reserved values from the ledger and reservations, distinguishes unavailable,
disabled and unlimited states, and requires `billing.read`. Plan-change controls additionally require
`billing.manage` and an active provider mapping; display prices do not initiate or confirm a charge.

## 9. Plan-version migration and grandfathering policy

- `config_blueprints/plans.yml` is the governed commercial source. Validate it with
  `bin/rails plans:catalog:validate` and preview changes with `DRY_RUN=1 bin/rails plans:catalog:sync`.
- Synchronization creates or updates drafts only. Any checksum difference for a published, retired or
  grandfathered version is rejected; change the per-plan version number instead.
- Publishing requires the platform-scoped `plan_catalog.publish` grant, recent authentication and the exact
  `PUBLISH <key> VERSION <n> AFTER <previous>` confirmation phrase displayed by the administration screen.
  The review shows additions, changed values, removals and active subscribers attached to the previous
  version. Publish and retire outcomes are audited.
- A definition may be published only as the next integer version. Its `effective_at` may be immediate or up
  to one year in the future. Checkout resolves the highest effective version for the requested stable plan,
  currency and interval; a latest effective retired/grandfathered version fails closed instead of falling
  back to an older commercial offer.
- Existing subscriptions retain their exact `plan_version_id` and copied display/pricing metadata when a new
  draft or published version appears. No catalog sync silently migrates customer state.
- Retiring a version with active subscriptions first marks it `grandfathered`; it becomes `retired` only after
  its active subscriber count reaches zero. Neither state is offered to new subscriptions. An explicit,
  audited migration must select subscriptions, preserve a before/after record and define rollback and
  customer communication before moving them.
- Upgrade targets have a higher catalog display order and use the `immediate` policy; downgrade targets have a
  lower order and use `period_end`; a same-family version migration is `explicit`. Missing, not-yet-effective,
  retired, grandfathered, wrong-currency and unsupported-interval targets return a closed unavailable result.
- Provider price or variant identifiers are environment-specific Billing mappings. They must never be added
  to the provider-neutral plan catalog or used as commercial branching keys. Run
  `bin/rails plans:catalog:consistency` to compare YAML, database drafts/current versions and active mapping
  metadata before release.

The catalog-governance migration creates two empty reference/mapping tables and installs/replaces triggers on
`plans` and `plan_versions`. Trigger installation briefly takes table-level DDL locks, so apply it before
catalog sync and outside peak write traffic. The PostgreSQL triggers are required for direct-SQL immutability
and deletion enforcement.
