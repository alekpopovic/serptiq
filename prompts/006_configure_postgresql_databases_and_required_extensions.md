---
id: '006'
title: Configure PostgreSQL databases and required extensions
phase: 01 Rails and operational foundation
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '005'
status: pending
---

# Prompt 006 — Configure PostgreSQL databases and required extensions

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `005`
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
ruby tracking/scripts/prompt_tracker.rb start 006
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

Configure production-grade PostgreSQL usage for primary, queue, cache and cable workloads, with safe local defaults, constraints and connection behavior.

## Required references

- `docs/02_ARCHITECTURE.md`
- `docs/03_ERD.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/adr/0002_postgresql_and_solid_stack.md`

## Required work

1. Define `database.yml`/environment configuration for primary, queue, cache and cable databases using PostgreSQL only, supporting colocation locally and separate URLs in production.
2. Enable only justified extensions, such as `pgcrypto` for UUID generation, through reversible migrations.
3. Establish UUID primary-key policy for tenant/external aggregate roots and bigint policy for high-volume internal crawl rows; document exceptions.
4. Configure pool sizes from per-process environment values and prevent aggregate pool counts from exceeding managed database capacity.
5. Set safe application names, timeouts and advisory-lock behavior where supported.
6. Add database tasks/setup documentation that works from a clean machine and CI.
7. Create a database health query used by readiness with a strict timeout rather than a broad expensive check.

## Required verification

- Create all configured databases and load schema from zero.
- Run tests against PostgreSQL, not SQLite.
- Verify queue/cache/cable connections can initialize.
- Test invalid/missing database configuration fails clearly.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define `database.yml`/environment configuration for primary, queue, cache and cable databases using PostgreSQL only, supporting colocation locally and separate URLs in production.
- [ ] Enable only justified extensions, such as `pgcrypto` for UUID generation, through reversible migrations.
- [ ] Establish UUID primary-key policy for tenant/external aggregate roots and bigint policy for high-volume internal crawl rows; document exceptions.
- [ ] Configure pool sizes from per-process environment values and prevent aggregate pool counts from exceeding managed database capacity.
- [ ] Set safe application names, timeouts and advisory-lock behavior where supported.
- [ ] Add database tasks/setup documentation that works from a clean machine and CI.
- [ ] Create a database health query used by readiness with a strict timeout rather than a broad expensive check.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not enable extensions without a documented need.
- Do not commit environment-specific credentials.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 006 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 006 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 006
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
