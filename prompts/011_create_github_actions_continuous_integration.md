---
id: '011'
title: Create GitHub Actions continuous integration
phase: 01 Rails and operational foundation
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '010'
status: pending
---

# Prompt 011 — Create GitHub Actions continuous integration

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `010`
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
ruby tracking/scripts/prompt_tracker.rb start 011
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

Build a secure CI pipeline that reproduces the required quality gates and produces actionable artifacts without exposing credentials.

## Required references

- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Create GitHub Actions workflows for dependency setup/cache, PostgreSQL services, lint/static analysis, tests, system/browser tests, tracker validation, assets and production container boot.
2. Pin actions to trusted immutable versions/commits according to repository policy and grant minimal token permissions.
3. Use dependency caches keyed by lockfiles without caching secrets or mutable build output.
4. Split fast and browser/security jobs for useful feedback while retaining a required aggregate gate.
5. Upload failure-only test/browser artifacts with bounded retention.
6. Add concurrency cancellation for superseded branch runs, but never cancel an active protected-branch deployment automatically.
7. Document required branch protection checks and how to reproduce each job locally.

## Required verification

- Validate workflow syntax.
- Run equivalent local commands for every CI job.
- Build the production image and boot `/up` in CI or a local equivalent.
- Confirm workflows contain no real provider credentials.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create GitHub Actions workflows for dependency setup/cache, PostgreSQL services, lint/static analysis, tests, system/browser tests, tracker validation, assets and production container boot.
- [ ] Pin actions to trusted immutable versions/commits according to repository policy and grant minimal token permissions.
- [ ] Use dependency caches keyed by lockfiles without caching secrets or mutable build output.
- [ ] Split fast and browser/security jobs for useful feedback while retaining a required aggregate gate.
- [ ] Upload failure-only test/browser artifacts with bounded retention.
- [ ] Add concurrency cancellation for superseded branch runs, but never cancel an active protected-branch deployment automatically.
- [ ] Document required branch protection checks and how to reproduce each job locally.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use long-lived cloud credentials when OIDC or scoped alternatives are available later.
- CI must not run production migrations or deployments.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 011 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 011 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 011
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
