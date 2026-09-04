---
id: '115'
title: Optimize indexes, query plans, partitioning and retention
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '114'
status: pending
---

# Prompt 115 — Optimize indexes, query plans, partitioning and retention

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `114`
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
ruby tracking/scripts/prompt_tracker.rb start 115
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

Validate the PostgreSQL design against representative data volumes and make measured, documented performance changes before launch.

## Required references

- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Generate deterministic representative datasets for organizations/projects, million-scale frontier rows and multi-million finding/usage occurrences without production data.
2. Capture `EXPLAIN (ANALYZE, BUFFERS)` for critical tenant lists, frontier leasing, finding filters, dashboard aggregates, usage checks, schedules and report snapshots.
3. Add/adjust composite, partial and covering indexes only from measured query shapes; check write amplification.
4. Implement or document partitioning/retention for the highest-volume tables with safe migration path.
5. Eliminate N+1 and unbounded queries; add pagination and statement timeouts.
6. Review foreign keys/cascades and deletion jobs for lock risk.
7. Set performance regression tests/budgets for key operations.
8. Document autovacuum/analyze/bloat and connection-pool monitoring.

## Required verification

- Benchmark before/after with dataset and environment recorded.
- Migration safety/lock-time review.
- Run full tests and representative concurrent frontier/quota workloads.
- Verify indexes are used and no tenant filter is missing.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Generate deterministic representative datasets for organizations/projects, million-scale frontier rows and multi-million finding/usage occurrences without production data.
- [ ] Capture `EXPLAIN (ANALYZE, BUFFERS)` for critical tenant lists, frontier leasing, finding filters, dashboard aggregates, usage checks, schedules and report snapshots.
- [ ] Add/adjust composite, partial and covering indexes only from measured query shapes; check write amplification.
- [ ] Implement or document partitioning/retention for the highest-volume tables with safe migration path.
- [ ] Eliminate N+1 and unbounded queries; add pagination and statement timeouts.
- [ ] Review foreign keys/cascades and deletion jobs for lock risk.
- [ ] Set performance regression tests/budgets for key operations.
- [ ] Document autovacuum/analyze/bloat and connection-pool monitoring.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not add indexes speculatively without query evidence.
- Do not disable database constraints for speed.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 115 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 115 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 115
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
