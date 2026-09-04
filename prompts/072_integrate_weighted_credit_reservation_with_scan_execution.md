---
id: '072'
title: Integrate weighted credit reservation with scan execution
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '071'
status: pending
---

# Prompt 072 — Integrate weighted credit reservation with scan execution

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `071`
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
ruby tracking/scripts/prompt_tracker.rb start 072
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

Connect static fetch, render, Lighthouse and artifact operations to the usage ledger without double charging or unbounded cost.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Define exact meter/weight lookup from versioned configuration and include it in scan snapshots.
2. Reserve estimated scan credits at admission and charge/finalize actual operations through idempotent source keys.
3. Track HTTP fetch attempts vs successful billable fetches according to documented policy.
4. Reserve incremental credits before expanding beyond estimate; pause/cancel safely if unavailable.
5. Release unused reservation at terminal scan state and recover after crashes.
6. Expose per-scan cost breakdown and organization usage aggregation.
7. Ensure provider/internal retries do not create duplicate usage events.
8. Add audit/support adjustment path through compensating events only.

## Required verification

- End-to-end scan reservation → operations → finalization tests.
- Retry/duplicate/cancellation/failure tests.
- Mid-scan quota exhaustion/pause behavior tests.
- Concurrent scans near quota boundary tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define exact meter/weight lookup from versioned configuration and include it in scan snapshots.
- [ ] Reserve estimated scan credits at admission and charge/finalize actual operations through idempotent source keys.
- [ ] Track HTTP fetch attempts vs successful billable fetches according to documented policy.
- [ ] Reserve incremental credits before expanding beyond estimate; pause/cancel safely if unavailable.
- [ ] Release unused reservation at terminal scan state and recover after crashes.
- [ ] Expose per-scan cost breakdown and organization usage aggregation.
- [ ] Ensure provider/internal retries do not create duplicate usage events.
- [ ] Add audit/support adjustment path through compensating events only.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not charge simply for enqueuing a job.
- Credit weights are versioned facts of the scan, not mutable global lookups after execution.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 072 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 072 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 072
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
