---
id: '041'
title: Build pricing, plan comparison and usage UI
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '040'
status: pending
---

# Prompt 041 — Build pricing, plan comparison and usage UI

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `040`
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
ruby tracking/scripts/prompt_tracker.rb start 041
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

Expose the internal plan catalog and organization usage transparently without hardcoding commercial rules into views.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/01_PRD_V1.md`

## Required work

1. Build public pricing and authenticated plan comparison pages from published plan-version/read-model data.
2. Display key features, limits, interval/currency and grandfathered/current plan status accurately.
3. Create an organization usage page showing used, reserved, remaining, reset date and meter explanations.
4. Represent unlimited, disabled, unavailable and temporarily reserved states distinctly.
5. Add upgrade/downgrade calls to action gated by billing permission and provider availability.
6. Show quota errors with actionable links while preserving access to existing scans/reports according to policy.
7. Add accessible tables/cards and responsive behavior.

## Required verification

- View/request tests for every plan and special value state.
- Authorization tests for billing controls.
- System test for quota-exhausted messaging.
- Verify views do not compare plan names or provider variant IDs.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Build public pricing and authenticated plan comparison pages from published plan-version/read-model data.
- [ ] Display key features, limits, interval/currency and grandfathered/current plan status accurately.
- [ ] Create an organization usage page showing used, reserved, remaining, reset date and meter explanations.
- [ ] Represent unlimited, disabled, unavailable and temporarily reserved states distinctly.
- [ ] Add upgrade/downgrade calls to action gated by billing permission and provider availability.
- [ ] Show quota errors with actionable links while preserving access to existing scans/reports according to policy.
- [ ] Add accessible tables/cards and responsive behavior.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Prices are display data until billing adapter checkout confirms them.
- Do not claim taxes are included unless provider response/configuration says so.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 041 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 041 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 041
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
