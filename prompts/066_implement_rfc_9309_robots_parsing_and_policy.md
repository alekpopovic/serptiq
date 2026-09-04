---
id: '066'
title: Implement RFC 9309 robots parsing and policy
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '065'
status: pending
---

# Prompt 066 — Implement RFC 9309 robots parsing and policy

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `065`
- **Execution mode:** one prompt at a time; inspect and modify the real repository; do not simulate completion

The reasoning label is a minimum recommendation for this task. Use deeper reasoning when implementation evidence demands it. Never lower rigor for authentication, authorization, billing, concurrency, tenant isolation, outbound networking, browser execution, migrations or production safety.

## Mandatory operating contract

Before writing code:

1. Read `AGENTS.md`.
2. Read `tracking/state.json` and the result summaries for all dependencies.
3. Read this entire prompt and the referenced documents below.
4. Inspect the current code, tests, schema, migrations, configuration and Git diff. The repository—not an assumed greenfield state—is the source of truth.
5. Start the prompt:

```bash
ruby tracking/scripts/prompt_tracker.rb start 066
```

If the tracker refuses, stop and resolve the stated dependency/current-state problem honestly. Do not edit `tracking/state.json` by hand to bypass it.

During implementation:

- Follow the modular-monolith, PostgreSQL-only, native-session and Solid-stack decisions.
- Do not add Devise, OmniAuth, Doorkeeper, Sidekiq, Redis, Elasticsearch or Kubernetes unless a later accepted ADR explicitly supersedes the blueprint.
- Preserve tenant isolation and enforce access in backend/domain boundaries, not only in views.
- Add database constraints as well as model validation.
- Treat every external payload and customer-controlled value as hostile.
- Keep unrelated refactors out of this prompt.
- Do not hide failing tests, skipped checks, assumptions or security limitations.

## Objective

Parse and evaluate robots rules reproducibly while explaining that robots exclusion is crawl policy, not authorization or data protection.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Implement or integrate a maintained parser validated against RFC 9309 semantics for user-agent groups, allow/disallow precedence, percent encoding and file size/redirect/error limits.
2. Define the SearchOps user-agent token and HTTP identification/contact policy.
3. Cache robots responses per scan/origin with retrieval status, timestamp and artifact hash.
4. Evaluate each URL with an explicit allow/deny/unknown reason and record robots source version.
5. Define behavior for unavailable, 4xx, 5xx, timeout, oversized and malformed robots responses according to documented policy.
6. Support customer setting to respect robots by default; any verified-owner override must be explicit, plan/policy controlled and still subject to network safety.
7. Parse sitemap directives for discovery without treating them as trusted/safe.
8. Create customer-facing explanation that robots is not access control.

## Required verification

- RFC/example fixture tests and precedence cases.
- Response-status/redirect/size/error behavior tests.
- Security tests for malicious sitemap URLs in robots.
- Rule/output provenance tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement or integrate a maintained parser validated against RFC 9309 semantics for user-agent groups, allow/disallow precedence, percent encoding and file size/redirect/error limits.
- [ ] Define the SearchOps user-agent token and HTTP identification/contact policy.
- [ ] Cache robots responses per scan/origin with retrieval status, timestamp and artifact hash.
- [ ] Evaluate each URL with an explicit allow/deny/unknown reason and record robots source version.
- [ ] Define behavior for unavailable, 4xx, 5xx, timeout, oversized and malformed robots responses according to documented policy.
- [ ] Support customer setting to respect robots by default; any verified-owner override must be explicit, plan/policy controlled and still subject to network safety.
- [ ] Parse sitemap directives for discovery without treating them as trusted/safe.
- [ ] Create customer-facing explanation that robots is not access control.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Robots permission never bypasses SSRF/network policy.
- Do not claim blocked URLs are absent from search indexes.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 066 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 066 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 066
Status: completed or blocked
Implemented:
Key files:
Migrations:
Tests and actual results:
Security/tenancy review:
Remaining risks:
Next eligible prompt:
```

Never claim completion based only on generated code or an unexecuted test plan.
