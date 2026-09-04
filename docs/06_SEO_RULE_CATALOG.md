# SEO, Search, Performance, and App Discovery Rule Catalog

## 1. Rule philosophy

Rules produce evidence-backed observations, not ranking guarantees. A rule may fail technically while having low business impact, or pass while the page still performs poorly for reasons outside the platform's evidence.

Every executable version declares:

```text
stable rule key
immutable version
supported property kinds
required input artifacts
outcome contract
default severity
confidence calculation
evidence schema
recommendation template
verification method
cost class
provider/catalog versions when applicable
```

Outcomes are `pass`, `fail`, `warning`, `not_applicable`, `unknown`, and `error`. `unknown` and `error` are never silently converted to pass.

## 2. Initial catalog

| Key | Category | Default severity | Applies to | Input | Description |
|---|---|---:|---|---|---|
| `http.unreachable` | http | critical | website | fetch | The URL could not be fetched after bounded retries. |
| `http.server_error` | http | high | website | fetch | Final response is 5xx. |
| `http.client_error` | http | medium | website | fetch | Internal target resolves to 4xx. |
| `http.soft_404_suspected` | http | medium | website | snapshot | A successful response resembles an error/not-found page. |
| `http.redirect_loop` | redirect | critical | website | fetch | Redirect chain loops. |
| `http.redirect_chain_long` | redirect | medium | website | fetch | Redirect chain exceeds configured threshold. |
| `http.redirect_target_error` | redirect | high | website | fetch | Redirect terminates at an error or rejected destination. |
| `http.mixed_content_reference` | transport | medium | website | snapshot | HTTPS page references active HTTP resources. |
| `http.invalid_content_type` | http | medium | website | fetch | Response MIME conflicts with expected indexable HTML content. |
| `robots.txt_unreachable` | robots | medium | website | robots | robots.txt cannot be evaluated reliably. |
| `robots.syntax_warning` | robots | low | website | robots | robots.txt contains unsupported or malformed records. |
| `robots.blocks_property` | robots | critical | website | robots | Configured search crawler is blocked from the entire verified property. |
| `robots.blocks_sitemap` | robots | high | website | robots | Declared sitemap cannot be fetched under selected crawler policy. |
| `indexability.meta_noindex` | indexability | high | website | snapshot | An expected-indexable page declares noindex in HTML. |
| `indexability.xrobots_noindex` | indexability | high | website | fetch | An expected-indexable response declares noindex in X-Robots-Tag. |
| `indexability.conflicting_directives` | indexability | high | website | snapshot | Robots directives conflict across header, source, or rendered DOM. |
| `indexability.blocked_and_noindex` | indexability | medium | website | snapshot | A URL combines crawl blocking and noindex in a way that may prevent directive observation. |
| `indexability.accidental_nofollow` | indexability | medium | website | snapshot | Expected-indexable page applies page-level nofollow. |
| `sitemap.unreachable` | sitemap | high | website | sitemap | Sitemap or sitemap index cannot be fetched. |
| `sitemap.invalid_xml` | sitemap | high | website | sitemap | Sitemap XML is malformed or violates supported structure. |
| `sitemap.url_outside_property` | sitemap | medium | website | sitemap | Sitemap includes a URL outside allowed property hosts. |
| `sitemap.noncanonical_url` | sitemap | medium | website | snapshot | Sitemap URL resolves to a different canonical target. |
| `sitemap.error_url` | sitemap | high | website | fetch | Sitemap entry resolves to an error or redirect policy violation. |
| `sitemap.lastmod_future` | sitemap | low | website | sitemap | lastmod is materially in the future. |
| `sitemap.indexable_url_missing` | sitemap | low | website | scan | Important discovered indexable URL is absent from configured sitemaps. |
| `canonical.missing` | canonical | medium | website | snapshot | Expected-indexable HTML page has no canonical declaration. |
| `canonical.multiple` | canonical | high | website | snapshot | Page exposes multiple canonical declarations. |
| `canonical.invalid_url` | canonical | high | website | snapshot | Canonical value is invalid or unsafe. |
| `canonical.target_error` | canonical | high | website | fetch | Canonical target resolves to error or unsafe destination. |
| `canonical.chain` | canonical | medium | website | snapshot | Canonical target declares a different canonical. |
| `canonical.target_nonindexable` | canonical | high | website | snapshot | Canonical target is blocked or noindex. |
| `canonical.source_render_mismatch` | canonical | high | website | render | Source and rendered DOM canonical differ. |
| `hreflang.invalid_code` | hreflang | medium | website | snapshot | hreflang value is malformed or unsupported by configured validator. |
| `hreflang.missing_return` | hreflang | medium | website | snapshot | Alternate page does not link back. |
| `hreflang.noncanonical_target` | hreflang | medium | website | snapshot | Alternate points to a noncanonical URL. |
| `hreflang.target_error` | hreflang | high | website | fetch | Alternate target cannot be fetched successfully. |
| `hreflang.duplicate_language` | hreflang | medium | website | snapshot | Multiple conflicting URLs are declared for the same language/region. |
| `metadata.title_missing` | metadata | high | website | snapshot | HTML page has no non-empty title. |
| `metadata.title_duplicate` | metadata | medium | website | scan | Multiple indexable pages share the same normalized title. |
| `metadata.title_preview_risk` | metadata | low | website | snapshot | Title exceeds configurable preview-risk threshold. |
| `metadata.description_missing` | metadata | medium | website | snapshot | Expected landing page has no meta description. |
| `metadata.description_duplicate` | metadata | low | website | scan | Multiple indexable pages share the same description. |
| `content.h1_missing` | content | medium | website | snapshot | Page has no meaningful H1 under project policy. |
| `content.h1_multiple` | content | low | website | snapshot | Page exceeds configured H1 policy. |
| `content.main_text_empty` | content | high | website | snapshot | Expected content page has little or no extractable primary text. |
| `content.near_duplicate_cluster` | content | medium | website | scan | Several indexable pages have highly similar primary content. |
| `content.language_mismatch` | content | low | website | snapshot | Declared language conflicts with detected primary language. |
| `mobile.viewport_missing` | mobile | high | website | snapshot | Page lacks a suitable viewport declaration. |
| `mobile.content_parity_gap` | mobile | high | website | render | Configured mobile and desktop profiles expose materially different indexable content. |
| `links.broken_internal` | links | high | website | fetch | Internal link points to failed or rejected target. |
| `links.orphan_indexable` | links | medium | website | scan | Indexable URL has no discovered internal incoming links. |
| `links.depth_high` | links | low | website | scan | Important page exceeds configured crawl depth. |
| `links.internal_nofollow` | links | low | website | snapshot | Internal link is unexpectedly nofollow. |
| `links.empty_anchor` | links | low | website | snapshot | Internal link lacks meaningful accessible text/name. |
| `links.redirecting_internal` | links | low | website | fetch | Internal links point through avoidable redirects. |
| `images.alt_missing` | images | medium | website | snapshot | Informative image lacks alt text under heuristic policy. |
| `images.dimensions_missing` | images | low | website | snapshot | Image lacks explicit intrinsic dimensions. |
| `images.oversized_resource` | images | medium | website | fetch | Image transfer size exceeds configured threshold for context. |
| `images.lcp_lazy_loaded` | images | high | website | lighthouse | Likely LCP image is configured for lazy loading. |
| `structured_data.invalid_jsonld` | structured_data | high | website | snapshot | JSON-LD cannot be parsed. |
| `structured_data.unsupported_or_deprecated` | structured_data | low | website | snapshot | Markup uses a type/property not supported by configured search feature catalog. |
| `structured_data.required_property_missing` | structured_data | medium | website | snapshot | Supported rich-result type lacks a required property. |
| `structured_data.visible_content_mismatch` | structured_data | high | website | snapshot | Markup materially conflicts with visible extracted content. |
| `render.failed` | rendering | high | website | render | Browser navigation or extraction failed. |
| `render.metadata_only_after_js` | rendering | medium | website | render | Critical metadata exists only after JavaScript execution. |
| `render.content_missing_in_source` | rendering | medium | website | render | Important primary content appears only after rendering. |
| `render.links_not_crawlable` | rendering | high | website | render | Navigation depends on non-link interactions or invalid hrefs. |
| `render.robots_changed` | rendering | high | website | render | Robots directives change after execution. |
| `cwv.lcp_poor` | performance | high | website | crux | Field LCP is in the poor range for the configured 75th-percentile view. |
| `cwv.inp_poor` | performance | high | website | crux | Field INP is in the poor range. |
| `cwv.cls_poor` | performance | high | website | crux | Field CLS is in the poor range. |
| `performance.lab_regression` | performance | medium | website | lighthouse | Comparable Lighthouse metric regressed beyond release policy. |
| `performance.field_data_unavailable` | performance | info | website | crux | CrUX has insufficient data for the requested scope. |
| `ai_crawler.searchbot_blocked` | ai_crawler | info | website | robots | OAI-SearchBot is blocked for selected paths. |
| `ai_crawler.trainingbot_policy` | ai_crawler | info | website | robots | GPTBot policy is recorded independently from search inclusion policy. |
| `ai_crawler.policy_inconsistent` | ai_crawler | low | website | robots | Crawler groups contain contradictory or unintended rules under project policy. |
| `ai_crawler.snippet_restricted` | ai_crawler | info | website | snapshot | Important page applies snippet/index controls that may limit reuse or appearance. |
| `android.assetlinks_missing` | android_links | critical | android | deep_link | Digital Asset Links file is missing or unreachable. |
| `android.assetlinks_invalid` | android_links | high | android | deep_link | Digital Asset Links JSON is invalid. |
| `android.package_mismatch` | android_links | critical | android | deep_link | Hosted association does not include expected package. |
| `android.fingerprint_mismatch` | android_links | critical | android | deep_link | Expected signing certificate fingerprint is absent. |
| `android.autoverify_missing` | android_links | medium | android | manifest | Relevant intent filter does not request verification. |
| `android.host_unverified` | android_links | high | android | deep_link | Declared host lacks a matching hosted association. |
| `ios.aasa_missing` | ios_links | critical | ios | deep_link | AASA file is missing or unreachable. |
| `ios.aasa_invalid` | ios_links | high | ios | deep_link | AASA content is invalid. |
| `ios.appid_mismatch` | ios_links | critical | ios | deep_link | Expected Team ID and Bundle ID combination is absent. |
| `ios.associated_domain_missing` | ios_links | high | ios | declaration | Expected applinks domain is not declared. |
| `ios.route_not_covered` | ios_links | medium | ios | deep_link | Expected web route is not covered by AASA components/paths. |
| `app_store.name_limit` | aso | medium | ios | store_listing | App name exceeds current provider limit. |
| `app_store.subtitle_limit` | aso | medium | ios | store_listing | Subtitle exceeds current provider limit. |
| `app_store.keywords_limit` | aso | medium | ios | store_listing | Keyword field exceeds current provider limit. |
| `store_listing.required_metadata` | aso | high | mobile | store_listing | Required configured listing metadata is missing. |
| `store_listing.locale_gap` | aso | low | mobile | store_listing | Important locale is incomplete compared with project policy. |
| `route_map.web_without_app_target` | route_map | medium | mobile | route_map | Mapped public web pattern lacks a platform destination. |
| `route_map.conflict` | route_map | high | mobile | route_map | Multiple rules ambiguously match the same route. |
| `route_map.fallback_failed` | route_map | high | mobile | route_map | Web fallback returns an error or unsafe redirect. |

## 3. Severity semantics

| Severity | Meaning |
|---|---|
| critical | Broad loss of accessibility/indexability, security rejection, or release-blocking misconfiguration is likely |
| high | Significant technical problem affecting important pages or platform association |
| medium | Actionable issue with bounded impact or dependent on page importance |
| low | Optimization, maintainability, or weak-signal issue |
| info | Policy visibility or data availability; not inherently an error |

Severity is not priority. Priority additionally considers confidence, affected scope, traffic/search context, recurrence, release novelty, and remediation effort.

## 4. Confidence

Suggested levels:

- `1.00`: deterministic protocol/schema/status fact;
- `0.80–0.99`: strong multi-source evidence;
- `0.50–0.79`: supported heuristic;
- below `0.50`: informational or manual-review candidate, not a default high-severity issue.

Heuristic thresholds must be visible and configurable by supported policy. Examples include soft-404 similarity, title preview risk, near-duplicate content, thin-content expectations, and language detection.

## 5. Rule versioning

- A published rule version is immutable.
- A changed evidence schema, logic, provider limit, or identity behavior creates a new version.
- Minor recommendation-copy changes may use a content revision without changing finding identity.
- Historical occurrences keep the exact rule version.
- Finding fingerprints use a stable rule identity strategy so a harmless implementation version does not create duplicate findings.
- Re-analysis of stored artifacts creates a new analysis run and occurrence; it never rewrites history.

## 6. Current-standards policy

Provider constraints and search documentation change. Values such as App Store metadata lengths, Android link behavior, structured-data feature support, crawler user agents, or API quotas must be represented as dated provider-catalog data rather than hardcoded forever in rule classes. A scheduled maintenance workflow reviews official source changes, creates a new catalog version, runs regression fixtures, and activates it deliberately.

The MVP does not treat `llms.txt` as a required search standard. It may record its presence later as an informational experiment only after product and standards review.

## 7. Evidence safety

Evidence payloads must be bounded, schema-validated, and redacted. Store hashes, selectors, line/field locations, normalized values, and short excerpts rather than arbitrary full page content. Full artifacts remain separately protected by artifact authorization and retention.
