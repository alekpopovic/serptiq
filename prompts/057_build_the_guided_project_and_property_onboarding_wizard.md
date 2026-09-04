---
id: '057'
title: Build the guided project and property onboarding wizard
phase: 05 Projects, properties and verification
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '056'
status: pending
---

# Prompt 057 — Build the guided project and property onboarding wizard

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `056`
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
ruby tracking/scripts/prompt_tracker.rb start 057
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

Create a resumable, accessible onboarding path from organization to verified project/property and initial scan readiness.

## Required references

- `docs/01_PRD_V1.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`

## Required work

1. Implement server-side persisted onboarding state for project basics, property type, environment/origin, verification method, crawl settings and review.
2. Allow safe back/forward/resume without trusting hidden state or creating duplicate aggregates.
3. Show plan entitlement/limit effects before creation and reserve no scan credits until actual scan admission.
4. Handle website-only and combined web/mobile product paths.
5. Route invited/scoped users according to permissions and prevent them from escalating configuration.
6. Provide factual readiness checklist: property exists, origin normalized, ownership verified, scan settings valid.
7. Instrument abandonment/step completion with privacy-safe events.
8. Add cancellation cleanup for drafts.

## Required verification

- System tests for website, Android/iOS addition, resume and validation failure.
- Duplicate submission/idempotency tests.
- Permission/entitlement/quota boundary tests.
- No-JavaScript and accessibility checks.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement server-side persisted onboarding state for project basics, property type, environment/origin, verification method, crawl settings and review.
- [ ] Allow safe back/forward/resume without trusting hidden state or creating duplicate aggregates.
- [ ] Show plan entitlement/limit effects before creation and reserve no scan credits until actual scan admission.
- [ ] Handle website-only and combined web/mobile product paths.
- [ ] Route invited/scoped users according to permissions and prevent them from escalating configuration.
- [ ] Provide factual readiness checklist: property exists, origin normalized, ownership verified, scan settings valid.
- [ ] Instrument abandonment/step completion with privacy-safe events.
- [ ] Add cancellation cleanup for drafts.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not claim a property is verified before challenge success.
- Do not start a crawl from a GET or page refresh.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 057 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 057 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 057
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
