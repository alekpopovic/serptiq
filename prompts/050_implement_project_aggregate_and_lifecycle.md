---
id: '050'
title: Implement project aggregate and lifecycle
phase: 05 Projects, properties and verification
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 049
status: pending
---

# Prompt 050 — Implement project aggregate and lifecycle

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `049`
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
ruby tracking/scripts/prompt_tracker.rb start 050
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

Create organization-owned product/projects as the principal authorization and reporting boundary for related web and mobile properties.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`

## Required work

1. Create projects with UUID, organization, stable key/slug, name, description, lifecycle state, default locale/timezone and external release key.
2. Define active, archived and pending-deletion transitions with centralized operations.
3. Enforce organization ownership and unique keys through database constraints.
4. Create CRUD/list/detail UI protected by project permissions and pagination/search.
5. Create initial project-scoped role assignment hooks without granting implicit access beyond documented organization roles.
6. Emit audit events and preserve archived history.
7. Add read model placeholders for health, property counts and latest scan without N+1 queries.

## Required verification

- Model/database lifecycle and uniqueness tests.
- Cross-tenant request/index tests.
- Archive/reactivate permission tests.
- System tests for project CRUD.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create projects with UUID, organization, stable key/slug, name, description, lifecycle state, default locale/timezone and external release key.
- [ ] Define active, archived and pending-deletion transitions with centralized operations.
- [ ] Enforce organization ownership and unique keys through database constraints.
- [ ] Create CRUD/list/detail UI protected by project permissions and pagination/search.
- [ ] Create initial project-scoped role assignment hooks without granting implicit access beyond documented organization roles.
- [ ] Emit audit events and preserve archived history.
- [ ] Add read model placeholders for health, property counts and latest scan without N+1 queries.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use projects as billing tenants; organization remains the billing boundary.
- Archived projects do not permit new scans.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 050 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 050 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 050
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
