---
id: 089
title: Implement issue workflow, assignment, comments and verified resolution
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 088
status: pending
---

# Prompt 089 — Implement issue workflow, assignment, comments and verified resolution

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `088`
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
ruby tracking/scripts/prompt_tracker.rb start 089
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

Turn findings into collaborative work with explicit ownership, lifecycle, risk acceptance and scan-based verification.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Create issues linked to one or more findings with status transitions: detected, triaged, accepted, in_progress, ready_for_verification, resolved, reopened, ignored, false_positive and risk_accepted as appropriate.
2. Define allowed transitions/permissions and keep finding technical presence separate from human workflow state.
3. Implement assignments to active memberships/teams in the same organization and optional due date/priority.
4. Create comments/activity with sanitized Markdown/plain text, edits policy and historical attribution.
5. Implement suppression/risk acceptance with reason, actor, expiry and scope; audit every change.
6. Trigger targeted verification from ready state using unified access/quota flow.
7. Resolve only when verification evidence meets policy; reopen on recurrence.
8. Build issue board/list/detail UI with Turbo updates and notifications hooks.

## Required verification

- State-machine and permission matrix tests.
- Cross-tenant assignment/comment/finding tests.
- Verification success/failure/reopen tests.
- XSS/sanitization, concurrency and audit tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create issues linked to one or more findings with status transitions: detected, triaged, accepted, in_progress, ready_for_verification, resolved, reopened, ignored, false_positive and risk_accepted as appropriate.
- [ ] Define allowed transitions/permissions and keep finding technical presence separate from human workflow state.
- [ ] Implement assignments to active memberships/teams in the same organization and optional due date/priority.
- [ ] Create comments/activity with sanitized Markdown/plain text, edits policy and historical attribution.
- [ ] Implement suppression/risk acceptance with reason, actor, expiry and scope; audit every change.
- [ ] Trigger targeted verification from ready state using unified access/quota flow.
- [ ] Resolve only when verification evidence meets policy; reopen on recurrence.
- [ ] Build issue board/list/detail UI with Turbo updates and notifications hooks.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- A user-clicked close is not proof the technical issue disappeared.
- Do not assign work to inactive/out-of-tenant principals.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 089 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 089 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 089
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
