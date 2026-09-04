---
id: '031'
title: Implement the authorization decision service
phase: 03 Organizations, membership and RBAC
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '030'
status: pending
---

# Prompt 031 — Implement the authorization decision service

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `030`
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
ruby tracking/scripts/prompt_tracker.rb start 031
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

Create one explainable authorization engine that resolves active membership, effective scoped permissions and resource state without coupling to plan entitlements.

## Required references

- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `AGENTS.md`
- `docs/adr/0004_separate_rbac_entitlements_and_quotas.md`

## Required work

1. Define an authorization request/value object containing actor membership, permission key, organization and optional project/property/resource.
2. Resolve direct and team role assignments at compatible ancestor scopes and return a structured allow/deny decision with internal reason code.
3. Keep RBAC independent from entitlements and quotas; expose a later orchestration point rather than calling billing inside the policy.
4. Cache only safely within a request or with revision-based invalidation; privilege changes must take effect promptly.
5. Support grant-management decisions including protected owner permissions.
6. Instrument decisions with bounded metadata and audit high-risk denials without logging customer content.
7. Create a policy adapter/concern for controllers, views, jobs and domain operations.

## Required verification

- Truth-table tests for all scopes and principals.
- Cross-tenant, suspended, archived and unknown-permission denial tests.
- Cache invalidation/privilege-change tests.
- Performance test for a representative member with direct/team assignments.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define an authorization request/value object containing actor membership, permission key, organization and optional project/property/resource.
- [ ] Resolve direct and team role assignments at compatible ancestor scopes and return a structured allow/deny decision with internal reason code.
- [ ] Keep RBAC independent from entitlements and quotas; expose a later orchestration point rather than calling billing inside the policy.
- [ ] Cache only safely within a request or with revision-based invalidation; privilege changes must take effect promptly.
- [ ] Support grant-management decisions including protected owner permissions.
- [ ] Instrument decisions with bounded metadata and audit high-risk denials without logging customer content.
- [ ] Create a policy adapter/concern for controllers, views, jobs and domain operations.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Views may hide controls but are never the enforcement boundary.
- Unknown permission keys must fail closed.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 031 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 031 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 031
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
