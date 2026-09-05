# JavaScript rendering workers

JavaScript rendering is an opt-in, sampled observation layered on a successful
static HTML fetch. `crawl_page_renders` binds one render to the exact tenant,
scan, `crawl_page_snapshot` and source `crawl_page_fact`; the copied final fetch
URL and digest are immutable job input. A scan's snapshotted
`rendering_sample_percent`, `max_rendered_pages`, and admission credit estimate
jointly cap deterministic scheduling. Replays use the unique source snapshot and
never create another render.

## Isolation and browser lifecycle

Only `Crawling::PageRenderJob` uses the `render` queue, and only
`worker_render` polls that queue. `FerrumPageRenderer` also rejects calls unless
the runtime role is exactly `worker_render`, so a direct call cannot start
Chromium in web or default workers. The production `Dockerfile` keeps Chromium
out of its default `final` target and provides a separate `render` target. The
development image pins Chromium and its sandbox package at
`152.0.7977.75-1~deb13u1`; Ferrum is lockfile-pinned at `0.18.0`. Both values are
image labels, while every completed row records the actual browser product,
revision, CDP protocol, Ferrum and renderer versions.

A browser process is reused serially inside one single-threaded worker, but
every target gets a newly created incognito context/page which Ferrum closes and
disposes after the block. Dead or timed-out browsers are discarded. The fixed
`bin/searchops-chromium` launcher clears the inherited process environment and
passes only locale, executable-path and temporary-directory values to Chromium;
customer flags and Rails/provider secrets cannot enter the browser process.
Downloads, authentication prompts, non-GET/HEAD requests and unsupported URL
schemes are denied. Customer pages never control browser flags.

The application destination policy authorizes the initial URL, every redirected
navigation and every HTTP(S) subresource. Infrastructure must additionally
apply `config/crawler_egress_policy.yml`; protected render workers fail boot
without that deployment attestation. Browser sandboxing remains enabled.

## Bounds, cancellation and evidence

The global browser settings impose a 45-second wall limit, six-minute durable
lease, 200-request cap and 50 MiB encoded-response budget by default. Rendered
DOM is additionally constrained by the shared 5 MiB HTML extraction limit.
Network-idle waiting consumes the same wall budget. Cancellation is checked
before navigation, during each intercepted request and before artifact capture.
Container process, memory and shared-memory bounds are independent controls.

Completed renders store only bounded summaries in PostgreSQL: final URL,
digests, timing, request/byte counts, status/content-type counts, console
summaries and page-error summaries. Rendered DOM and optional PNG screenshots
use the private artifact store. The exact same `HtmlPageExtractor` parses the
rendered DOM into immutable `crawl_rendered_page_facts` and
`crawl_rendered_links`; these stay separate from source facts and the static
discovery graph.

Each attempt reserves `crawl.rendered_page` through a source key containing the
render ID and attempt number. Only an atomically completed, accepted render
consumes its snapshotted weighted rate. Timeout, crash, cancellation and policy
failure release the attempt as non-billable. Expired leases are released and
requeued within the same scan lock order; terminal scan reconciliation remains
the final safety net.

## Operations

Local isolated execution is explicit:

```bash
docker compose --profile workers up --build render
SEARCHOPS_PROCESS_ROLE=worker_render bin/jobs
```

`Crawling::Public.render_metrics` returns bounded pending, processing, stale,
completed, failed and canceled counts plus average completed duration. Render
events contain low-cardinality outcome/reason/retry/duration fields and never
URLs, DOM, screenshots, headers, console payloads or tenant identifiers.

Production rollout must build the `render` target, run it as the non-root Rails
user, keep one job thread per process, enforce memory/PID/tmpfs bounds, verify
the Chromium sandbox and egress policy, and inject only the database/object-store
credentials needed by the Rails worker. No browser capability exists in the
default web image.

The migration creates new empty tables and concurrent supporting indexes on
existing fact rows. Table creation itself does not rewrite populated crawl
tables; the new composite unique index scans `crawl_page_facts`, so deploy it
before increasing render traffic and monitor normal index-build I/O.
