---
id: 069
title: Implement the bounded HTTP fetcher and redirect handling
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 068
status: pending
---

# Prompt 069 — Implement the bounded HTTP fetcher and redirect handling

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `068`
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
ruby tracking/scripts/prompt_tracker.rb start 069
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

Create the crawler HTTP transport on top of approved destinations with strict resource limits, provenance and safe retry semantics.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Implement GET/HEAD behavior using only the destination resolver's approved connection plan.
2. Set connect/TLS/header/body/total deadlines, maximum header/body size, decompression ratio/bytes and supported content encodings.
3. Validate TLS by default and record categorized failures; do not add global disable-verification options.
4. Follow redirects manually through revalidation and record each hop/status/location/timing.
5. Stream/hash artifacts without loading unbounded bodies in memory.
6. Normalize response metadata, media type/charset and fetch outcome; treat misleading content types defensively.
7. Define retries only for safe transient failures with bounded attempts/backoff and scan cancellation checks.
8. Use an explicit, honest SearchOps user agent and optional contact URL.

## Required verification

- Timeout/slowloris/oversized/decompression/redirect-loop tests.
- TLS/certificate failure tests using local fixtures.
- Cancellation and retry/idempotency tests.
- Memory/streaming test on bounded large body.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement GET/HEAD behavior using only the destination resolver's approved connection plan.
- [ ] Set connect/TLS/header/body/total deadlines, maximum header/body size, decompression ratio/bytes and supported content encodings.
- [ ] Validate TLS by default and record categorized failures; do not add global disable-verification options.
- [ ] Follow redirects manually through revalidation and record each hop/status/location/timing.
- [ ] Stream/hash artifacts without loading unbounded bodies in memory.
- [ ] Normalize response metadata, media type/charset and fetch outcome; treat misleading content types defensively.
- [ ] Define retries only for safe transient failures with bounded attempts/backoff and scan cancellation checks.
- [ ] Use an explicit, honest SearchOps user agent and optional contact URL.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No global TLS verification bypass.
- Do not automatically submit forms, authenticate or execute JavaScript.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 069 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 069 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 069
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
