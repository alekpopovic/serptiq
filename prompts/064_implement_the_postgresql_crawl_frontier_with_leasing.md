---
id: '064'
title: Implement the PostgreSQL crawl frontier with leasing
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '063'
status: pending
---

# Prompt 064 — Implement the PostgreSQL crawl frontier with leasing

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `063`
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
ruby tracking/scripts/prompt_tracker.rb start 064
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

Create a durable high-volume crawl frontier using PostgreSQL row leasing and `FOR UPDATE SKIP LOCKED` with recovery and fair scheduling.

## Required references

- `docs/02_ARCHITECTURE.md`
- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Create high-volume crawl URL/frontier tables using bigint where appropriate, normalized URL digest, depth, priority, discovery source, state, lease owner/expiry, attempts and result references.
2. Enforce uniqueness per scan/normalized URL and organization/project consistency.
3. Implement batch discovery/upsert and lease acquisition with `SKIP LOCKED`, ordered by priority/depth/discovery sequence.
4. Implement heartbeat/lease extension, success/failure/retry, terminal exhaustion and stale lease recovery.
5. Prevent two workers from fetching the same frontier item concurrently under normal operation.
6. Add organization/host fairness inputs so one large scan cannot monopolize all workers.
7. Design indexes and retention/partition notes using representative query plans.
8. Expose aggregate progress without counting the entire frontier on every request.

## Required verification

- Real PostgreSQL multi-worker leasing tests.
- Stale lease/crash/retry/idempotency tests.
- Duplicate discovery concurrency tests.
- `EXPLAIN`/performance test on representative dataset.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create high-volume crawl URL/frontier tables using bigint where appropriate, normalized URL digest, depth, priority, discovery source, state, lease owner/expiry, attempts and result references.
- [ ] Enforce uniqueness per scan/normalized URL and organization/project consistency.
- [ ] Implement batch discovery/upsert and lease acquisition with `SKIP LOCKED`, ordered by priority/depth/discovery sequence.
- [ ] Implement heartbeat/lease extension, success/failure/retry, terminal exhaustion and stale lease recovery.
- [ ] Prevent two workers from fetching the same frontier item concurrently under normal operation.
- [ ] Add organization/host fairness inputs so one large scan cannot monopolize all workers.
- [ ] Design indexes and retention/partition notes using representative query plans.
- [ ] Expose aggregate progress without counting the entire frontier on every request.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use in-memory queues as source of truth.
- Leases must have bounded duration and owner identity.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 064 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 064 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 064
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
