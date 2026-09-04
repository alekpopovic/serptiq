---
id: '030'
title: Implement scoped role assignments
phase: 03 Organizations, membership and RBAC
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 029
status: pending
---

# Prompt 030 — Implement scoped role assignments

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `029`
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
ruby tracking/scripts/prompt_tracker.rb start 030
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

Assign roles to users or teams at organization, project and property scopes with strict scope/tenant consistency.

## Required references

- `docs/03_ERD.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create role assignments supporting membership or team principals and organization/project/property scope targets as defined in the ERD.
2. Enforce that principal, role and scope all belong to the same organization and that a property belongs to the scoped project.
3. Define precedence/union behavior and explicitly reject deny semantics for the MVP unless documented otherwise.
4. Implement assign/revoke operations with grant authority checks and protection against self-escalation.
5. Handle archived teams/projects/properties and suspended memberships deterministically.
6. Emit audit events including actor, principal, role and scope.
7. Create queries optimized for effective-permission resolution without N+1 behavior.

## Required verification

- Database and domain tests for every cross-tenant mismatch.
- Tests for direct + team grant union and narrower scope.
- Concurrent duplicate assignment/revocation tests.
- Self-escalation and unauthorized grant tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create role assignments supporting membership or team principals and organization/project/property scope targets as defined in the ERD.
- [ ] Enforce that principal, role and scope all belong to the same organization and that a property belongs to the scoped project.
- [ ] Define precedence/union behavior and explicitly reject deny semantics for the MVP unless documented otherwise.
- [ ] Implement assign/revoke operations with grant authority checks and protection against self-escalation.
- [ ] Handle archived teams/projects/properties and suspended memberships deterministically.
- [ ] Emit audit events including actor, principal, role and scope.
- [ ] Create queries optimized for effective-permission resolution without N+1 behavior.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No wildcard database grants.
- Do not allow an actor to grant permissions beyond their authorized grant policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 030 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 030 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 030
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
