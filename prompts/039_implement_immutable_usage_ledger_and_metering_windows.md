---
id: 039
title: Implement immutable usage ledger and metering windows
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 038
status: pending
---

# Prompt 039 — Implement immutable usage ledger and metering windows

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `038`
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
ruby tracking/scripts/prompt_tracker.rb start 039
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

Create an append-only usage ledger and deterministic billing/entitlement windows for all variable-cost operations.

## Required references

- `docs/03_ERD.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Create usage meter definitions for HTTP crawl credits, rendered pages, Lighthouse runs, app-store snapshots, reports and other configured units.
2. Create usage windows tied to organization, meter, start/end, plan/subscription context and timezone policy.
3. Create append-only usage events with idempotency key, quantity, source aggregate, occurred/recorded timestamps and metadata bounds.
4. Implement current-window resolution and aggregation that handles UTC calendar months and provider billing periods explicitly.
5. Prevent updates/deletes through normal domain APIs; corrections use compensating events with references.
6. Create query/read models for used, reserved, remaining and unlimited values.
7. Add retention/partitioning notes for high-volume ledgers and indexes for organization/window/source.
8. Emit audit events for manual adjustments.

## Required verification

- Idempotency and append-only tests.
- Boundary tests at window rollover/timezone/DST.
- Compensating-event and aggregate consistency tests.
- Cross-tenant source/meter tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create usage meter definitions for HTTP crawl credits, rendered pages, Lighthouse runs, app-store snapshots, reports and other configured units.
- [ ] Create usage windows tied to organization, meter, start/end, plan/subscription context and timezone policy.
- [ ] Create append-only usage events with idempotency key, quantity, source aggregate, occurred/recorded timestamps and metadata bounds.
- [ ] Implement current-window resolution and aggregation that handles UTC calendar months and provider billing periods explicitly.
- [ ] Prevent updates/deletes through normal domain APIs; corrections use compensating events with references.
- [ ] Create query/read models for used, reserved, remaining and unlimited values.
- [ ] Add retention/partitioning notes for high-volume ledgers and indexes for organization/window/source.
- [ ] Emit audit events for manual adjustments.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never overwrite usage history to correct it.
- Quantities and units must not mix within a meter.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 039 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 039 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 039
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
