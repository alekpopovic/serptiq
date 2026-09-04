# ADR 0006 — Treat the crawler as an SSRF security boundary

- Status: Accepted
- Date: 2026-09-04

## Context

Customers submit URLs and pages may redirect, change DNS answers or reference arbitrary resources. A crawler could otherwise access loopback, private networks, link-local addresses, metadata services or internal control planes.

## Decision

All outbound crawl destinations pass a centralized network-safety policy. Allow only HTTP/HTTPS, normalize hostnames, resolve DNS, reject non-public addresses, connect using validated resolution, re-resolve every redirect, bound redirects/bytes/time and record denials. Run crawl/render workers in networks with defense-in-depth egress restrictions.

## Consequences

- The HTTP client cannot be used directly for customer targets.
- DNS and IP parsing edge cases receive security regression tests.
- Domain verification is required before high-volume or rendering work.
- Some legitimate private/internal-site auditing is outside MVP scope.
