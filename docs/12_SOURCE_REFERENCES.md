# Official Source References

Checked on **2026-09-04** unless an item states otherwise. These sources provide implementation constraints and terminology; they do not replace compatibility tests, legal review, provider agreements or current console configuration.

## Ruby and Rails

- Ruby release index: <https://www.ruby-lang.org/en/downloads/releases/>
- Rails 8.1 release notes: <https://guides.rubyonrails.org/8_1_release_notes.html>
- Rails 8.1.3.1 security release: <https://rubyonrails.org/2026/7/29/Rails-Versions-7-2-3-2-8-0-5-1-and-8-1-3-1-have-been-released>
- Rails security guide: <https://guides.rubyonrails.org/security.html>
- Active Record Encryption: <https://guides.rubyonrails.org/active_record_encryption.html>
- Active Job basics: <https://guides.rubyonrails.org/active_job_basics.html>
- Solid Queue README: <https://github.com/rails/solid_queue>
- Solid Cache README: <https://github.com/rails/solid_cache>
- Active Storage overview: <https://guides.rubyonrails.org/active_storage_overview.html>
- Rails performance/deployment guide: <https://guides.rubyonrails.org/tuning_performance_for_deployment.html>

## Authentication and OAuth

- OpenID Connect Core: <https://openid.net/specs/openid-connect-core-1_0.html>
- OAuth 2.0 Security Best Current Practice, RFC 9700: <https://www.rfc-editor.org/rfc/rfc9700>
- PKCE, RFC 7636: <https://www.rfc-editor.org/rfc/rfc7636>
- Google OpenID Connect: <https://developers.google.com/identity/openid-connect/openid-connect>
- JSON Web Token, RFC 7519: <https://www.rfc-editor.org/rfc/rfc7519>
- JSON Web Key, RFC 7517: <https://www.rfc-editor.org/rfc/rfc7517>
- GitHub OAuth application authorization: <https://docs.github.com/en/apps/oauth-apps/building-oauth-apps/authorizing-oauth-apps>
- GitHub authenticated user endpoint: <https://docs.github.com/en/rest/users/users#get-the-authenticated-user>
- GitHub authenticated email endpoints: <https://docs.github.com/en/rest/users/emails#list-email-addresses-for-the-authenticated-user>

## Billing

- Lemon Squeezy webhooks: <https://docs.lemonsqueezy.com/guides/developer-guide/webhooks>
- Lemon Squeezy webhook signing requests: <https://docs.lemonsqueezy.com/help/webhooks/signing-requests>
- Lemon Squeezy subscription object: <https://docs.lemonsqueezy.com/api/subscriptions/the-subscription-object>
- Lemon Squeezy API requests, authentication and pagination: <https://docs.lemonsqueezy.com/api/getting-started/requests>
- Lemon Squeezy create checkout: <https://docs.lemonsqueezy.com/api/checkouts/create-checkout>
- Lemon Squeezy customer object and signed portal URL: <https://docs.lemonsqueezy.com/api/customers/the-customer-object>
- Lemon Squeezy subscription management: <https://docs.lemonsqueezy.com/guides/developer-guide/managing-subscriptions>
- Lemon Squeezy subscription reconciliation list: <https://docs.lemonsqueezy.com/api/subscriptions/list-all-subscriptions>

## Google Search and performance

- Google Search technical requirements: <https://developers.google.com/search/docs/essentials/technical>
- Mobile-first indexing: <https://developers.google.com/search/docs/crawling-indexing/mobile/mobile-sites-mobile-first-indexing>
- Structured data introduction: <https://developers.google.com/search/docs/appearance/structured-data/intro-structured-data>
- Core Web Vitals and Search: <https://developers.google.com/search/docs/appearance/core-web-vitals>
- Web Vitals definitions and thresholds: <https://web.dev/articles/vitals>
- Search Console Search Analytics query: <https://developers.google.com/webmaster-tools/v1/searchanalytics/query>
- Search Console URL Inspection: <https://developers.google.com/webmaster-tools/v1/urlInspection.index/inspect>
- Chrome UX Report API: <https://developer.chrome.com/docs/crux/api/>
- CrUX History API: <https://developer.chrome.com/docs/crux/history-api/>
- Lighthouse: <https://developer.chrome.com/docs/lighthouse/overview/>

## Crawling and discovery

- Robots Exclusion Protocol, RFC 9309: <https://www.rfc-editor.org/rfc/rfc9309>
- IndexNow documentation: <https://www.indexnow.org/documentation>
- OpenAI crawlers and user agents: <https://platform.openai.com/docs/bots>

## Mobile applications

- Android App Links: <https://developer.android.com/training/app-links>
- Add Android App Links: <https://developer.android.com/training/app-links/add-applinks>
- Apple Supporting Associated Domains: <https://developer.apple.com/documentation/xcode/supporting-associated-domains>
- Apple App Store product page: <https://developer.apple.com/app-store/product-page/>
- Google Play store listing: <https://play.google.com/console/about/storelistings/>

## Deployment

- Kamal installation: <https://kamal-deploy.org/docs/installation/>
- Kamal configuration overview: <https://kamal-deploy.org/docs/configuration/overview/>

## Interpretation policy

Where provider documentation changes, update:

1. this reference list;
2. the related adapter contract;
3. rule metadata/version;
4. affected tests and fixtures;
5. customer-facing explanations;
6. the relevant ADR when architecture changes.

A source date or API response version should be retained when a rule result depends on a provider-specific limit or behavior.
