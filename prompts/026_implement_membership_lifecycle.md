---
id: '026'
title: Implement membership lifecycle
phase: 03 Organizations, membership and RBAC
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '025'
status: pending
---

# Prompt 026 — Implement membership lifecycle

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `025`
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
ruby tracking/scripts/prompt_tracker.rb start 026
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

Model active, invited, suspended and removed membership behavior with database/domain invariants and explicit audit history.

## Required references

- `docs/03_ERD.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create memberships linked to one user and organization with status, accepted/suspended/removed timestamps and safe display metadata.
2. Define allowed lifecycle transitions and central domain operations for suspend, reactivate and remove.
3. Prevent duplicate active/invited membership for the same user/organization through database indexes and locking.
4. Ensure removal/suspension immediately affects tenant context and relevant sessions.
5. Preserve historical attribution on issues/comments/audit records after removal.
6. Add list/detail UI foundations and pagination.
7. Emit audit events for every transition with actor and target.

## Required verification

- Transition and database constraint tests.
- Concurrent duplicate membership creation test.
- Request/job tests proving suspended/removed members lose access.
- Historical attribution tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create memberships linked to one user and organization with status, accepted/suspended/removed timestamps and safe display metadata.
- [ ] Define allowed lifecycle transitions and central domain operations for suspend, reactivate and remove.
- [ ] Prevent duplicate active/invited membership for the same user/organization through database indexes and locking.
- [ ] Ensure removal/suspension immediately affects tenant context and relevant sessions.
- [ ] Preserve historical attribution on issues/comments/audit records after removal.
- [ ] Add list/detail UI foundations and pagination.
- [ ] Emit audit events for every transition with actor and target.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not delete user-authored history when removing a membership.
- Do not let membership status be inferred from role rows.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 026 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 026 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 026
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
