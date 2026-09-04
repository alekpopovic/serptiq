---
id: '040'
title: Implement atomic quota reservations and finalization
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 039
status: pending
---

# Prompt 040 — Implement atomic quota reservations and finalization

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `039`
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
ruby tracking/scripts/prompt_tracker.rb start 040
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

Prevent oversubscription by reserving estimated credits atomically before asynchronous work and reconciling actual consumption afterward.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/adr/0004_separate_rbac_entitlements_and_quotas.md`

## Required work

1. Create quota reservations with organization, meter/window, idempotency key, requested/held/consumed/released quantities, expiry and source aggregate.
2. Implement a PostgreSQL transaction/locking strategy that checks entitlement limit, committed usage and active reservations atomically.
3. Support unlimited plans explicitly, not through an unsafe sentinel arithmetic shortcut.
4. Implement reserve, extend where allowed, finalize actual usage, release unused quantity and expire abandoned reservations.
5. Make all operations idempotent and resilient to worker retry/cancellation.
6. Snapshot relevant entitlement/plan context at admission so mid-scan plan changes have documented behavior.
7. Create maintenance recovery and reconciliation for stale reservations.
8. Return structured denial with limit, used, reserved, requested and reset time safe for UI/API.

## Required verification

- Real PostgreSQL concurrent reservation race tests at the exact quota boundary.
- Idempotent retry/finalize/release tests.
- Plan change and window rollover tests.
- Crash/stale reservation recovery tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create quota reservations with organization, meter/window, idempotency key, requested/held/consumed/released quantities, expiry and source aggregate.
- [ ] Implement a PostgreSQL transaction/locking strategy that checks entitlement limit, committed usage and active reservations atomically.
- [ ] Support unlimited plans explicitly, not through an unsafe sentinel arithmetic shortcut.
- [ ] Implement reserve, extend where allowed, finalize actual usage, release unused quantity and expire abandoned reservations.
- [ ] Make all operations idempotent and resilient to worker retry/cancellation.
- [ ] Snapshot relevant entitlement/plan context at admission so mid-scan plan changes have documented behavior.
- [ ] Create maintenance recovery and reconciliation for stale reservations.
- [ ] Return structured denial with limit, used, reserved, requested and reset time safe for UI/API.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use cache counters as the source of truth.
- Failed admission must create no charge.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 040 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 040 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 040
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
