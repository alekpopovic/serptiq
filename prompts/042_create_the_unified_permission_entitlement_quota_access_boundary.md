---
id: '042'
title: Create the unified permission-entitlement-quota access boundary
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '041'
status: pending
---

# Prompt 042 — Create the unified permission-entitlement-quota access boundary

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `041`
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
ruby tracking/scripts/prompt_tracker.rb start 042
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

Implement one orchestration service that makes protected billable decisions while preserving separate RBAC, entitlement and quota responsibilities.

## Required references

- `AGENTS.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/adr/0004_separate_rbac_entitlements_and_quotas.md`

## Required work

1. Define an access request containing actor, permission, scope/resource, optional entitlement and optional metered quantity/idempotency key.
2. Evaluate authentication/membership, RBAC, entitlement, resource state and quota in a stable order that avoids information leakage and unnecessary reservations.
3. Return a structured decision with public error code and internal reason/provenance.
4. Reserve quota only after permission/entitlement/resource validation and provide a block/yield API that releases on pre-enqueue failure.
5. Make controller/job/API integrations explicit and hard to bypass.
6. Instrument allow/deny/reserve outcomes with bounded labels.
7. Create a developer guide mapping feature operations to permission, entitlement and meter keys.

## Required verification

- Full truth-table tests from `docs/09_TEST_STRATEGY.md`.
- Test denial ordering does not reveal another tenant's entitlement/resource.
- Test enqueue failure releases reservation.
- Architecture test rejects direct plan-name checks and unauthorized quota mutation patterns where practical.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define an access request containing actor, permission, scope/resource, optional entitlement and optional metered quantity/idempotency key.
- [ ] Evaluate authentication/membership, RBAC, entitlement, resource state and quota in a stable order that avoids information leakage and unnecessary reservations.
- [ ] Return a structured decision with public error code and internal reason/provenance.
- [ ] Reserve quota only after permission/entitlement/resource validation and provide a block/yield API that releases on pre-enqueue failure.
- [ ] Make controller/job/API integrations explicit and hard to bypass.
- [ ] Instrument allow/deny/reserve outcomes with bounded labels.
- [ ] Create a developer guide mapping feature operations to permission, entitlement and meter keys.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not collapse all denials into one internal category.
- Do not expose sensitive internal denial details to clients.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 042 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 042 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 042
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
