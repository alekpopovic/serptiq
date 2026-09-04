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

## 5. Entitlement precedence

1. Platform emergency deny.
2. Time-bounded organization override.
3. Active subscription's immutable plan version.
4. Trial or default free plan version.
5. Definition-level safe default.

The resolver returns the value and provenance. Unknown keys fail closed and emit an operational error.

## 6. Subscription access states

| Provider/business state | Application behavior |
|---|---|
| Trialing/active | Full effective plan access |
| Payment failed, early grace | Existing data remains readable; bounded writes may continue per policy |
| Past due after grace | Read-only except billing, export, and remediation required for account access |
| Canceled at period end | Full access until effective end; display exact date |
| Expired | Fall back to retention-safe read-only/free behavior; no silent data deletion |
| Fraud/security suspension | Block privileged actions; preserve audited support path |

Provider status and application `access_state` are separate fields.

## 7. Upgrade and downgrade rules

- Upgrade may become effective immediately after a verified provider event.
- Downgrade normally becomes effective at period end.
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

## 9. Plan-version migration and grandfathering policy

- `config_blueprints/plans.yml` is the governed commercial source. Validate it with
  `bin/rails plans:catalog:validate` and preview changes with `DRY_RUN=1 bin/rails plans:catalog:sync`.
- Synchronization creates or updates drafts only. Any checksum difference for a published, retired or
  grandfathered version is rejected; change the per-plan version number instead.
- Publishing requires the platform-scoped `plan_catalog.publish` grant, recent authentication and the exact
  confirmation phrase displayed by the administration screen. Publish and retire outcomes are audited.
- Existing subscriptions retain their exact `plan_version_id` and copied display/pricing metadata when a new
  draft or published version appears. No catalog sync silently migrates customer state.
- Grandfathering means the old immutable version remains usable by subscriptions already attached to it but
  is not a target for new subscriptions. An explicit, audited migration must select subscriptions, preserve a
  before/after record and define rollback and customer communication before moving them.
- Provider price or variant identifiers are environment-specific Billing mappings. They must never be added
  to the provider-neutral plan catalog or used as commercial branching keys.

The initial migration creates new, empty tables and takes only catalog-level locks. Apply it before catalog
sync; the PostgreSQL trigger installed by the migration is required for direct-SQL immutability enforcement.
