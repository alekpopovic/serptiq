---
id: 059
title: Complete project- and property-scoped access enforcement
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 058
status: pending
---

# Prompt 059 — Complete project- and property-scoped access enforcement

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `058`
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
ruby tracking/scripts/prompt_tracker.rb start 059
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

Apply scoped RBAC to the full project/property/environment/verification surface and prove list/query isolation.

## Required references

- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/09_TEST_STRATEGY.md`
- `AGENTS.md`

## Required work

1. Map every project/property action to a permission and compatible scope.
2. Ensure organization-scoped grants inherit downward while project/property grants never grant sibling or organization administration.
3. Scope all collection queries before pagination/search/counts.
4. Prevent nested-route ID substitution across projects/properties.
5. Ensure team-derived roles and archived principal/resource behavior match the resolver.
6. Add reusable shared examples for project/property authorization.
7. Review audit entries and UI controls for scope correctness.

## Required verification

- Exhaustive two-organization/two-project/two-property matrix tests.
- Index count/search leakage tests.
- Nested route substitution tests.
- System test for a client viewer restricted to one project.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Map every project/property action to a permission and compatible scope.
- [ ] Ensure organization-scoped grants inherit downward while project/property grants never grant sibling or organization administration.
- [ ] Scope all collection queries before pagination/search/counts.
- [ ] Prevent nested-route ID substitution across projects/properties.
- [ ] Ensure team-derived roles and archived principal/resource behavior match the resolver.
- [ ] Add reusable shared examples for project/property authorization.
- [ ] Review audit entries and UI controls for scope correctness.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not authorize child resources using only parent URL parameters.
- Property-scoped grants cannot access project billing/member administration.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 059 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 059 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 059
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
