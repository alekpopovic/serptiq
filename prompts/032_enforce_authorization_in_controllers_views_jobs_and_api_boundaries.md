---
id: '032'
title: Enforce authorization in controllers, views, jobs and API boundaries
phase: 03 Organizations, membership and RBAC
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '031'
status: pending
---

# Prompt 032 — Enforce authorization in controllers, views, jobs and API boundaries

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `031`
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
ruby tracking/scripts/prompt_tracker.rb start 032
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

Apply the authorization service consistently to all existing tenant actions and establish reusable enforcement patterns for future features.

## Required references

- `AGENTS.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Inventory every authenticated tenant route/domain operation and map it to a permission key.
2. Add controller/request enforcement before record exposure, including index scopes and nested resources.
3. Add view helpers that consume prior decisions for UI visibility but do not replace backend checks.
4. Require background jobs to receive explicit organization/resource IDs, reload records and re-authorize the intended system/user context according to job policy.
5. Create API authorization error contracts for later use.
6. Add automated coverage/architecture checks that identify tenant controllers lacking an explicit permission declaration where practical.
7. Document the pattern with examples for organization-, project- and property-scoped actions.

## Required verification

- Cross-tenant request tests for every existing tenant route.
- Negative permission tests and list/index leakage tests.
- Background job mismatched-tenant tests.
- System test showing controls hidden and direct request still denied.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Inventory every authenticated tenant route/domain operation and map it to a permission key.
- [ ] Add controller/request enforcement before record exposure, including index scopes and nested resources.
- [ ] Add view helpers that consume prior decisions for UI visibility but do not replace backend checks.
- [ ] Require background jobs to receive explicit organization/resource IDs, reload records and re-authorize the intended system/user context according to job policy.
- [ ] Create API authorization error contracts for later use.
- [ ] Add automated coverage/architecture checks that identify tenant controllers lacking an explicit permission declaration where practical.
- [ ] Document the pattern with examples for organization-, project- and property-scoped actions.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never fetch an unscoped record and authorize after rendering.
- Do not pass serialized `Current` objects into jobs.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 032 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 032 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 032
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
