---
id: '025'
title: Build organization creation, settings and switcher flows
phase: 03 Organizations, membership and RBAC
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '024'
status: pending
---

# Prompt 025 — Build organization creation, settings and switcher flows

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `024`
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
ruby tracking/scripts/prompt_tracker.rb start 025
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

Expose the organization lifecycle foundation through accessible Rails screens while keeping privileged settings separate from ordinary navigation.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`

## Required work

1. Implement organization creation for eligible users with validated name/slug and clear error recovery.
2. Build organization switcher using only active memberships and preserve a safe local destination.
3. Create settings pages for general metadata with placeholders for billing/security sections.
4. Handle slug changes with an explicit policy for redirects/reserved slugs and auditability.
5. Show suspended/archived states accurately and prevent mutations when lifecycle policy denies them.
6. Add breadcrumbs/navigation that preserve organization context without trusting hidden form fields.
7. Provide empty states leading to project creation only after authorization is implemented.

## Required verification

- System tests for create, switch, rename and inaccessible slug.
- Tests for reserved/case-conflicting slugs.
- Cross-tenant form submission tests.
- Accessibility and no-JavaScript checks.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement organization creation for eligible users with validated name/slug and clear error recovery.
- [ ] Build organization switcher using only active memberships and preserve a safe local destination.
- [ ] Create settings pages for general metadata with placeholders for billing/security sections.
- [ ] Handle slug changes with an explicit policy for redirects/reserved slugs and auditability.
- [ ] Show suspended/archived states accurately and prevent mutations when lifecycle policy denies them.
- [ ] Add breadcrumbs/navigation that preserve organization context without trusting hidden form fields.
- [ ] Provide empty states leading to project creation only after authorization is implemented.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not expose billing controls yet.
- Do not accept an organization ID from the client without resolving it through active membership.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 025 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 025 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 025
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
