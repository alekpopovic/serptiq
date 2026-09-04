# Pricing, plan comparison and usage UI

The public `/pricing` page and authenticated organization plan comparison are read projections of effective
published `plan_versions`; templates do not branch on plan names or provider variant identifiers. Each page
shows catalog currency and monthly/annual intervals, custom pricing explicitly, and all governed entitlement
values with disabled, unavailable and contract-configuration states. Displayed prices are not charges and do
not imply tax treatment. Hosted checkout remains the only future authority for a purchase.

The authenticated page also includes an organization's exact subscribed plan version, including a
grandfathered version that is no longer offered. Upgrade or downgrade direction comes from catalog display
order. Billing controls require `billing.manage` and are actionable only when the configured provider has an
active mapping for the exact plan version, environment, currency and interval. Variant identifiers never
leave the Billing boundary.

Prompt 045 turns an eligible selected interval into a CSRF-protected POST that reserves one tenant checkout,
creates or reuses the tenant's provider customer and redirects only to the adapter's normalized HTTPS link. The
redirect response is `no-store` with a `no-referrer` policy. A provider-backed current subscription exposes a
separate short-lived portal action. The checkout return page reports the existing local projection and never
treats browser query parameters or the return itself as payment evidence.

The organization-wide usage page requires organization-scoped `billing.read` and obtains a tenant-bound
authorization proof before reading the ledger; project-scoped `usage.read` remains for later project views.
The page groups compatible meters into their logical pool, shows immutable used usage,
unexpired reservations, remaining capacity and the exact window reset time. Unlimited observation meters,
zero/disabled limits, custom or malformed unavailable limits and temporary holds have distinct labels.

At exhaustion, only new metered work is described as paused. Existing scans, reports and workspace data
remain reachable according to the subscription access policy. Quota error pages link back to usage, plan
comparison and the existing workspace without exposing source IDs, reservation keys or provider metadata.
