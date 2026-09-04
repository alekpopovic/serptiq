---
id: '073'
title: Implement static crawl orchestration
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '072'
status: pending
---

# Prompt 073 — Implement static crawl orchestration

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `072`
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
ruby tracking/scripts/prompt_tracker.rb start 073
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

Coordinate robots, sitemap/frontier discovery, bounded HTTP fetches, extraction, retries and terminal scan accounting into the first working crawl.

## Required references

- `docs/02_ARCHITECTURE.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Implement orchestration jobs/services that transition admitted scan to running, initialize robots/sitemaps/start URLs and lease frontier batches.
2. Fetch through the safe transport, persist normalized response/page snapshot metadata and artifact references.
3. Enqueue extraction/discovery idempotently and stop at settings/plan/global URL/depth/credit limits.
4. Check cancellation between units and prevent new work after cancel request.
5. Aggregate progress and determine terminal state from durable counters/states, including partial completion.
6. Handle worker crashes, stale leases and poison URLs without losing the scan.
7. Emit structured events/Turbo updates at bounded frequency.
8. Create manual scan UI from request through live progress and terminal summary.

## Required verification

- End-to-end local-site crawl system/integration test.
- Crash/retry/cancellation/limit/quota tests.
- Duplicate job/frontier idempotency tests.
- Cross-tenant scan/job/artifact tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement orchestration jobs/services that transition admitted scan to running, initialize robots/sitemaps/start URLs and lease frontier batches.
- [ ] Fetch through the safe transport, persist normalized response/page snapshot metadata and artifact references.
- [ ] Enqueue extraction/discovery idempotently and stop at settings/plan/global URL/depth/credit limits.
- [ ] Check cancellation between units and prevent new work after cancel request.
- [ ] Aggregate progress and determine terminal state from durable counters/states, including partial completion.
- [ ] Handle worker crashes, stale leases and poison URLs without losing the scan.
- [ ] Emit structured events/Turbo updates at bounded frequency.
- [ ] Create manual scan UI from request through live progress and terminal summary.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No target network call from web process.
- Do not mark scan complete while durable runnable frontier work remains.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 073 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 073 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 073
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
