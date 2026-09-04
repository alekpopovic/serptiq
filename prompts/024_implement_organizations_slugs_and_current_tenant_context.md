---
id: '024'
title: Implement organizations, slugs and current tenant context
phase: 03 Organizations, membership and RBAC
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '023'
status: pending
---

# Prompt 024 — Implement organizations, slugs and current tenant context

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `023`
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
ruby tracking/scripts/prompt_tracker.rb start 024
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

Create the tenant aggregate and establish explicit, verified organization context for every tenant request and background operation.

## Required references

- `docs/03_ERD.md`
- `AGENTS.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create organizations with UUID IDs, normalized unique slugs, display metadata, lifecycle status and ownership timestamps according to the ERD.
2. Implement organization creation as a transaction that also creates the initial owner membership and required role assignment.
3. Resolve organization from a stable route segment or explicit selector only after authenticating the user and validating active membership.
4. Set `Current.organization` and `Current.membership` together; clear context after each request/job.
5. Create tenant-aware query entry points and prohibit `default_scope` as an isolation mechanism.
6. Add organization switcher data without leaking names/counts from inaccessible organizations.
7. Emit audit events for create, rename/slug change and lifecycle state.
8. Create reusable tenant-isolation request helpers.

## Required verification

- Database tests for slug/ownership constraints.
- Request tests with IDs/slugs from a second organization.
- Thread/request context leakage tests.
- Transaction rollback test proving no ownerless organization can be created.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create organizations with UUID IDs, normalized unique slugs, display metadata, lifecycle status and ownership timestamps according to the ERD.
- [ ] Implement organization creation as a transaction that also creates the initial owner membership and required role assignment.
- [ ] Resolve organization from a stable route segment or explicit selector only after authenticating the user and validating active membership.
- [ ] Set `Current.organization` and `Current.membership` together; clear context after each request/job.
- [ ] Create tenant-aware query entry points and prohibit `default_scope` as an isolation mechanism.
- [ ] Add organization switcher data without leaking names/counts from inaccessible organizations.
- [ ] Emit audit events for create, rename/slug change and lifecycle state.
- [ ] Create reusable tenant-isolation request helpers.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never derive authorization from possession of a slug.
- No tenant-owned row may become ambiguously shared.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 024 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 024 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 024
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
