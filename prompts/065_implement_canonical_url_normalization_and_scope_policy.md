---
id: '065'
title: Implement canonical URL normalization and scope policy
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '064'
status: pending
---

# Prompt 065 — Implement canonical URL normalization and scope policy

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `064`
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
ruby tracking/scripts/prompt_tracker.rb start 065
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

Create the deterministic URL identity and crawl-scope rules used by frontier deduplication, evidence and security checks.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Implement parsing/normalization for HTTP(S): lowercase/IDNA host, default ports, dot segments, percent-encoding policy, fragment removal and empty path.
2. Define query parameter ordering, tracking-parameter removal and configured allow/deny behavior without changing semantic values unexpectedly.
3. Keep fetch URL and normalized identity URL distinct when necessary.
4. Implement same-origin/allowed-host/path/include/exclude/depth policy with explicit reason codes.
5. Reject userinfo, control characters, ambiguous IP forms, invalid ports and unsupported schemes.
6. Create stable digest/fingerprint versioning so normalization changes do not silently corrupt old scans.
7. Document canonical normalization versus HTML canonical recommendation as separate concepts.

## Required verification

- Large table-driven normalization test corpus.
- Property-based/fuzz tests for parser crashes and idempotence.
- Scope boundary tests for sibling/lookalike domains and encoded paths.
- Backward-version fixture tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement parsing/normalization for HTTP(S): lowercase/IDNA host, default ports, dot segments, percent-encoding policy, fragment removal and empty path.
- [ ] Define query parameter ordering, tracking-parameter removal and configured allow/deny behavior without changing semantic values unexpectedly.
- [ ] Keep fetch URL and normalized identity URL distinct when necessary.
- [ ] Implement same-origin/allowed-host/path/include/exclude/depth policy with explicit reason codes.
- [ ] Reject userinfo, control characters, ambiguous IP forms, invalid ports and unsupported schemes.
- [ ] Create stable digest/fingerprint versioning so normalization changes do not silently corrupt old scans.
- [ ] Document canonical normalization versus HTML canonical recommendation as separate concepts.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never use regex alone to parse URLs.
- Do not treat an HTML canonical URL as authorization to leave crawl scope.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 065 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 065 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 065
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
