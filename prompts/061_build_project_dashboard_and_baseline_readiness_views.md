---
id: '061'
title: Build project dashboard and baseline readiness views
phase: 05 Projects, properties and verification
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '060'
status: pending
---

# Prompt 061 — Build project dashboard and baseline readiness views

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `060`
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
ruby tracking/scripts/prompt_tracker.rb start 061
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

Create the first useful project dashboard that reflects real state and guides the user to verification/scan actions without fake metrics.

## Required references

- `docs/01_PRD_V1.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`

## Required work

1. Build a project overview with properties, verification status, latest scan state, finding counts placeholders/read models, usage and integration readiness.
2. Show clear empty states before scans and distinguish unavailable, loading, failed, stale and no-data states.
3. Use permission/entitlement decisions for actions and explain disabled controls.
4. Add property/environment navigation and readiness checklist.
5. Prepare Turbo Stream targets for later scan progress without coupling dashboard queries to queue internals.
6. Optimize queries and add pagination for property/activity lists.
7. Add audit/recent activity summaries from real records.

## Required verification

- View/system tests for empty, ready, archived, quota-exhausted and restricted user states.
- Query-count/N+1 regression test.
- Cross-tenant dashboard test.
- Accessibility/responsive checks.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Build a project overview with properties, verification status, latest scan state, finding counts placeholders/read models, usage and integration readiness.
- [ ] Show clear empty states before scans and distinguish unavailable, loading, failed, stale and no-data states.
- [ ] Use permission/entitlement decisions for actions and explain disabled controls.
- [ ] Add property/environment navigation and readiness checklist.
- [ ] Prepare Turbo Stream targets for later scan progress without coupling dashboard queries to queue internals.
- [ ] Optimize queries and add pagination for property/activity lists.
- [ ] Add audit/recent activity summaries from real records.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fabricate SEO scores before rule execution exists.
- Do not expose raw internal IDs or queue details.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 061 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 061 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 061
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
