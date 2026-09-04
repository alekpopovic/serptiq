---
id: '007'
title: Configure Solid Queue, Solid Cache and Solid Cable topology
phase: 01 Rails and operational foundation
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '006'
status: pending
---

# Prompt 007 — Configure Solid Queue, Solid Cache and Solid Cable topology

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `006`
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
ruby tracking/scripts/prompt_tracker.rb start 007
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

Install/configure the Rails Solid components with explicit process roles, queue priorities, recurring-task ownership and operational bounds.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/adr/0002_postgresql_and_solid_stack.md`

## Required work

1. Complete Solid Queue, Solid Cache and Solid Cable database schemas/configuration using the database topology from prompt 006.
2. Define named queues for default, mail, integrations, billing, crawl, render, analysis, reports and maintenance with documented priorities/concurrency.
3. Configure worker process definitions so browser jobs can never run in the web/default worker by accident.
4. Set retry/discard defaults by error taxonomy; domain jobs must override intentionally.
5. Configure recurring-task files for later tasks without adding placeholder jobs that fail.
6. Bound Solid Cache size/expiry and document that it is disposable.
7. Configure Solid Cable retention/polling appropriate for Turbo updates without using it as durable domain messaging.
8. Add operational documentation for queue latency, failed jobs, graceful shutdown and stale process cleanup.

## Required verification

- Enqueue and perform a smoke job through real Solid Queue/PostgreSQL.
- Verify queue routing for each representative job class.
- Verify Rails boots when cache/cable databases are empty and migrations are applied.
- Run the test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Complete Solid Queue, Solid Cache and Solid Cable database schemas/configuration using the database topology from prompt 006.
- [ ] Define named queues for default, mail, integrations, billing, crawl, render, analysis, reports and maintenance with documented priorities/concurrency.
- [ ] Configure worker process definitions so browser jobs can never run in the web/default worker by accident.
- [ ] Set retry/discard defaults by error taxonomy; domain jobs must override intentionally.
- [ ] Configure recurring-task files for later tasks without adding placeholder jobs that fail.
- [ ] Bound Solid Cache size/expiry and document that it is disposable.
- [ ] Configure Solid Cable retention/polling appropriate for Turbo updates without using it as durable domain messaging.
- [ ] Add operational documentation for queue latency, failed jobs, graceful shutdown and stale process cleanup.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use Redis or Sidekiq.
- Do not use Action Cable/Solid Cable as a durable event bus.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 007 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 007 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 007
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
