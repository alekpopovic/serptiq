---
id: '034'
title: Enforce last-owner and member-removal invariants
phase: 03 Organizations, membership and RBAC
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '033'
status: pending
---

# Prompt 034 — Enforce last-owner and member-removal invariants

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `033`
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
ruby tracking/scripts/prompt_tracker.rb start 034
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

Close role and membership lifecycle gaps so administrative actions can never remove the last owner or preserve unintended access.

## Required references

- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Centralize last-owner checks across membership removal, suspension, role revocation, team changes and organization archive/delete flows.
2. Use locking and database/domain constraints to handle concurrent owner changes.
3. Revoke active sessions and queued user-context actions when a member is suspended/removed according to policy.
4. Reassign or preserve ownership of issues/reports/history without breaking attribution.
5. Define self-removal behavior and require transfer when the actor is the last owner.
6. Create user-facing conflict messages and operator diagnostics.
7. Add repair/audit query for organizations with inconsistent owner state, expected to return zero.

## Required verification

- Concurrent two-owner removal/revocation tests.
- Tests for every path that could remove effective owner status.
- Session/job access revocation tests.
- Run consistency query in test fixtures.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Centralize last-owner checks across membership removal, suspension, role revocation, team changes and organization archive/delete flows.
- [ ] Use locking and database/domain constraints to handle concurrent owner changes.
- [ ] Revoke active sessions and queued user-context actions when a member is suspended/removed according to policy.
- [ ] Reassign or preserve ownership of issues/reports/history without breaking attribution.
- [ ] Define self-removal behavior and require transfer when the actor is the last owner.
- [ ] Create user-facing conflict messages and operator diagnostics.
- [ ] Add repair/audit query for organizations with inconsistent owner state, expected to return zero.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not rely solely on a stale pre-count of owners.
- Do not erase historical actor attribution.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 034 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 034 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 034
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
