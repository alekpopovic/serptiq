---
id: '001'
title: Initialize Rails application and pin a compatible baseline
phase: 00 Governance and bootstrap
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '000'
status: pending
---

# Prompt 001 — Initialize Rails application and pin a compatible baseline

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `000`
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
ruby tracking/scripts/prompt_tracker.rb start 001
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

Create the Rails application in the repository root using a verified, mutually compatible Ruby and Rails patch baseline. Preserve the blueprint, use PostgreSQL and the Rails default Solid components, and leave a reproducible application that boots in all intended modes.

## Required references

- `docs/00_EXECUTIVE_SUMMARY.md`
- `docs/02_ARCHITECTURE.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/adr/0001_modular_rails_monolith.md`

## Required work

1. Review the baseline report and verify current supported/security-patched Ruby and Rails versions before pinning. Start from the documented 2026-09-04 baseline only when compatibility and advisories still permit it.
2. Create or merge the Rails application into the repository root without overwriting `docs/`, `prompts/`, `tracking/`, `schemas/`, `config_blueprints/`, `AGENTS.md`, or the READMEs.
3. Configure PostgreSQL as the only database technology and retain Hotwire/Turbo/Stimulus, ERB, Tailwind, Minitest, Active Job, Active Storage and the Rails Solid defaults.
4. Explicitly exclude Devise, OmniAuth, Doorkeeper, Sidekiq, Redis, Elasticsearch and Kubernetes-related dependencies.
5. Pin Ruby, Rails, Bundler and relevant runtime versions through repository-standard files; commit the lockfile and document the exact command/options used.
6. Add a minimal development setup section and an `.env.example` containing names only, never secrets.
7. Boot the application in development and test mode and verify production configuration can load with dummy non-secret environment values.

## Required verification

- Run `bundle check` and the default Rails test suite.
- Run `bin/rails db:prepare` against PostgreSQL.
- Run `RAILS_ENV=production bin/rails runner 'puts Rails.version'` with safe dummy configuration.
- Run `bin/rails assets:precompile` or the current equivalent.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Review the baseline report and verify current supported/security-patched Ruby and Rails versions before pinning. Start from the documented 2026-09-04 baseline only when compatibility and advisories still permit it.
- [ ] Create or merge the Rails application into the repository root without overwriting `docs/`, `prompts/`, `tracking/`, `schemas/`, `config_blueprints/`, `AGENTS.md`, or the READMEs.
- [ ] Configure PostgreSQL as the only database technology and retain Hotwire/Turbo/Stimulus, ERB, Tailwind, Minitest, Active Job, Active Storage and the Rails Solid defaults.
- [ ] Explicitly exclude Devise, OmniAuth, Doorkeeper, Sidekiq, Redis, Elasticsearch and Kubernetes-related dependencies.
- [ ] Pin Ruby, Rails, Bundler and relevant runtime versions through repository-standard files; commit the lockfile and document the exact command/options used.
- [ ] Add a minimal development setup section and an `.env.example` containing names only, never secrets.
- [ ] Boot the application in development and test mode and verify production configuration can load with dummy non-secret environment values.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not replace PostgreSQL with SQLite for any environment.
- Do not weaken dependency versions merely to make an old local runtime work.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 001 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 001 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 001
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
