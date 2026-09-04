---
id: 068
title: Implement the SSRF-safe destination resolver and connection policy
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '067'
status: pending
---

# Prompt 068 — Implement the SSRF-safe destination resolver and connection policy

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `067`
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
ruby tracking/scripts/prompt_tracker.rb start 068
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

Build the central security boundary that resolves and authorizes every crawler/browser outbound destination, including every redirect and resource request.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Create a destination-policy service for HTTP(S) URLs that canonicalizes hostname, resolves A/AAAA records and rejects loopback, private, link-local, multicast, unspecified, documentation/reserved and cloud metadata destinations.
2. Handle IPv4-in-IPv6, integer/octal/hex-like forms rejected by the parser, zone identifiers, IDNA and trailing-dot edge cases.
3. Return approved IP set/port and require the HTTP transport to connect consistently with validated resolution while preserving Host/SNI.
4. Re-resolve and revalidate every redirect hop; cap hops and reject scheme/credential/origin policy violations.
5. Mitigate DNS rebinding/TOCTOU with transport-level controls and network egress defense in depth.
6. Record a safe denial reason and resolution provenance without logging sensitive DNS payloads.
7. Create a local malicious DNS/HTTP fixture suite.
8. Make direct target HTTP clients inaccessible by architecture convention/check.

## Required verification

- Comprehensive IPv4/IPv6/private/reserved test matrix.
- DNS rebinding and public-to-private redirect tests asserting no forbidden connection.
- Host/SNI/approved-IP transport tests.
- Fuzz/property tests and security CI integration.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a destination-policy service for HTTP(S) URLs that canonicalizes hostname, resolves A/AAAA records and rejects loopback, private, link-local, multicast, unspecified, documentation/reserved and cloud metadata destinations.
- [ ] Handle IPv4-in-IPv6, integer/octal/hex-like forms rejected by the parser, zone identifiers, IDNA and trailing-dot edge cases.
- [ ] Return approved IP set/port and require the HTTP transport to connect consistently with validated resolution while preserving Host/SNI.
- [ ] Re-resolve and revalidate every redirect hop; cap hops and reject scheme/credential/origin policy violations.
- [ ] Mitigate DNS rebinding/TOCTOU with transport-level controls and network egress defense in depth.
- [ ] Record a safe denial reason and resolution provenance without logging sensitive DNS payloads.
- [ ] Create a local malicious DNS/HTTP fixture suite.
- [ ] Make direct target HTTP clients inaccessible by architecture convention/check.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- This is a security-critical prompt: do not approximate IP classification.
- Application validation must be backed by infrastructure egress restrictions.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 068 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 068 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 068
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
