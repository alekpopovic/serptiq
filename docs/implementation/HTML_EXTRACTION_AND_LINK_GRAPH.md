# HTML extraction and internal link graph

Prompt 074 replaces the static crawler's discovery-only HTML pass with deterministic normalized page facts and
directed link evidence. The analysis worker still reads only the exact private artifact attached to its tenant,
scan, fetch and page snapshot. It never executes page JavaScript and it never treats an extracted URL as network
authorization.

## Parser and resource limits

`Crawling::HtmlPageExtractor` uses Nokogiri's maintained HTML5 parser with explicit limits of 5 MiB source
bytes, 256 tree levels, 128 attributes per element, 50,000 elements and 20 retained parse errors. Extraction
then caps anchors/areas at 5,000, meta directives at 100, headings at 200, canonicals at 20, hreflangs at 100,
images at 500 and JSON-LD blocks at 20. Attributes are accepted only below 8,192 bytes. JSON-LD is parsed with
a nesting ceiling and retains at most 32 KiB per block and 256 KiB in total; oversized or invalid blocks retain
only status, digest and source locator.

Titles, descriptions, heading text, image alt values and anchor names are whitespace-normalized UTF-8 plain
text with control characters removed and strict byte ceilings. PostgreSQL never receives full visible text or
the source document. These snippets remain untrusted strings: Rails must render them through normal automatic
escaping, and callers must never mark them `html_safe`.

## URL and fact semantics

The observed final fetch URL is the document URL. The first `base[href]` candidate becomes the effective base only
when it resolves to a syntactically valid HTTP(S) URL; a missing base is `absent`, while an unsafe or invalid first
candidate is `malformed` and cannot affect resolution. Canonical, hreflang, anchor/area and image references resolve
against the effective base and pass through crawl URL normalization. Canonical and hreflang remain observations
only. Anchor discovery additionally passes the immutable scan scope before a frontier request, and frontier
capacity remains the final admission boundary.

`crawl_page_facts` is one immutable fact aggregate per exact page snapshot. It records parser version, source
content hash, a canonical fact digest, parse/error/element observations, effective base, bounded scalar facts,
bounded repeated facts and counts. Every fact family has an explicit `present`, `absent`, `malformed` or
`unavailable` state. A terminal extraction failure writes an `unavailable` aggregate without inventing a pass.
Source locators are bounded parser-generated paths; JSON-LD and all displayed values are hostile evidence.

## Directed graph and replay

`crawl_links` stores one immutable directed edge for each source page snapshot and normalized destination URL
digest. Repeated DOM occurrences are aggregated in first-occurrence order with an occurrence count, nofollow
count, union of bounded `rel` tokens, a representative source locator and anchor summary/hash. Each edge records
internal/external classification, immutable scope decision and whether an allowed internal destination was
linked to a frontier row or could not be admitted because the scan cap was already full. External and denied
internal observations never receive a crawl target implicitly.

The unique snapshot/destination index makes retries and duplicate elements inexpensive. Frontier insertion runs
before the facts/edges transaction and is itself idempotent. Facts and edge digests make a conflicting replay
fail closed; if their transaction committed before the page-snapshot completion write, a retry completes from
the already persisted evidence without reparsing or rediscovery.

`Crawling::Public.link_graph` requires an exact organization/scan pair and returns bounded IDs/counts for
successful graph nodes, internal/external edges, terminal broken internal destinations, non-seed successful
pages without an incoming internal edge, and depth distribution. This is analysis input, not a ranking or
indexability guarantee.

## Database and operations

Migration `20260904157000_create_html_extraction_graph.rb` adds an exact page-snapshot identity index
concurrently, then creates the empty fact and link tables with composite tenant/source/destination foreign keys,
JSON/size/state checks, graph indexes and lifecycle-aware immutability triggers. There is no row backfill or
source-table rewrite. The concurrent index avoids a long blocking build, but table/constraint creation still
takes brief metadata locks. A partially failed nontransactional migration must be inspected before retry.

Resource deletion removes links, then facts, then page snapshots inside the already authorized
`scans_and_findings` lifecycle transaction. Monitor unavailable/limit outcomes, fact payload sizes, link counts,
edges not admitted by the frontier cap and graph queries on large scans. Parser or normalization changes require
a new parser/version contract and regression fixtures rather than rewriting retained evidence.
