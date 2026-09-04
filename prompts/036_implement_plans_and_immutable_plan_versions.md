---
id: '036'
title: Implement plans and immutable plan versions
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '035'
status: pending
---

# Prompt 036 — Implement plans and immutable plan versions

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `035`
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
ruby tracking/scripts/prompt_tracker.rb start 036
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

Create the internal commercial catalog so subscriptions reference immutable plan versions rather than mutable plan-name conditionals.

## Required references

- `docs/03_ERD.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `config_blueprints/plans.yml`
- `docs/adr/0004_separate_rbac_entitlements_and_quotas.md`

## Required work

1. Create `plans` and `plan_versions` with stable keys, display metadata, currency/pricing presentation fields, lifecycle state, effective dates and immutable published snapshots.
2. Represent Free, Starter, Growth, Agency and Enterprise as products/catalog entries without embedding provider variant IDs in core domain code.
3. Define draft, published, retired and grandfathered behavior; published versions cannot be mutated in place.
4. Store customer subscriptions against a specific plan version and preserve historical display/pricing metadata.
5. Add idempotent catalog synchronization from `config_blueprints/plans.yml` with validation and a dry-run mode.
6. Implement administrative read-only catalog screens and a controlled publish operation protected by permission/audit.
7. Document migration policy for plan changes and grandfathering.

## Required verification

- Database constraints for stable keys/version uniqueness and immutable published data.
- Config validation and idempotent sync tests.
- Tests proving existing subscription references are unaffected by a new version.
- Audit/authorization tests for publish/retire.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create `plans` and `plan_versions` with stable keys, display metadata, currency/pricing presentation fields, lifecycle state, effective dates and immutable published snapshots.
- [ ] Represent Free, Starter, Growth, Agency and Enterprise as products/catalog entries without embedding provider variant IDs in core domain code.
- [ ] Define draft, published, retired and grandfathered behavior; published versions cannot be mutated in place.
- [ ] Store customer subscriptions against a specific plan version and preserve historical display/pricing metadata.
- [ ] Add idempotent catalog synchronization from `config_blueprints/plans.yml` with validation and a dry-run mode.
- [ ] Implement administrative read-only catalog screens and a controlled publish operation protected by permission/audit.
- [ ] Document migration policy for plan changes and grandfathering.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never branch business logic on display name.
- Do not edit a published plan version in place.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 036 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 036 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 036
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
