# Sitemap discovery and bounded XML parsing

Prompt 067 adds an exact-tenant, per-scan sitemap discovery operation. Sitemap data is an untrusted
observation used by later SEO rules; neither a sitemap file nor a listed URL proves safety, ownership,
indexing or search-engine behavior.

## Candidate and network policy

Discovery considers immutable scan-policy sitemap URLs first, then bounded `Sitemap` directives from the
scan's robots snapshot. The standard exact-origin `/sitemap.xml` candidate is added only when
`SEARCHOPS_CRAWLER_SITEMAP_WELL_KNOWN_ENABLED` is enabled. Canonical URL identity deduplicates candidates
before any request.

Every candidate must remain on the exact property-environment scheme, host and port. Every request uses the
shared pinned public-network HTTP boundary; DNS/address classification is repeated for every redirect, HTTPS
downgrades are rejected and sitemap redirects are restricted to the original scan origin. A rejected robots
candidate is retained as bounded status evidence and is never resolved or connected to.

## Parser and resource limits

Only XML `urlset` and `sitemapindex` documents are supported. Nokogiri's streaming reader runs in strict,
`NONET` mode without `NOENT`, `DTDLOAD`, `DTDVALID`, `XINCLUDE` or `HUGE`. Document types and entity nodes are
explicitly rejected. XML depth, entries per document, entries per scan, sitemap documents, index recursion,
download bytes, decompressed bytes, redirects and warning evidence all have typed runtime limits.

Gzip is detected by its magic bytes, not a trusted filename or media type. Decompression reads bounded chunks
and stops before crossing the configured uncompressed-byte ceiling. Invalid gzip, malformed XML, unsupported
roots, missing locations, invalid URLs and limit exhaustion become stable status/warning codes; they do not
crash the scan. Well-formed documents may retain valid entries around missing or invalid records. Raw XML and
compressed bodies are not stored in PostgreSQL.

The Sitemap protocol permits at most 50,000 records and 50 MiB uncompressed per file. SearchOps never raises
those protocol ceilings and may use lower operational limits. The protocol's same-site statements do not
override SearchOps' stricter configured-origin or SSRF policies.

## Graph, frontier and metering evidence

`crawl_sitemap_discoveries` is the one-per-scan aggregate and stores terminal counters. A fetch attempt counts
each initial or redirect-hop request passed to the network boundary; `metered_fetch_count` counts requests that
produced an accepted HTTP response. Prompt 073 starts one operation allocation before each request and finishes
each redirect/final response separately. DNS/policy failures release their operation without billing, and quota
denial prevents DNS/transport. The scan's existing admission hold supplies these allocations and terminal
finalization consumes only the accepted-response usage events.

`crawl_sitemap_files` stores the deduplicated index graph, first-parent provenance, digest-only artifact
identity, response status, gzip byte counts, parser version and bounded warning codes. `crawl_sitemap_entries`
stores normalized URL identity, exact source position, date/datetime/invalid `lastmod` provenance, scope
decision and either a child sitemap or frontier relationship. Circular and repeated index edges are retained
as entry outcomes without another fetch.

Page locations pass the immutable scan's full scheme/host/port/path/query/depth scope before frontier
insertion. Frontier rows are inserted in bounded batches and retain the first semantic fetch URL while using
versioned identity for deduplication. The scan's URL ceiling limits new frontier rows even when the sitemap
contains more observations.

## Database and lifecycle guarantees

All three tables repeat the exact organization/project/property/environment/scan identity. Composite foreign
keys prevent cross-scan graph, child and frontier substitution. Checks enforce state, counter, warning,
`lastmod` and relationship shapes. Terminal discovery/file results and every entry are immutable in
PostgreSQL. Authorized resource deletion removes entries, files and the aggregate before frontier and scan
rows during the existing `scans_and_findings` lifecycle stage.

Migration `20260904152000_create_crawl_sitemap_discovery.rb` creates empty tables, indexes, checks, composite
foreign keys and protection triggers. It performs no backfill or table rewrite; deployment takes only the
brief DDL locks required to install new schema objects. Rollback drops sitemap evidence and is appropriate
only before those observations are relied upon.

## Sources

- Sitemap protocol: <https://www.sitemaps.org/protocol.html>
- Nokogiri untrusted XML parsing: <https://nokogiri.org/tutorials/parsing_an_html_xml_document.html>
- Nokogiri XML reader: <https://nokogiri.org/rdoc/Nokogiri/XML/Reader.html>
