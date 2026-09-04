---
id: '010'
title: Establish the Minitest and system-test foundation
phase: 01 Rails and operational foundation
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 009
status: pending
---

# Prompt 010 — Establish the Minitest and system-test foundation

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `009`
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
ruby tracking/scripts/prompt_tracker.rb start 010
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

Build reusable test infrastructure for domain decisions, requests, jobs, provider contracts, tenant isolation and critical browser journeys.

## Required references

- `docs/09_TEST_STRATEGY.md`
- `AGENTS.md`

## Required work

1. Organize the test tree according to `docs/09_TEST_STRATEGY.md` while retaining Rails conventions.
2. Add deterministic helpers for clocks, IDs, encrypted attributes, signed requests, current tenant and provider fakes.
3. Create a tenant-isolation shared test helper that can be applied to every tenant-owned controller/operation.
4. Configure system tests with the chosen browser driver and failure artifact capture.
5. Add helpers for asserting enqueued jobs, idempotent retries, audit events, permission decisions and usage events.
6. Create a local malicious HTTP fixture service/test support boundary for later crawler security cases without permitting external network access.
7. Document fast/default/full/security test commands and random-order reproduction.

## Required verification

- Run a representative unit, request, job, system and contract test.
- Prove randomized seed reproduction works.
- Verify system-test screenshots/logs are kept only on failure and excluded from Git.
- Run the full current test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Organize the test tree according to `docs/09_TEST_STRATEGY.md` while retaining Rails conventions.
- [ ] Add deterministic helpers for clocks, IDs, encrypted attributes, signed requests, current tenant and provider fakes.
- [ ] Create a tenant-isolation shared test helper that can be applied to every tenant-owned controller/operation.
- [ ] Configure system tests with the chosen browser driver and failure artifact capture.
- [ ] Add helpers for asserting enqueued jobs, idempotent retries, audit events, permission decisions and usage events.
- [ ] Create a local malicious HTTP fixture service/test support boundary for later crawler security cases without permitting external network access.
- [ ] Document fast/default/full/security test commands and random-order reproduction.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Tests must not contact real providers or arbitrary internet hosts.
- Do not hide flaky tests with retries.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 010 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 010 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 010
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
