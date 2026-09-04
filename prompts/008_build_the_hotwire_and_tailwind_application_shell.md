---
id: 008
title: Build the Hotwire and Tailwind application shell
phase: 01 Rails and operational foundation
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '007'
status: pending
---

# Prompt 008 — Build the Hotwire and Tailwind application shell

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `007`
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
ruby tracking/scripts/prompt_tracker.rb start 008
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

Create an accessible, responsive Rails/Hotwire application shell suitable for organization/project workflows without introducing a separate SPA.

## Required references

- `docs/01_PRD_V1.md`
- `docs/02_ARCHITECTURE.md`

## Required work

1. Create public and authenticated layouts with semantic landmarks, skip link, flash region, navigation, account menu and responsive sidebar/topbar behavior.
2. Establish Tailwind design tokens/components for typography, spacing, forms, buttons, badges, alerts, tables, cards, dialogs, pagination and empty/loading states.
3. Use Turbo Frames/Streams and small Stimulus controllers only where interaction requires them; preserve server-rendered navigation and form behavior.
4. Implement reusable partials/components with explicit locals and avoid global view state.
5. Create placeholder dashboard and public home/sign-in surfaces clearly marked as implementation scaffolding, not fake completed product screens.
6. Add accessible error summaries, focus behavior and reduced-motion considerations.
7. Document frontend conventions and where future charting may be introduced.

## Required verification

- Run system tests for keyboard navigation, validation errors and responsive navigation.
- Run accessibility checks available locally/CI.
- Verify core navigation and forms remain usable without JavaScript.
- Run asset compilation and the test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create public and authenticated layouts with semantic landmarks, skip link, flash region, navigation, account menu and responsive sidebar/topbar behavior.
- [ ] Establish Tailwind design tokens/components for typography, spacing, forms, buttons, badges, alerts, tables, cards, dialogs, pagination and empty/loading states.
- [ ] Use Turbo Frames/Streams and small Stimulus controllers only where interaction requires them; preserve server-rendered navigation and form behavior.
- [ ] Implement reusable partials/components with explicit locals and avoid global view state.
- [ ] Create placeholder dashboard and public home/sign-in surfaces clearly marked as implementation scaffolding, not fake completed product screens.
- [ ] Add accessible error summaries, focus behavior and reduced-motion considerations.
- [ ] Document frontend conventions and where future charting may be introduced.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not introduce React, Angular or a client-side state framework.
- Do not hardcode organization/project data in the layout.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 008 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 008 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 008
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
