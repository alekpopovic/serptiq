# ADR 0007 — Isolate JavaScript rendering from web processes

- Status: Accepted
- Date: 2026-09-04
- Owners: Security, Crawling
- Last reviewed: 2026-09-05 (Prompt 075)

## Context

Customer JavaScript is hostile code. Rendering consumes much more CPU/memory than HTTP fetching and can attempt network access, downloads, persistence or denial of service.

## Decision

Run Chromium only in dedicated render workers/containers with fresh contexts, bounded resources, blocked private egress, disabled unnecessary capabilities and no application secrets. Store normalized results/artifacts and terminate contexts deterministically.

## Consequences

- Render work has a higher credit weight and concurrency cap.
- Browser/Chromium versions are part of result provenance.
- Web processes remain isolated from page execution.
- Render fleet can be scaled or extracted independently if measured demand requires it.

## Implementation

Prompt 075 implements the dedicated queue/image target, runtime role guard,
fresh Ferrum incognito contexts, scrubbed Chromium environment, bounded render
evidence, weighted attempt accounting and crash recovery. The detailed contract
is [`../implementation/JAVASCRIPT_RENDERING.md`](../implementation/JAVASCRIPT_RENDERING.md).
Prompt 076 remains responsible for the next interception and sandbox hardening
layer.
