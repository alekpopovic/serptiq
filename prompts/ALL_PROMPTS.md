# SearchOps Codex Prompt Book

This file mirrors the 120 separate prompt files. The separate files and tracker catalog are authoritative.

---
id: '000'
title: Repository reconnaissance and baseline snapshot
phase: 00 Governance and bootstrap
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on: []
status: pending
---

# Prompt 000 — Repository reconnaissance and baseline snapshot

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `none`
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
ruby tracking/scripts/prompt_tracker.rb start 000
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

Inspect the repository exactly as it exists, determine whether it is empty, partially initialized, or already contains application code, and establish a factual baseline before changing anything. Preserve this blueprint and make later prompts safe to execute against the observed state.

## Required references

- `README.md`
- `AGENTS.md`
- `docs/02_ARCHITECTURE.md`
- `docs/11_ROADMAP_AND_DEFINITION_OF_DONE.md`

## Required work

1. Read `AGENTS.md`, the top-level READMEs, all architecture ADRs, `tracking/state.json`, and this prompt before touching files.
2. Inventory tracked and untracked files, Git status, branches/remotes, runtime/version files, dependency manifests, containers, CI configuration, databases, tests, and any existing Rails application.
3. Record available local tool versions for Ruby, Bundler, Rails, PostgreSQL client, Node, npm, Chromium/Chrome, Docker, and Git. Mark unavailable tools rather than installing them silently.
4. Check for committed secrets, credentials, private keys, generated binaries, and oversized artifacts using safe local inspection; do not print secret values.
5. Create `docs/implementation/000_BASELINE.md` with repository facts, compatibility risks, missing prerequisites, and a proposed initialization path that preserves all blueprint files.
6. Update only documentation/tracker support files required for this baseline. Do not initialize Rails or introduce dependencies in this prompt.

## Required verification

- `git status --short --branch` and record the factual outcome.
- Run the tracker validation command.
- Verify `docs/implementation/000_BASELINE.md` contains no secret values and distinguishes facts from assumptions.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Read `AGENTS.md`, the top-level READMEs, all architecture ADRs, `tracking/state.json`, and this prompt before touching files.
- [ ] Inventory tracked and untracked files, Git status, branches/remotes, runtime/version files, dependency manifests, containers, CI configuration, databases, tests, and any existing Rails application.
- [ ] Record available local tool versions for Ruby, Bundler, Rails, PostgreSQL client, Node, npm, Chromium/Chrome, Docker, and Git. Mark unavailable tools rather than installing them silently.
- [ ] Check for committed secrets, credentials, private keys, generated binaries, and oversized artifacts using safe local inspection; do not print secret values.
- [ ] Create `docs/implementation/000_BASELINE.md` with repository facts, compatibility risks, missing prerequisites, and a proposed initialization path that preserves all blueprint files.
- [ ] Update only documentation/tracker support files required for this baseline. Do not initialize Rails or introduce dependencies in this prompt.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not delete or overwrite user work.
- Do not install packages or create the Rails application yet.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 000 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 000 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 000
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



---

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



---

---
id: '002'
title: Establish repository conventions and module boundaries
phase: 00 Governance and bootstrap
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '001'
status: pending
---

# Prompt 002 — Establish repository conventions and module boundaries

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `001`
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
ruby tracking/scripts/prompt_tracker.rb start 002
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

Turn the initialized repository into an enforceable modular-monolith workspace with clear naming, ownership, dependency and file-layout conventions before domain features accumulate.

## Required references

- `AGENTS.md`
- `docs/02_ARCHITECTURE.md`
- `docs/adr/0001_modular_rails_monolith.md`

## Required work

1. Create a documented module layout for Identity, Tenancy, Authorization, Billing, Entitlements, Usage, Projects, Properties, Crawling, Auditing, Findings, Issues, AppDiscovery, Integrations, Releases, Reporting, Notifications and Administration.
2. Choose a Rails-compatible boundary mechanism that does not introduce service deployment boundaries; use namespaces, explicit public APIs and automated dependency checks.
3. Create `docs/implementation/MODULE_BOUNDARIES.md` with allowed dependencies, prohibited cross-module access and a process for approved exceptions.
4. Add a small architecture test/lint that catches at least forbidden direct references between representative modules and can expand as code is added.
5. Define shared locations for cross-cutting primitives such as IDs, money, clocks, encryption, idempotency and domain errors without turning `lib/` into an unowned dumping ground.
6. Document naming rules for commands/operations, queries/read models, adapters, jobs, policies and events.
7. Update `AGENTS.md` only where the implementation reveals a necessary clarification; preserve all existing invariants.

## Required verification

- Run the architecture boundary check.
- Run the Rails test suite.
- Demonstrate one intentionally prohibited reference is caught in a temporary test or fixture, then remove it.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a documented module layout for Identity, Tenancy, Authorization, Billing, Entitlements, Usage, Projects, Properties, Crawling, Auditing, Findings, Issues, AppDiscovery, Integrations, Releases, Reporting, Notifications and Administration.
- [ ] Choose a Rails-compatible boundary mechanism that does not introduce service deployment boundaries; use namespaces, explicit public APIs and automated dependency checks.
- [ ] Create `docs/implementation/MODULE_BOUNDARIES.md` with allowed dependencies, prohibited cross-module access and a process for approved exceptions.
- [ ] Add a small architecture test/lint that catches at least forbidden direct references between representative modules and can expand as code is added.
- [ ] Define shared locations for cross-cutting primitives such as IDs, money, clocks, encryption, idempotency and domain errors without turning `lib/` into an unowned dumping ground.
- [ ] Document naming rules for commands/operations, queries/read models, adapters, jobs, policies and events.
- [ ] Update `AGENTS.md` only where the implementation reveals a necessary clarification; preserve all existing invariants.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not introduce networked microservices.
- Do not create empty abstraction layers without an owned module and documented purpose.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 002 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 002 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 002
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



---

---
id: '003'
title: Define environment, configuration and secrets contract
phase: 00 Governance and bootstrap
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '002'
status: pending
---

# Prompt 003 — Define environment, configuration and secrets contract

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `002`
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
ruby tracking/scripts/prompt_tracker.rb start 003
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

Create a typed, fail-fast configuration layer that distinguishes public settings from secrets, supports development/test/staging/production, and prevents accidental credential disclosure.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Inventory all anticipated configuration categories: application URLs, database roles, object storage, OAuth providers, billing, encryption, crawler limits, browser limits, provider integrations, email, Slack, observability and deployment metadata.
2. Implement a small configuration interface that validates required keys by environment and converts bounded integers, booleans, durations, URL origins and enums safely.
3. Use Rails credentials/runtime secret injection for secrets and ordinary environment/config files for non-secret settings; document precedence.
4. Add secret-redaction filters for parameter, header, URL query and structured-event fields including OAuth codes/tokens, API keys, webhook signatures and page credentials.
5. Create `.env.example`/configuration examples with placeholders and safe local defaults. Never include usable credentials.
6. Make production boot fail with a clear message when critical secrets or unsafe origins are missing; keep test configuration deterministic.
7. Document key rotation/versioning expectations for encrypted database attributes and webhook/API signing secrets.

## Required verification

- Add unit tests for parsing, required values, invalid URLs, invalid bounds and redaction.
- Verify production boot rejects missing critical settings.
- Search the repository for representative placeholder secret patterns and ensure no real secret is present.
- Run the full test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Inventory all anticipated configuration categories: application URLs, database roles, object storage, OAuth providers, billing, encryption, crawler limits, browser limits, provider integrations, email, Slack, observability and deployment metadata.
- [ ] Implement a small configuration interface that validates required keys by environment and converts bounded integers, booleans, durations, URL origins and enums safely.
- [ ] Use Rails credentials/runtime secret injection for secrets and ordinary environment/config files for non-secret settings; document precedence.
- [ ] Add secret-redaction filters for parameter, header, URL query and structured-event fields including OAuth codes/tokens, API keys, webhook signatures and page credentials.
- [ ] Create `.env.example`/configuration examples with placeholders and safe local defaults. Never include usable credentials.
- [ ] Make production boot fail with a clear message when critical secrets or unsafe origins are missing; keep test configuration deterministic.
- [ ] Document key rotation/versioning expectations for encrypted database attributes and webhook/API signing secrets.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never log secret values in validation errors.
- Do not require real third-party credentials to run tests.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 003 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 003 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 003
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



---

---
id: '004'
title: Integrate and verify the prompt execution tracker
phase: 00 Governance and bootstrap
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '003'
status: pending
---

# Prompt 004 — Integrate and verify the prompt execution tracker

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `003`
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
ruby tracking/scripts/prompt_tracker.rb start 004
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

Make the included prompt tracker a dependable repository workflow: validate catalog/state consistency, document recovery, and add non-destructive checks to CI without changing prompt statuses incorrectly.

## Required references

- `tracking/README.md`
- `schemas/prompt_result.schema.json`
- `AGENTS.md`

## Required work

1. Review `tracking/README.md`, the CSV catalog, initial state, result schema and Ruby CLI implementation included in this blueprint.
2. Run all read-only tracker commands and validate IDs, prompt files, dependencies, cycles, statuses and result-file consistency.
3. Add automated tests for the tracker in an isolated temporary directory, covering next/start/complete/block/reset, dependency denial, concurrent/current prompt denial, atomic state writes and invalid catalog input.
4. Add a CI check that runs tracker validation but never starts/completes prompts.
5. Document how to recover from an interrupted prompt, resolve a block, repair a corrupt state from Git and record an honest failed test.
6. Ensure tracker output is useful to both humans and Codex and never marks this prompt complete automatically.

## Required verification

- Run the tracker test suite.
- Run `ruby tracking/scripts/prompt_tracker.rb validate`.
- Run `ruby tracking/scripts/prompt_tracker.rb status` and verify no unrelated prompt status changed.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Review `tracking/README.md`, the CSV catalog, initial state, result schema and Ruby CLI implementation included in this blueprint.
- [ ] Run all read-only tracker commands and validate IDs, prompt files, dependencies, cycles, statuses and result-file consistency.
- [ ] Add automated tests for the tracker in an isolated temporary directory, covering next/start/complete/block/reset, dependency denial, concurrent/current prompt denial, atomic state writes and invalid catalog input.
- [ ] Add a CI check that runs tracker validation but never starts/completes prompts.
- [ ] Document how to recover from an interrupted prompt, resolve a block, repair a corrupt state from Git and record an honest failed test.
- [ ] Ensure tracker output is useful to both humans and Codex and never marks this prompt complete automatically.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Tracker tests must operate on a copied temporary state.
- Do not rewrite execution history to hide earlier entries.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 004 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 004 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 004
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



---

---
id: '005'
title: Finalize ADR index and architecture guardrails
phase: 00 Governance and bootstrap
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '004'
status: pending
---

# Prompt 005 — Finalize ADR index and architecture guardrails

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `004`
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
ruby tracking/scripts/prompt_tracker.rb start 005
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

Create a navigable architecture decision index and make the accepted foundational decisions visible in pull requests, code review and future prompt execution.

## Required references

- `docs/adr`
- `docs/02_ARCHITECTURE.md`
- `AGENTS.md`

## Required work

1. Review ADRs 0001–0010 against the initialized repository and update facts that changed during prompts 001–004 without silently changing the intent.
2. Create `docs/adr/README.md` containing status definitions, decision lifecycle, supersession rules, owner/review fields and an indexed summary of every ADR.
3. Add an ADR template with Context, Decision, Alternatives, Security/Privacy, Operations, Consequences and Revisit Triggers sections.
4. Create a lightweight pull-request checklist that asks whether tenancy, permissions, entitlements, quotas, migrations, provider contracts, security boundaries and ADRs were affected.
5. Add repository links from the main README and implementation docs.
6. Record any unresolved architecture discrepancy in `tracking/DECISIONS.md` or `tracking/BLOCKERS.md` rather than guessing.

## Required verification

- Check every ADR link from the index resolves.
- Run markdown/link checks available in the repository.
- Run tracker validation and the existing test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Review ADRs 0001–0010 against the initialized repository and update facts that changed during prompts 001–004 without silently changing the intent.
- [ ] Create `docs/adr/README.md` containing status definitions, decision lifecycle, supersession rules, owner/review fields and an indexed summary of every ADR.
- [ ] Add an ADR template with Context, Decision, Alternatives, Security/Privacy, Operations, Consequences and Revisit Triggers sections.
- [ ] Create a lightweight pull-request checklist that asks whether tenancy, permissions, entitlements, quotas, migrations, provider contracts, security boundaries and ADRs were affected.
- [ ] Add repository links from the main README and implementation docs.
- [ ] Record any unresolved architecture discrepancy in `tracking/DECISIONS.md` or `tracking/BLOCKERS.md` rather than guessing.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not mark an ADR superseded without a replacement decision.
- Do not turn preferences into mandatory rules without rationale.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 005 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 005 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 005
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



---

---
id: '006'
title: Configure PostgreSQL databases and required extensions
phase: 01 Rails and operational foundation
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '005'
status: pending
---

# Prompt 006 — Configure PostgreSQL databases and required extensions

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `005`
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
ruby tracking/scripts/prompt_tracker.rb start 006
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

Configure production-grade PostgreSQL usage for primary, queue, cache and cable workloads, with safe local defaults, constraints and connection behavior.

## Required references

- `docs/02_ARCHITECTURE.md`
- `docs/03_ERD.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/adr/0002_postgresql_and_solid_stack.md`

## Required work

1. Define `database.yml`/environment configuration for primary, queue, cache and cable databases using PostgreSQL only, supporting colocation locally and separate URLs in production.
2. Enable only justified extensions, such as `pgcrypto` for UUID generation, through reversible migrations.
3. Establish UUID primary-key policy for tenant/external aggregate roots and bigint policy for high-volume internal crawl rows; document exceptions.
4. Configure pool sizes from per-process environment values and prevent aggregate pool counts from exceeding managed database capacity.
5. Set safe application names, timeouts and advisory-lock behavior where supported.
6. Add database tasks/setup documentation that works from a clean machine and CI.
7. Create a database health query used by readiness with a strict timeout rather than a broad expensive check.

## Required verification

- Create all configured databases and load schema from zero.
- Run tests against PostgreSQL, not SQLite.
- Verify queue/cache/cable connections can initialize.
- Test invalid/missing database configuration fails clearly.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define `database.yml`/environment configuration for primary, queue, cache and cable databases using PostgreSQL only, supporting colocation locally and separate URLs in production.
- [ ] Enable only justified extensions, such as `pgcrypto` for UUID generation, through reversible migrations.
- [ ] Establish UUID primary-key policy for tenant/external aggregate roots and bigint policy for high-volume internal crawl rows; document exceptions.
- [ ] Configure pool sizes from per-process environment values and prevent aggregate pool counts from exceeding managed database capacity.
- [ ] Set safe application names, timeouts and advisory-lock behavior where supported.
- [ ] Add database tasks/setup documentation that works from a clean machine and CI.
- [ ] Create a database health query used by readiness with a strict timeout rather than a broad expensive check.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not enable extensions without a documented need.
- Do not commit environment-specific credentials.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 006 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 006 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 006
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



---

---
id: '007'
title: Configure Solid Queue, Solid Cache and Solid Cable topology
phase: 01 Rails and operational foundation
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '006'
status: pending
---

# Prompt 007 — Configure Solid Queue, Solid Cache and Solid Cable topology

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `006`
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
ruby tracking/scripts/prompt_tracker.rb start 007
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

Install/configure the Rails Solid components with explicit process roles, queue priorities, recurring-task ownership and operational bounds.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/adr/0002_postgresql_and_solid_stack.md`

## Required work

1. Complete Solid Queue, Solid Cache and Solid Cable database schemas/configuration using the database topology from prompt 006.
2. Define named queues for default, mail, integrations, billing, crawl, render, analysis, reports and maintenance with documented priorities/concurrency.
3. Configure worker process definitions so browser jobs can never run in the web/default worker by accident.
4. Set retry/discard defaults by error taxonomy; domain jobs must override intentionally.
5. Configure recurring-task files for later tasks without adding placeholder jobs that fail.
6. Bound Solid Cache size/expiry and document that it is disposable.
7. Configure Solid Cable retention/polling appropriate for Turbo updates without using it as durable domain messaging.
8. Add operational documentation for queue latency, failed jobs, graceful shutdown and stale process cleanup.

## Required verification

- Enqueue and perform a smoke job through real Solid Queue/PostgreSQL.
- Verify queue routing for each representative job class.
- Verify Rails boots when cache/cable databases are empty and migrations are applied.
- Run the test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Complete Solid Queue, Solid Cache and Solid Cable database schemas/configuration using the database topology from prompt 006.
- [ ] Define named queues for default, mail, integrations, billing, crawl, render, analysis, reports and maintenance with documented priorities/concurrency.
- [ ] Configure worker process definitions so browser jobs can never run in the web/default worker by accident.
- [ ] Set retry/discard defaults by error taxonomy; domain jobs must override intentionally.
- [ ] Configure recurring-task files for later tasks without adding placeholder jobs that fail.
- [ ] Bound Solid Cache size/expiry and document that it is disposable.
- [ ] Configure Solid Cable retention/polling appropriate for Turbo updates without using it as durable domain messaging.
- [ ] Add operational documentation for queue latency, failed jobs, graceful shutdown and stale process cleanup.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use Redis or Sidekiq.
- Do not use Action Cable/Solid Cable as a durable event bus.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 007 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 007 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 007
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



---

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



---

---
id: 009
title: Add linting, static analysis and dependency security checks
phase: 01 Rails and operational foundation
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- 008
status: pending
---

# Prompt 009 — Add linting, static analysis and dependency security checks

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `008`
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
ruby tracking/scripts/prompt_tracker.rb start 009
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

Establish fast, reproducible quality checks for Ruby, ERB, JavaScript/importmap assets, configuration and dependencies.

## Required references

- `docs/09_TEST_STRATEGY.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Configure RuboCop using a documented style baseline and minimal justified exclusions.
2. Configure Brakeman and a dependency vulnerability audit compatible with the chosen Rails/Bundler versions.
3. Add ERB/template linting and YAML/JSON validation; include custom validation for config blueprints where practical.
4. Add a repository script such as `bin/quality` that runs deterministic local checks in a sensible order.
5. Keep generated/vendor directories out of scans without excluding application code.
6. Document how advisories are triaged, upgraded and temporarily waived with owner/expiry.
7. Fix existing findings instead of adding blanket exclusions.

## Required verification

- Run all configured linters with zero unreviewed errors.
- Run Brakeman and dependency audit.
- Validate all YAML and JSON files in the blueprint.
- Run the Rails test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Configure RuboCop using a documented style baseline and minimal justified exclusions.
- [ ] Configure Brakeman and a dependency vulnerability audit compatible with the chosen Rails/Bundler versions.
- [ ] Add ERB/template linting and YAML/JSON validation; include custom validation for config blueprints where practical.
- [ ] Add a repository script such as `bin/quality` that runs deterministic local checks in a sensible order.
- [ ] Keep generated/vendor directories out of scans without excluding application code.
- [ ] Document how advisories are triaged, upgraded and temporarily waived with owner/expiry.
- [ ] Fix existing findings instead of adding blanket exclusions.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No `--force` or blanket ignore of security findings.
- Do not auto-format migrations in ways that obscure generated intent.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 009 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 009 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 009
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



---

---
id: '010'
title: Establish the Minitest and system-test foundation
phase: 01 Rails and operational foundation
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 009
status: pending
---

# Prompt 010 — Establish the Minitest and system-test foundation

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `009`
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
ruby tracking/scripts/prompt_tracker.rb start 010
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

Build reusable test infrastructure for domain decisions, requests, jobs, provider contracts, tenant isolation and critical browser journeys.

## Required references

- `docs/09_TEST_STRATEGY.md`
- `AGENTS.md`

## Required work

1. Organize the test tree according to `docs/09_TEST_STRATEGY.md` while retaining Rails conventions.
2. Add deterministic helpers for clocks, IDs, encrypted attributes, signed requests, current tenant and provider fakes.
3. Create a tenant-isolation shared test helper that can be applied to every tenant-owned controller/operation.
4. Configure system tests with the chosen browser driver and failure artifact capture.
5. Add helpers for asserting enqueued jobs, idempotent retries, audit events, permission decisions and usage events.
6. Create a local malicious HTTP fixture service/test support boundary for later crawler security cases without permitting external network access.
7. Document fast/default/full/security test commands and random-order reproduction.

## Required verification

- Run a representative unit, request, job, system and contract test.
- Prove randomized seed reproduction works.
- Verify system-test screenshots/logs are kept only on failure and excluded from Git.
- Run the full current test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Organize the test tree according to `docs/09_TEST_STRATEGY.md` while retaining Rails conventions.
- [ ] Add deterministic helpers for clocks, IDs, encrypted attributes, signed requests, current tenant and provider fakes.
- [ ] Create a tenant-isolation shared test helper that can be applied to every tenant-owned controller/operation.
- [ ] Configure system tests with the chosen browser driver and failure artifact capture.
- [ ] Add helpers for asserting enqueued jobs, idempotent retries, audit events, permission decisions and usage events.
- [ ] Create a local malicious HTTP fixture service/test support boundary for later crawler security cases without permitting external network access.
- [ ] Document fast/default/full/security test commands and random-order reproduction.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Tests must not contact real providers or arbitrary internet hosts.
- Do not hide flaky tests with retries.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 010 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 010 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 010
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



---

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



---

---
id: '012'
title: Implement structured events and error taxonomy
phase: 01 Rails and operational foundation
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '011'
status: pending
---

# Prompt 012 — Implement structured events and error taxonomy

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `011`
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
ruby tracking/scripts/prompt_tracker.rb start 012
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

Create a consistent observability foundation that records useful operational context while protecting tenant data and credentials.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Define stable application error categories for validation, authentication, authorization, entitlement, quota, conflict, external provider, transient infrastructure, unsafe destination and internal faults.
2. Implement structured event emission with request/job/release correlation and optional safe organization/project/scan identifiers.
3. Add parameter/header/query/payload redaction and tests for OAuth, billing, API key and crawler-sensitive data.
4. Create request and job middleware/hooks that attach correlation context and clear it reliably.
5. Map expected domain errors to safe HTTP responses and user-facing messages without leaking internals.
6. Record exception causes for operators while presenting stable public error codes.
7. Document event naming/versioning, cardinality limits and prohibited fields.

## Required verification

- Test redaction against representative nested payloads and URLs.
- Test request and job context is cleared between executions.
- Test expected domain errors and unexpected faults produce correct status/public code.
- Run logging tests and full suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define stable application error categories for validation, authentication, authorization, entitlement, quota, conflict, external provider, transient infrastructure, unsafe destination and internal faults.
- [ ] Implement structured event emission with request/job/release correlation and optional safe organization/project/scan identifiers.
- [ ] Add parameter/header/query/payload redaction and tests for OAuth, billing, API key and crawler-sensitive data.
- [ ] Create request and job middleware/hooks that attach correlation context and clear it reliably.
- [ ] Map expected domain errors to safe HTTP responses and user-facing messages without leaking internals.
- [ ] Record exception causes for operators while presenting stable public error codes.
- [ ] Document event naming/versioning, cardinality limits and prohibited fields.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not log raw page bodies by default.
- Do not use customer-controlled strings as metric names or unbounded labels.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 012 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 012 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 012
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



---

---
id: '013'
title: Implement health, readiness and version endpoints
phase: 01 Rails and operational foundation
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '012'
status: pending
---

# Prompt 013 — Implement health, readiness and version endpoints

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `012`
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
ruby tracking/scripts/prompt_tracker.rb start 013
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

Expose minimal operational endpoints with correct liveness/readiness semantics and release provenance.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Implement `/up` as an inexpensive process-liveness endpoint that does not depend on third-party providers.
2. Implement `/ready` with tightly bounded checks for dependencies required by the current process role, including PostgreSQL, while avoiding cascading load.
3. Implement `/version` with release ID/commit, build time, environment and safe runtime versions; omit secrets and host internals.
4. Return machine-readable JSON and appropriate status/cache headers, with optional simple HTML only where useful.
5. Make worker heartbeat/readiness information available through internal/admin mechanisms rather than exposing sensitive queue data publicly.
6. Add deployment documentation describing how Kamal/load balancers use each endpoint.

## Required verification

- Request-test success and dependency-failure behavior.
- Verify third-party outages do not make `/up` fail.
- Verify `/version` contains no secrets and is cache-safe.
- Boot the production image and probe all endpoints.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement `/up` as an inexpensive process-liveness endpoint that does not depend on third-party providers.
- [ ] Implement `/ready` with tightly bounded checks for dependencies required by the current process role, including PostgreSQL, while avoiding cascading load.
- [ ] Implement `/version` with release ID/commit, build time, environment and safe runtime versions; omit secrets and host internals.
- [ ] Return machine-readable JSON and appropriate status/cache headers, with optional simple HTML only where useful.
- [ ] Make worker heartbeat/readiness information available through internal/admin mechanisms rather than exposing sensitive queue data publicly.
- [ ] Add deployment documentation describing how Kamal/load balancers use each endpoint.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not expose database names, credentials, internal IPs or exception traces.
- Do not turn readiness into a broad provider health dashboard.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 013 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 013 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 013
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



---

---
id: '014'
title: Create native authentication and session foundations
phase: 02 Identity and sessions
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '013'
status: pending
---

# Prompt 014 — Create native authentication and session foundations

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `013`
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
ruby tracking/scripts/prompt_tracker.rb start 014
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

Establish the application-owned authentication boundary, current-user/session lifecycle and login-required controller behavior before provider-specific code.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0003_native_social_authentication.md`

## Required work

1. Define the Identity module public API and domain errors.
2. Implement opaque server-side sessions stored in PostgreSQL-backed application state with hashed tokens, expiry, revocation, last-seen and safe metadata.
3. Use a secure HttpOnly cookie with production Secure/SameSite settings and environment-aware domain/path.
4. Establish `Current.user` and `Current.session` from the session token and clear them reliably.
5. Add login-required and anonymous-only controller concerns plus safe return-path handling limited to local allowlisted paths.
6. Rotate/reissue the session token on authentication and future privilege-sensitive events.
7. Implement logout as server-side revocation plus cookie deletion.
8. Emit audit/structured events without recording raw session tokens.

## Required verification

- Request tests for anonymous/authenticated access, expiry, revocation and logout.
- Session fixation/rotation tests.
- Safe-return-path tests including absolute/external/malformed URLs.
- Cross-process session lookup test against PostgreSQL.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define the Identity module public API and domain errors.
- [ ] Implement opaque server-side sessions stored in PostgreSQL-backed application state with hashed tokens, expiry, revocation, last-seen and safe metadata.
- [ ] Use a secure HttpOnly cookie with production Secure/SameSite settings and environment-aware domain/path.
- [ ] Establish `Current.user` and `Current.session` from the session token and clear them reliably.
- [ ] Add login-required and anonymous-only controller concerns plus safe return-path handling limited to local allowlisted paths.
- [ ] Rotate/reissue the session token on authentication and future privilege-sensitive events.
- [ ] Implement logout as server-side revocation plus cookie deletion.
- [ ] Emit audit/structured events without recording raw session tokens.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not add passwords in the MVP.
- Do not store raw bearer/session tokens.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 014 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 014 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 014
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



---

---
id: '015'
title: Model users, identities, sessions and OAuth transactions
phase: 02 Identity and sessions
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '014'
status: pending
---

# Prompt 015 — Model users, identities, sessions and OAuth transactions

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `014`
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
ruby tracking/scripts/prompt_tracker.rb start 015
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

Create the durable identity data model with database-enforced uniqueness, one-time OAuth transactions and safe account-linking foundations.

## Required references

- `docs/03_ERD.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create `users`, `identities`, `sessions` and `oauth_transactions` according to the ERD and module boundaries.
2. Use stable provider subject IDs as identity keys; never use mutable GitHub login or email as the provider primary key.
3. Store normalized email and verification metadata while allowing provider identities without a usable email according to policy.
4. Hash OAuth state, PKCE verifier references and session tokens; encrypt provider tokens only if a later flow genuinely stores them.
5. Add one-time consumption, expiry and attempt metadata to OAuth transactions.
6. Add foreign keys, checks and unique indexes for provider/subject and active token digests.
7. Create fixtures/factories/helpers for verified, unverified and colliding identities.
8. Document deletion/anonymization behavior for identity records.

## Required verification

- Model and database constraint tests for duplicate subjects/tokens.
- Tests for transaction expiry and one-time consumption under concurrency.
- Encryption/redaction tests.
- Run migrations from zero and rollback where safe.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create `users`, `identities`, `sessions` and `oauth_transactions` according to the ERD and module boundaries.
- [ ] Use stable provider subject IDs as identity keys; never use mutable GitHub login or email as the provider primary key.
- [ ] Store normalized email and verification metadata while allowing provider identities without a usable email according to policy.
- [ ] Hash OAuth state, PKCE verifier references and session tokens; encrypt provider tokens only if a later flow genuinely stores them.
- [ ] Add one-time consumption, expiry and attempt metadata to OAuth transactions.
- [ ] Add foreign keys, checks and unique indexes for provider/subject and active token digests.
- [ ] Create fixtures/factories/helpers for verified, unverified and colliding identities.
- [ ] Document deletion/anonymization behavior for identity records.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not automatically merge users by email.
- Do not store access/refresh tokens unless a provider flow requires ongoing API access.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 015 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 015 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 015
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



---

---
id: '016'
title: Define the OAuth/OIDC provider adapter architecture
phase: 02 Identity and sessions
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '015'
status: pending
---

# Prompt 016 — Define the OAuth/OIDC provider adapter architecture

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `015`
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
ruby tracking/scripts/prompt_tracker.rb start 016
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

Create a small provider-neutral sign-in contract with deterministic fakes and strict separation between protocol handling and local account decisions.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/adr/0003_native_social_authentication.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Define adapter methods/value objects for authorization request, callback exchange, normalized identity, provider error and optional OIDC token claims.
2. Separate Google OIDC requirements from GitHub OAuth behavior without forcing a false common denominator.
3. Create provider registry/allowlist and configuration validation for exact issuer, authorization/token/JWKS/user endpoints and redirect URI.
4. Implement HTTP client timeouts, response-size bounds, JSON/content-type validation, retry policy for safe discovery/JWKS requests and structured error categories.
5. Create fake adapters and shared contract tests for success, denial, malformed response, timeout, rate limit and revoked credentials.
6. Make account resolution/linking an application domain operation, not an adapter side effect.
7. Document provider addition checklist.

## Required verification

- Run shared adapter contract tests against Google/GitHub fakes.
- Test unknown providers and unsafe/unconfigured endpoint rejection.
- Test secret/token redaction on every error path.
- Run full suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define adapter methods/value objects for authorization request, callback exchange, normalized identity, provider error and optional OIDC token claims.
- [ ] Separate Google OIDC requirements from GitHub OAuth behavior without forcing a false common denominator.
- [ ] Create provider registry/allowlist and configuration validation for exact issuer, authorization/token/JWKS/user endpoints and redirect URI.
- [ ] Implement HTTP client timeouts, response-size bounds, JSON/content-type validation, retry policy for safe discovery/JWKS requests and structured error categories.
- [ ] Create fake adapters and shared contract tests for success, denial, malformed response, timeout, rate limit and revoked credentials.
- [ ] Make account resolution/linking an application domain operation, not an adapter side effect.
- [ ] Document provider addition checklist.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not dynamically accept issuer/endpoints from callback input.
- Do not let provider payloads create memberships or organizations.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 016 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 016 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 016
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



---

---
id: '017'
title: Implement Google OIDC authorization start with PKCE, state and nonce
phase: 02 Identity and sessions
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '016'
status: pending
---

# Prompt 017 — Implement Google OIDC authorization start with PKCE, state and nonce

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `016`
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
ruby tracking/scripts/prompt_tracker.rb start 017
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

Implement the Google sign-in initiation path with one-time transaction state, PKCE and nonce, exact redirect behavior and abuse controls.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Generate cryptographically random state, nonce and PKCE verifier/challenge for each attempt.
2. Persist only protected/hashed transaction material needed for callback validation, with short expiry and one-time semantics.
3. Build the authorization request from allowlisted Google metadata/configuration with exact client ID, redirect URI, response type, scope and PKCE parameters.
4. Store a validated local return path and optional explicit linking intent bound to the authenticated session.
5. Add rate limits by safe dimensions and cap outstanding transactions without enabling account enumeration.
6. Set appropriate no-store/referrer/security headers on login initiation/callback responses.
7. Emit a correlation event without state, nonce, verifier or authorization URL secrets.

## Required verification

- Request tests assert every required authorization parameter.
- Entropy/uniqueness and expiry tests using deterministic injection where needed.
- Tests for external `return_to`, excess attempts and transaction cleanup.
- Verify secrets do not appear in logs or rendered pages.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Generate cryptographically random state, nonce and PKCE verifier/challenge for each attempt.
- [ ] Persist only protected/hashed transaction material needed for callback validation, with short expiry and one-time semantics.
- [ ] Build the authorization request from allowlisted Google metadata/configuration with exact client ID, redirect URI, response type, scope and PKCE parameters.
- [ ] Store a validated local return path and optional explicit linking intent bound to the authenticated session.
- [ ] Add rate limits by safe dimensions and cap outstanding transactions without enabling account enumeration.
- [ ] Set appropriate no-store/referrer/security headers on login initiation/callback responses.
- [ ] Emit a correlation event without state, nonce, verifier or authorization URL secrets.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not expose the PKCE verifier to the browser after initiation.
- Do not accept a caller-supplied redirect URI.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 017 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 017 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 017
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



---

---
id: 018
title: Implement Google OIDC callback and token validation
phase: 02 Identity and sessions
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '017'
status: pending
---

# Prompt 018 — Implement Google OIDC callback and token validation

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `017`
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
ruby tracking/scripts/prompt_tracker.rb start 018
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

Complete Google sign-in with exact callback validation, secure code exchange, OIDC claim verification, replay protection and explicit local account resolution.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Validate provider error responses and require a matching unexpired unconsumed state transaction before code exchange.
2. Exchange the authorization code server-to-server using the stored PKCE verifier and exact configured redirect URI with tight timeouts/size limits.
3. Validate ID token signature using allowlisted issuer/JWKS, algorithm/key ID, issuer, audience/authorized party, expiry/not-before/issued-at and stored nonce.
4. Apply the documented verified-email policy and normalize a stable Google subject identity.
5. Consume the OAuth transaction atomically so callback replay cannot create a second session.
6. Resolve or create the local user/identity without email-based automatic merging; require explicit recent-auth linking for collisions.
7. Rotate the application session and redirect only to the stored safe local path.
8. Categorize and audit failures without leaking token contents.

## Required verification

- Contract/request tests for valid callback and every validation failure named above.
- Concurrency/replay test proving one code/state can produce at most one successful local transition.
- JWKS rotation/cache tests with bounded refresh behavior.
- Tests for email collision, unverified email and explicit link intent.
- Run Brakeman and full suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Validate provider error responses and require a matching unexpired unconsumed state transaction before code exchange.
- [ ] Exchange the authorization code server-to-server using the stored PKCE verifier and exact configured redirect URI with tight timeouts/size limits.
- [ ] Validate ID token signature using allowlisted issuer/JWKS, algorithm/key ID, issuer, audience/authorized party, expiry/not-before/issued-at and stored nonce.
- [ ] Apply the documented verified-email policy and normalize a stable Google subject identity.
- [ ] Consume the OAuth transaction atomically so callback replay cannot create a second session.
- [ ] Resolve or create the local user/identity without email-based automatic merging; require explicit recent-auth linking for collisions.
- [ ] Rotate the application session and redirect only to the stored safe local path.
- [ ] Categorize and audit failures without leaking token contents.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not decode and trust claims without cryptographic validation.
- Do not retry authorization-code exchange after an ambiguous successful provider response.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 018 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 018 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 018
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



---

---
id: 019
title: Implement the GitHub OAuth sign-in adapter
phase: 02 Identity and sessions
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 018
status: pending
---

# Prompt 019 — Implement the GitHub OAuth sign-in adapter

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `018`
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
ruby tracking/scripts/prompt_tracker.rb start 019
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

Add GitHub OAuth sign-in using the shared identity boundary while respecting GitHub-specific subject and email behavior.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Implement the GitHub authorization start with cryptographic state and PKCE where supported/configured by the current provider behavior; preserve exact callback URI.
2. Exchange the code server-to-server with strict HTTP bounds and parse the stable GitHub user ID as the provider subject.
3. Fetch verified primary email only when needed and authorized; handle absent/private/unverified email without using mutable login as identity.
4. Normalize provider profile fields conservatively and store only those needed for account display/audit.
5. Use the same explicit account linking/collision policy as Google.
6. Map provider denial, bad credentials, rate limits and malformed responses to stable errors.
7. Add fake/recorded sanitized fixtures and update login UI.

## Required verification

- Adapter/request tests for success, denial, absent email, unverified email and changed login.
- State replay and callback mismatch tests.
- Redaction tests for code/access token/provider response.
- System test signs in through the fake provider.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement the GitHub authorization start with cryptographic state and PKCE where supported/configured by the current provider behavior; preserve exact callback URI.
- [ ] Exchange the code server-to-server with strict HTTP bounds and parse the stable GitHub user ID as the provider subject.
- [ ] Fetch verified primary email only when needed and authorized; handle absent/private/unverified email without using mutable login as identity.
- [ ] Normalize provider profile fields conservatively and store only those needed for account display/audit.
- [ ] Use the same explicit account linking/collision policy as Google.
- [ ] Map provider denial, bad credentials, rate limits and malformed responses to stable errors.
- [ ] Add fake/recorded sanitized fixtures and update login UI.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use GitHub login name as the unique identity.
- Do not retain the access token after sign-in unless a separately consented GitHub integration later needs it.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 019 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 019 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 019
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



---

---
id: '020'
title: Implement identity linking and collision prevention
phase: 02 Identity and sessions
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 019
status: pending
---

# Prompt 020 — Implement identity linking and collision prevention

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `019`
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
ruby tracking/scripts/prompt_tracker.rb start 020
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

Allow a signed-in user to link or unlink social identities safely while preventing email-collision account takeover and lockout.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0003_native_social_authentication.md`

## Required work

1. Create explicit link initiation/callback flows bound to a recent authenticated session, intended provider and one-time OAuth transaction.
2. Require user confirmation before linking and never infer linking solely from equal email addresses.
3. Reject a provider identity already linked to another user with a privacy-safe error and audited event.
4. Allow unlinking only when the user retains another valid sign-in identity and recent authentication.
5. Rotate/revoke sessions according to the risk policy after linking/unlinking.
6. Create account security UI listing providers, linked date and last-use metadata without exposing provider tokens.
7. Add support-safe diagnostic identifiers that do not reveal another account.

## Required verification

- System tests for successful link/unlink and last-identity denial.
- Attack tests for CSRF, stale session, swapped provider, email collision and identity already owned.
- Concurrency test for simultaneous attempts to claim one provider subject.
- Audit-event assertions.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create explicit link initiation/callback flows bound to a recent authenticated session, intended provider and one-time OAuth transaction.
- [ ] Require user confirmation before linking and never infer linking solely from equal email addresses.
- [ ] Reject a provider identity already linked to another user with a privacy-safe error and audited event.
- [ ] Allow unlinking only when the user retains another valid sign-in identity and recent authentication.
- [ ] Rotate/revoke sessions according to the risk policy after linking/unlinking.
- [ ] Create account security UI listing providers, linked date and last-use metadata without exposing provider tokens.
- [ ] Add support-safe diagnostic identifiers that do not reveal another account.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No email-only merge path.
- Do not reveal whether a conflicting provider identity belongs to a named user.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 020 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 020 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 020
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



---

---
id: '021'
title: Harden session rotation, revocation and device management
phase: 02 Identity and sessions
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '020'
status: pending
---

# Prompt 021 — Harden session rotation, revocation and device management

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `020`
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
ruby tracking/scripts/prompt_tracker.rb start 021
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

Complete session security with device/session visibility, rotation and revocation behavior suitable for future organization privilege changes.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Implement session inventory showing safe approximate device/client, creation, last activity and current-session marker.
2. Allow users to revoke one other session or all other sessions, with recent authentication where policy requires.
3. Implement reusable hooks to rotate/revoke sessions after identity changes, ownership transfer, sensitive role changes and suspected compromise.
4. Bound idle and absolute expiry; update last-seen without excessive writes.
5. Protect session-management routes with CSRF, authorization and anti-enumeration behavior.
6. Create maintenance cleanup for expired/revoked sessions.
7. Add structured/audit events for creation, rotation and revocation without raw tokens.

## Required verification

- Request/system tests for session inventory and revocation.
- Tests for idle/absolute expiry and throttled last-seen updates.
- Concurrency tests for current-session rotation and revocation.
- Verify old tokens cannot be replayed.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement session inventory showing safe approximate device/client, creation, last activity and current-session marker.
- [ ] Allow users to revoke one other session or all other sessions, with recent authentication where policy requires.
- [ ] Implement reusable hooks to rotate/revoke sessions after identity changes, ownership transfer, sensitive role changes and suspected compromise.
- [ ] Bound idle and absolute expiry; update last-seen without excessive writes.
- [ ] Protect session-management routes with CSRF, authorization and anti-enumeration behavior.
- [ ] Create maintenance cleanup for expired/revoked sessions.
- [ ] Add structured/audit events for creation, rotation and revocation without raw tokens.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fingerprint users invasively.
- Do not display raw IP histories beyond documented privacy policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 021 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 021 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 021
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



---

---
id: '022'
title: Build authentication and first-run onboarding UI
phase: 02 Identity and sessions
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '021'
status: pending
---

# Prompt 022 — Build authentication and first-run onboarding UI

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `021`
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
ruby tracking/scripts/prompt_tracker.rb start 022
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

Create polished server-rendered login, callback-error and first-run account screens that explain social login and guide a new user toward organization creation.

## Required references

- `docs/01_PRD_V1.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Implement sign-in options for configured providers with unavailable-provider states.
2. Create safe, actionable error pages for denied consent, expired attempt, collision, provider outage and internal failure using stable public error codes.
3. Add account/profile basics sourced from local user data, not live provider calls.
4. Create first-run flow that distinguishes a user with no organization from an invited user and routes them appropriately.
5. Ensure all forms/navigation are accessible and work through Rails/Hotwire conventions.
6. Add privacy/security copy explaining linked providers and session control without overclaiming.

## Required verification

- System tests for new user, returning user, invited user and provider error.
- Keyboard/accessibility checks.
- Test no provider/token details are reflected into HTML.
- Run asset compilation and full suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement sign-in options for configured providers with unavailable-provider states.
- [ ] Create safe, actionable error pages for denied consent, expired attempt, collision, provider outage and internal failure using stable public error codes.
- [ ] Add account/profile basics sourced from local user data, not live provider calls.
- [ ] Create first-run flow that distinguishes a user with no organization from an invited user and routes them appropriately.
- [ ] Ensure all forms/navigation are accessible and work through Rails/Hotwire conventions.
- [ ] Add privacy/security copy explaining linked providers and session control without overclaiming.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not add password forms.
- Do not create an organization automatically when a valid invitation should be accepted first.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 022 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 022 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 022
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



---

---
id: '023'
title: Add authentication rate limits and security regression suite
phase: 02 Identity and sessions
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '022'
status: pending
---

# Prompt 023 — Add authentication rate limits and security regression suite

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `022`
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
ruby tracking/scripts/prompt_tracker.rb start 023
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

Protect authentication entry points against abuse and consolidate protocol/session attack tests into a required CI suite.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Add database/cache-backed rate policies for sign-in initiation, callback failure, session actions and sensitive account linking using privacy-safe keys.
2. Return appropriate generic responses and retry metadata without enabling provider/account enumeration.
3. Implement cleanup/expiry for counters and avoid permanent lockout.
4. Create `test/security/authentication_security_test.rb` or equivalent covering state/nonce/PKCE/replay/open redirect/session fixation/collision/redaction cases.
5. Add a CI security-test command and document how to investigate failures.
6. Add metrics for rate-limit decisions and categorized auth failures with bounded labels.
7. Review all identity code against the OAuth/OIDC ADR and source references.

## Required verification

- Run the dedicated authentication security suite.
- Load-test rate-limit atomicity at the boundary.
- Verify legitimate success resets/decays only as documented.
- Run Brakeman, dependency audit and full tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Add database/cache-backed rate policies for sign-in initiation, callback failure, session actions and sensitive account linking using privacy-safe keys.
- [ ] Return appropriate generic responses and retry metadata without enabling provider/account enumeration.
- [ ] Implement cleanup/expiry for counters and avoid permanent lockout.
- [ ] Create `test/security/authentication_security_test.rb` or equivalent covering state/nonce/PKCE/replay/open redirect/session fixation/collision/redaction cases.
- [ ] Add a CI security-test command and document how to investigate failures.
- [ ] Add metrics for rate-limit decisions and categorized auth failures with bounded labels.
- [ ] Review all identity code against the OAuth/OIDC ADR and source references.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not key limits solely by a user-controlled email.
- Do not return different collision/account-existence responses to anonymous callers.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 023 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 023 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 023
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



---

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



---

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



---

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



---

---
id: '027'
title: Implement teams and team memberships
phase: 03 Organizations, membership and RBAC
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '026'
status: pending
---

# Prompt 027 — Implement teams and team memberships

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `026`
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
ruby tracking/scripts/prompt_tracker.rb start 027
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

Add organization-scoped teams that can receive future scoped role assignments without crossing tenant boundaries.

## Required references

- `docs/03_ERD.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`

## Required work

1. Create teams and team memberships with organization-consistency constraints.
2. Implement create/rename/archive team and add/remove active organization members.
3. Prevent a membership from another organization being attached through IDs or race conditions.
4. Define behavior when a team is archived or a member is suspended/removed.
5. Provide team list/detail UI with pagination and member search bounded to current organization.
6. Emit audit events for team lifecycle and membership changes.
7. Prepare the authorization resolver interface to combine direct and team-derived grants without implementing role UI prematurely.

## Required verification

- Cross-tenant database/domain/request tests.
- Concurrent add/remove idempotency tests.
- Archive behavior tests.
- System tests for team management.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create teams and team memberships with organization-consistency constraints.
- [ ] Implement create/rename/archive team and add/remove active organization members.
- [ ] Prevent a membership from another organization being attached through IDs or race conditions.
- [ ] Define behavior when a team is archived or a member is suspended/removed.
- [ ] Provide team list/detail UI with pagination and member search bounded to current organization.
- [ ] Emit audit events for team lifecycle and membership changes.
- [ ] Prepare the authorization resolver interface to combine direct and team-derived grants without implementing role UI prematurely.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- A team cannot belong to multiple organizations.
- Archived team grants must not remain effective unless explicitly documented.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 027 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 027 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 027
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



---

---
id: 028
title: Implement secure organization invitations
phase: 03 Organizations, membership and RBAC
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '027'
status: pending
---

# Prompt 028 — Implement secure organization invitations

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `027`
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
ruby tracking/scripts/prompt_tracker.rb start 028
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

Create one-time, expiring invitations that bind an intended email/organization and support safe acceptance by social-login users.

## Required references

- `docs/03_ERD.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create invitations with hashed random token, normalized intended email, inviter, expiry, status and optional initial role assignment.
2. Generate/send invitation links without storing raw tokens and without leaking whether an email already has an account.
3. Require authentication on acceptance; enforce the documented verified-email match or an explicit safe alternative.
4. Consume invitations atomically and create/reactivate membership without duplicates.
5. Support revoke, resend-as-new-token and expiration; never reactivate a removed member silently without policy.
6. Handle users invited to multiple organizations and route first-run onboarding correctly.
7. Add rate limits and audit events for invite operations.
8. Create mail previews/fakes and accessible acceptance/error screens.

## Required verification

- Tests for valid, expired, revoked, replayed and wrong-email invitation.
- Concurrency test proving one token is accepted once.
- Cross-organization role/scope tampering tests.
- System test from invitation link through social login to membership.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create invitations with hashed random token, normalized intended email, inviter, expiry, status and optional initial role assignment.
- [ ] Generate/send invitation links without storing raw tokens and without leaking whether an email already has an account.
- [ ] Require authentication on acceptance; enforce the documented verified-email match or an explicit safe alternative.
- [ ] Consume invitations atomically and create/reactivate membership without duplicates.
- [ ] Support revoke, resend-as-new-token and expiration; never reactivate a removed member silently without policy.
- [ ] Handle users invited to multiple organizations and route first-run onboarding correctly.
- [ ] Add rate limits and audit events for invite operations.
- [ ] Create mail previews/fakes and accessible acceptance/error screens.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not store raw invitation tokens.
- Do not disclose account existence in invitation responses.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 028 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 028 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 028
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



---

---
id: 029
title: Seed permissions and immutable system roles
phase: 03 Organizations, membership and RBAC
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 028
status: pending
---

# Prompt 029 — Seed permissions and immutable system roles

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `028`
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
ruby tracking/scripts/prompt_tracker.rb start 029
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

Implement the 57-key permission catalog and immutable system role definitions from the blueprint as version-controlled, repeatable data.

## Required references

- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `config_blueprints/permissions.yml`
- `docs/03_ERD.md`

## Required work

1. Create permissions, roles and role-permission relationships with stable keys and organization/system ownership rules.
2. Load the catalog from `config_blueprints/permissions.yml` through an idempotent sync task that adds/updates metadata but never silently renames/removes in-use keys.
3. Implement the system roles Owner, Organization Admin, Billing Admin, SEO Lead, Developer, Content Editor, Analyst and Viewer with the documented grants.
4. Mark system-role grants immutable through application operations.
5. Define catalog validation for duplicate keys, unknown grants and permissions that lack descriptions/category/scope.
6. Record catalog revision/checksum for auditability.
7. Create an admin-readable permission matrix page or development report.

## Required verification

- Config schema/semantic validation tests.
- Idempotent sync test and removal/rename safety test.
- System-role immutability tests.
- Compare generated grants to `docs/04_RBAC_PERMISSION_MATRIX.md`.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create permissions, roles and role-permission relationships with stable keys and organization/system ownership rules.
- [ ] Load the catalog from `config_blueprints/permissions.yml` through an idempotent sync task that adds/updates metadata but never silently renames/removes in-use keys.
- [ ] Implement the system roles Owner, Organization Admin, Billing Admin, SEO Lead, Developer, Content Editor, Analyst and Viewer with the documented grants.
- [ ] Mark system-role grants immutable through application operations.
- [ ] Define catalog validation for duplicate keys, unknown grants and permissions that lack descriptions/category/scope.
- [ ] Record catalog revision/checksum for auditability.
- [ ] Create an admin-readable permission matrix page or development report.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never authorize by role name directly.
- Do not delete a permission merely because it disappeared from YAML.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 029 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 029 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 029
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



---

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



---

---
id: '031'
title: Implement the authorization decision service
phase: 03 Organizations, membership and RBAC
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '030'
status: pending
---

# Prompt 031 — Implement the authorization decision service

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `030`
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
ruby tracking/scripts/prompt_tracker.rb start 031
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

Create one explainable authorization engine that resolves active membership, effective scoped permissions and resource state without coupling to plan entitlements.

## Required references

- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `AGENTS.md`
- `docs/adr/0004_separate_rbac_entitlements_and_quotas.md`

## Required work

1. Define an authorization request/value object containing actor membership, permission key, organization and optional project/property/resource.
2. Resolve direct and team role assignments at compatible ancestor scopes and return a structured allow/deny decision with internal reason code.
3. Keep RBAC independent from entitlements and quotas; expose a later orchestration point rather than calling billing inside the policy.
4. Cache only safely within a request or with revision-based invalidation; privilege changes must take effect promptly.
5. Support grant-management decisions including protected owner permissions.
6. Instrument decisions with bounded metadata and audit high-risk denials without logging customer content.
7. Create a policy adapter/concern for controllers, views, jobs and domain operations.

## Required verification

- Truth-table tests for all scopes and principals.
- Cross-tenant, suspended, archived and unknown-permission denial tests.
- Cache invalidation/privilege-change tests.
- Performance test for a representative member with direct/team assignments.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define an authorization request/value object containing actor membership, permission key, organization and optional project/property/resource.
- [ ] Resolve direct and team role assignments at compatible ancestor scopes and return a structured allow/deny decision with internal reason code.
- [ ] Keep RBAC independent from entitlements and quotas; expose a later orchestration point rather than calling billing inside the policy.
- [ ] Cache only safely within a request or with revision-based invalidation; privilege changes must take effect promptly.
- [ ] Support grant-management decisions including protected owner permissions.
- [ ] Instrument decisions with bounded metadata and audit high-risk denials without logging customer content.
- [ ] Create a policy adapter/concern for controllers, views, jobs and domain operations.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Views may hide controls but are never the enforcement boundary.
- Unknown permission keys must fail closed.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 031 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 031 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 031
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



---

---
id: '032'
title: Enforce authorization in controllers, views, jobs and API boundaries
phase: 03 Organizations, membership and RBAC
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '031'
status: pending
---

# Prompt 032 — Enforce authorization in controllers, views, jobs and API boundaries

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `031`
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
ruby tracking/scripts/prompt_tracker.rb start 032
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

Apply the authorization service consistently to all existing tenant actions and establish reusable enforcement patterns for future features.

## Required references

- `AGENTS.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Inventory every authenticated tenant route/domain operation and map it to a permission key.
2. Add controller/request enforcement before record exposure, including index scopes and nested resources.
3. Add view helpers that consume prior decisions for UI visibility but do not replace backend checks.
4. Require background jobs to receive explicit organization/resource IDs, reload records and re-authorize the intended system/user context according to job policy.
5. Create API authorization error contracts for later use.
6. Add automated coverage/architecture checks that identify tenant controllers lacking an explicit permission declaration where practical.
7. Document the pattern with examples for organization-, project- and property-scoped actions.

## Required verification

- Cross-tenant request tests for every existing tenant route.
- Negative permission tests and list/index leakage tests.
- Background job mismatched-tenant tests.
- System test showing controls hidden and direct request still denied.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Inventory every authenticated tenant route/domain operation and map it to a permission key.
- [ ] Add controller/request enforcement before record exposure, including index scopes and nested resources.
- [ ] Add view helpers that consume prior decisions for UI visibility but do not replace backend checks.
- [ ] Require background jobs to receive explicit organization/resource IDs, reload records and re-authorize the intended system/user context according to job policy.
- [ ] Create API authorization error contracts for later use.
- [ ] Add automated coverage/architecture checks that identify tenant controllers lacking an explicit permission declaration where practical.
- [ ] Document the pattern with examples for organization-, project- and property-scoped actions.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never fetch an unscoped record and authorize after rendering.
- Do not pass serialized `Current` objects into jobs.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 032 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 032 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 032
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



---

---
id: '033'
title: Implement organization ownership transfer with recent authentication
phase: 03 Organizations, membership and RBAC
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '032'
status: pending
---

# Prompt 033 — Implement organization ownership transfer with recent authentication

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `032`
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
ruby tracking/scripts/prompt_tracker.rb start 033
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

Provide a safe, auditable ownership transfer that cannot leave an organization ownerless or be performed from a stale/compromised session.

## Required references

- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Define ownership as an explicit protected role/relationship consistent with the membership model.
2. Require current owner permission, recent authentication and confirmation of the target active membership.
3. Execute new-owner grant and old-owner transition atomically with row locking.
4. Rotate/revoke relevant sessions and permission caches after transfer.
5. Prevent transfer to suspended/removed/external-organization membership.
6. Create confirmation UI describing billing/security consequences without exposing secrets.
7. Emit high-severity audit/security events and notification hooks.
8. Define recovery/support policy without adding an unaudited backdoor.

## Required verification

- Transaction/concurrency tests proving an owner always remains.
- Recent-authentication and stale-session tests.
- Cross-tenant/invalid-target tests.
- System test of successful transfer and immediate permission effects.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define ownership as an explicit protected role/relationship consistent with the membership model.
- [ ] Require current owner permission, recent authentication and confirmation of the target active membership.
- [ ] Execute new-owner grant and old-owner transition atomically with row locking.
- [ ] Rotate/revoke relevant sessions and permission caches after transfer.
- [ ] Prevent transfer to suspended/removed/external-organization membership.
- [ ] Create confirmation UI describing billing/security consequences without exposing secrets.
- [ ] Emit high-severity audit/security events and notification hooks.
- [ ] Define recovery/support policy without adding an unaudited backdoor.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No support-only direct database mutation as the normal path.
- Do not allow transfer through a GET or unsigned link.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 033 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 033 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 033
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



---

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



---

---
id: '035'
title: Complete tenancy and RBAC audit coverage
phase: 03 Organizations, membership and RBAC
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '034'
status: pending
---

# Prompt 035 — Complete tenancy and RBAC audit coverage

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `034`
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
ruby tracking/scripts/prompt_tracker.rb start 035
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

Create immutable, queryable audit records for tenant and access-management changes and finish the mandatory isolation regression gate.

## Required references

- `docs/03_ERD.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Implement an audit-event schema/service capturing actor, organization, action, target type/ID, safe change metadata, request/job correlation and timestamp.
2. Make audit rows append-only through normal application APIs and restrict access to `audit_log.read`.
3. Cover organization lifecycle, invitations, membership status, teams, role assignments, ownership transfer, identity linking and session revocation.
4. Redact emails/IP/user agents according to documented privacy policy and avoid secrets/full payloads.
5. Create organization audit UI with filters/pagination and safe CSV export placeholder only if entitled later.
6. Consolidate tenant-isolation tests for every entity implemented so far into a required CI command.
7. Add an operator consistency report for orphan/cross-tenant relationship detection.

## Required verification

- Append-only and authorization tests.
- Cross-tenant audit-list/export denial tests.
- Redaction tests.
- Run the complete tenancy/RBAC security suite and consistency report.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement an audit-event schema/service capturing actor, organization, action, target type/ID, safe change metadata, request/job correlation and timestamp.
- [ ] Make audit rows append-only through normal application APIs and restrict access to `audit_log.read`.
- [ ] Cover organization lifecycle, invitations, membership status, teams, role assignments, ownership transfer, identity linking and session revocation.
- [ ] Redact emails/IP/user agents according to documented privacy policy and avoid secrets/full payloads.
- [ ] Create organization audit UI with filters/pagination and safe CSV export placeholder only if entitled later.
- [ ] Consolidate tenant-isolation tests for every entity implemented so far into a required CI command.
- [ ] Add an operator consistency report for orphan/cross-tenant relationship detection.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Audit data must not become a second store of raw sensitive payloads.
- No unaudited admin mutation path.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 035 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 035 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 035
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



---

---
id: '036'
title: Implement plans and immutable plan versions
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '035'
status: pending
---

# Prompt 036 — Implement plans and immutable plan versions

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `035`
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
ruby tracking/scripts/prompt_tracker.rb start 036
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

Create the internal commercial catalog so subscriptions reference immutable plan versions rather than mutable plan-name conditionals.

## Required references

- `docs/03_ERD.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `config_blueprints/plans.yml`
- `docs/adr/0004_separate_rbac_entitlements_and_quotas.md`

## Required work

1. Create `plans` and `plan_versions` with stable keys, display metadata, currency/pricing presentation fields, lifecycle state, effective dates and immutable published snapshots.
2. Represent Free, Starter, Growth, Agency and Enterprise as products/catalog entries without embedding provider variant IDs in core domain code.
3. Define draft, published, retired and grandfathered behavior; published versions cannot be mutated in place.
4. Store customer subscriptions against a specific plan version and preserve historical display/pricing metadata.
5. Add idempotent catalog synchronization from `config_blueprints/plans.yml` with validation and a dry-run mode.
6. Implement administrative read-only catalog screens and a controlled publish operation protected by permission/audit.
7. Document migration policy for plan changes and grandfathering.

## Required verification

- Database constraints for stable keys/version uniqueness and immutable published data.
- Config validation and idempotent sync tests.
- Tests proving existing subscription references are unaffected by a new version.
- Audit/authorization tests for publish/retire.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create `plans` and `plan_versions` with stable keys, display metadata, currency/pricing presentation fields, lifecycle state, effective dates and immutable published snapshots.
- [ ] Represent Free, Starter, Growth, Agency and Enterprise as products/catalog entries without embedding provider variant IDs in core domain code.
- [ ] Define draft, published, retired and grandfathered behavior; published versions cannot be mutated in place.
- [ ] Store customer subscriptions against a specific plan version and preserve historical display/pricing metadata.
- [ ] Add idempotent catalog synchronization from `config_blueprints/plans.yml` with validation and a dry-run mode.
- [ ] Implement administrative read-only catalog screens and a controlled publish operation protected by permission/audit.
- [ ] Document migration policy for plan changes and grandfathering.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never branch business logic on display name.
- Do not edit a published plan version in place.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 036 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 036 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 036
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



---

---
id: '037'
title: Implement plan catalog publishing and grandfathering
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '036'
status: pending
---

# Prompt 037 — Implement plan catalog publishing and grandfathering

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `036`
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
ruby tracking/scripts/prompt_tracker.rb start 037
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

Turn plan configuration into a safe publishing workflow that can evolve pricing/features without silently changing existing customer rights.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/03_ERD.md`

## Required work

1. Create a catalog diff showing additions, changed values, removals and affected subscriber counts before publication.
2. Require explicit version bump and administrative confirmation for published changes.
3. Implement effective-at scheduling and selection of the current purchasable version by plan/currency/interval.
4. Preserve grandfathered versions for active subscriptions while hiding retired versions from new checkout.
5. Define upgrade/downgrade target selection and what happens when a target version is unavailable.
6. Prevent deletion of any plan/version referenced by subscription, invoice/report snapshot or audit event.
7. Add a consistency task comparing YAML, database catalog and provider mapping metadata.

## Required verification

- Tests for publish, scheduled activation, retire and grandfather behavior.
- Concurrent publish/version-number conflict test.
- Deletion protection tests.
- Catalog diff snapshot tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a catalog diff showing additions, changed values, removals and affected subscriber counts before publication.
- [ ] Require explicit version bump and administrative confirmation for published changes.
- [ ] Implement effective-at scheduling and selection of the current purchasable version by plan/currency/interval.
- [ ] Preserve grandfathered versions for active subscriptions while hiding retired versions from new checkout.
- [ ] Define upgrade/downgrade target selection and what happens when a target version is unavailable.
- [ ] Prevent deletion of any plan/version referenced by subscription, invoice/report snapshot or audit event.
- [ ] Add a consistency task comparing YAML, database catalog and provider mapping metadata.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No automatic migration of subscribers during catalog sync.
- Provider IDs remain mapping data, not plan identity.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 037 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 037 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 037
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



---

---
id: 038
title: Implement typed entitlement definitions and resolution
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '037'
status: pending
---

# Prompt 038 — Implement typed entitlement definitions and resolution

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `037`
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
ruby tracking/scripts/prompt_tracker.rb start 038
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

Create the typed feature/limit entitlement system and a single resolver that combines plan values with audited organization overrides.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `config_blueprints/plans.yml`
- `docs/adr/0004_separate_rbac_entitlements_and_quotas.md`

## Required work

1. Create entitlement definitions with stable key, data type, unit, category, validation bounds and customer-facing description.
2. Create plan entitlement values and optional organization overrides with validity window, reason, actor and audit metadata.
3. Support boolean, integer, decimal, enum and string values without loose type coercion.
4. Implement resolver precedence: valid organization override, subscribed plan version, safe system default; return value plus provenance.
5. Fail closed for unknown/security-sensitive entitlements and distinguish disabled from absent/misconfigured.
6. Load the 47-key catalog from `config_blueprints/plans.yml` and validate every plan has required values.
7. Add request-scoped caching keyed by entitlement/catalog/subscription revision.
8. Expose a diagnostic/admin view showing effective value and source without leaking billing secrets.

## Required verification

- Truth-table tests for types, bounds, overrides, expiry and provenance.
- Unknown/malformed entitlement tests.
- Cache invalidation tests after plan/override change.
- Cross-organization override denial tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create entitlement definitions with stable key, data type, unit, category, validation bounds and customer-facing description.
- [ ] Create plan entitlement values and optional organization overrides with validity window, reason, actor and audit metadata.
- [ ] Support boolean, integer, decimal, enum and string values without loose type coercion.
- [ ] Implement resolver precedence: valid organization override, subscribed plan version, safe system default; return value plus provenance.
- [ ] Fail closed for unknown/security-sensitive entitlements and distinguish disabled from absent/misconfigured.
- [ ] Load the 47-key catalog from `config_blueprints/plans.yml` and validate every plan has required values.
- [ ] Add request-scoped caching keyed by entitlement/catalog/subscription revision.
- [ ] Expose a diagnostic/admin view showing effective value and source without leaking billing secrets.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not let custom roles change entitlements.
- Do not interpret missing values as unlimited.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 038 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 038 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 038
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



---

---
id: 039
title: Implement immutable usage ledger and metering windows
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 038
status: pending
---

# Prompt 039 — Implement immutable usage ledger and metering windows

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `038`
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
ruby tracking/scripts/prompt_tracker.rb start 039
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

Create an append-only usage ledger and deterministic billing/entitlement windows for all variable-cost operations.

## Required references

- `docs/03_ERD.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Create usage meter definitions for HTTP crawl credits, rendered pages, Lighthouse runs, app-store snapshots, reports and other configured units.
2. Create usage windows tied to organization, meter, start/end, plan/subscription context and timezone policy.
3. Create append-only usage events with idempotency key, quantity, source aggregate, occurred/recorded timestamps and metadata bounds.
4. Implement current-window resolution and aggregation that handles UTC calendar months and provider billing periods explicitly.
5. Prevent updates/deletes through normal domain APIs; corrections use compensating events with references.
6. Create query/read models for used, reserved, remaining and unlimited values.
7. Add retention/partitioning notes for high-volume ledgers and indexes for organization/window/source.
8. Emit audit events for manual adjustments.

## Required verification

- Idempotency and append-only tests.
- Boundary tests at window rollover/timezone/DST.
- Compensating-event and aggregate consistency tests.
- Cross-tenant source/meter tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create usage meter definitions for HTTP crawl credits, rendered pages, Lighthouse runs, app-store snapshots, reports and other configured units.
- [ ] Create usage windows tied to organization, meter, start/end, plan/subscription context and timezone policy.
- [ ] Create append-only usage events with idempotency key, quantity, source aggregate, occurred/recorded timestamps and metadata bounds.
- [ ] Implement current-window resolution and aggregation that handles UTC calendar months and provider billing periods explicitly.
- [ ] Prevent updates/deletes through normal domain APIs; corrections use compensating events with references.
- [ ] Create query/read models for used, reserved, remaining and unlimited values.
- [ ] Add retention/partitioning notes for high-volume ledgers and indexes for organization/window/source.
- [ ] Emit audit events for manual adjustments.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never overwrite usage history to correct it.
- Quantities and units must not mix within a meter.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 039 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 039 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 039
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



---

---
id: '040'
title: Implement atomic quota reservations and finalization
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 039
status: pending
---

# Prompt 040 — Implement atomic quota reservations and finalization

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `039`
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
ruby tracking/scripts/prompt_tracker.rb start 040
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

Prevent oversubscription by reserving estimated credits atomically before asynchronous work and reconciling actual consumption afterward.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/adr/0004_separate_rbac_entitlements_and_quotas.md`

## Required work

1. Create quota reservations with organization, meter/window, idempotency key, requested/held/consumed/released quantities, expiry and source aggregate.
2. Implement a PostgreSQL transaction/locking strategy that checks entitlement limit, committed usage and active reservations atomically.
3. Support unlimited plans explicitly, not through an unsafe sentinel arithmetic shortcut.
4. Implement reserve, extend where allowed, finalize actual usage, release unused quantity and expire abandoned reservations.
5. Make all operations idempotent and resilient to worker retry/cancellation.
6. Snapshot relevant entitlement/plan context at admission so mid-scan plan changes have documented behavior.
7. Create maintenance recovery and reconciliation for stale reservations.
8. Return structured denial with limit, used, reserved, requested and reset time safe for UI/API.

## Required verification

- Real PostgreSQL concurrent reservation race tests at the exact quota boundary.
- Idempotent retry/finalize/release tests.
- Plan change and window rollover tests.
- Crash/stale reservation recovery tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create quota reservations with organization, meter/window, idempotency key, requested/held/consumed/released quantities, expiry and source aggregate.
- [ ] Implement a PostgreSQL transaction/locking strategy that checks entitlement limit, committed usage and active reservations atomically.
- [ ] Support unlimited plans explicitly, not through an unsafe sentinel arithmetic shortcut.
- [ ] Implement reserve, extend where allowed, finalize actual usage, release unused quantity and expire abandoned reservations.
- [ ] Make all operations idempotent and resilient to worker retry/cancellation.
- [ ] Snapshot relevant entitlement/plan context at admission so mid-scan plan changes have documented behavior.
- [ ] Create maintenance recovery and reconciliation for stale reservations.
- [ ] Return structured denial with limit, used, reserved, requested and reset time safe for UI/API.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use cache counters as the source of truth.
- Failed admission must create no charge.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 040 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 040 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 040
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



---

---
id: '041'
title: Build pricing, plan comparison and usage UI
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '040'
status: pending
---

# Prompt 041 — Build pricing, plan comparison and usage UI

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `040`
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
ruby tracking/scripts/prompt_tracker.rb start 041
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

Expose the internal plan catalog and organization usage transparently without hardcoding commercial rules into views.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/01_PRD_V1.md`

## Required work

1. Build public pricing and authenticated plan comparison pages from published plan-version/read-model data.
2. Display key features, limits, interval/currency and grandfathered/current plan status accurately.
3. Create an organization usage page showing used, reserved, remaining, reset date and meter explanations.
4. Represent unlimited, disabled, unavailable and temporarily reserved states distinctly.
5. Add upgrade/downgrade calls to action gated by billing permission and provider availability.
6. Show quota errors with actionable links while preserving access to existing scans/reports according to policy.
7. Add accessible tables/cards and responsive behavior.

## Required verification

- View/request tests for every plan and special value state.
- Authorization tests for billing controls.
- System test for quota-exhausted messaging.
- Verify views do not compare plan names or provider variant IDs.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Build public pricing and authenticated plan comparison pages from published plan-version/read-model data.
- [ ] Display key features, limits, interval/currency and grandfathered/current plan status accurately.
- [ ] Create an organization usage page showing used, reserved, remaining, reset date and meter explanations.
- [ ] Represent unlimited, disabled, unavailable and temporarily reserved states distinctly.
- [ ] Add upgrade/downgrade calls to action gated by billing permission and provider availability.
- [ ] Show quota errors with actionable links while preserving access to existing scans/reports according to policy.
- [ ] Add accessible tables/cards and responsive behavior.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Prices are display data until billing adapter checkout confirms them.
- Do not claim taxes are included unless provider response/configuration says so.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 041 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 041 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 041
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



---

---
id: '042'
title: Create the unified permission-entitlement-quota access boundary
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '041'
status: pending
---

# Prompt 042 — Create the unified permission-entitlement-quota access boundary

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `041`
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
ruby tracking/scripts/prompt_tracker.rb start 042
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

Implement one orchestration service that makes protected billable decisions while preserving separate RBAC, entitlement and quota responsibilities.

## Required references

- `AGENTS.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/adr/0004_separate_rbac_entitlements_and_quotas.md`

## Required work

1. Define an access request containing actor, permission, scope/resource, optional entitlement and optional metered quantity/idempotency key.
2. Evaluate authentication/membership, RBAC, entitlement, resource state and quota in a stable order that avoids information leakage and unnecessary reservations.
3. Return a structured decision with public error code and internal reason/provenance.
4. Reserve quota only after permission/entitlement/resource validation and provide a block/yield API that releases on pre-enqueue failure.
5. Make controller/job/API integrations explicit and hard to bypass.
6. Instrument allow/deny/reserve outcomes with bounded labels.
7. Create a developer guide mapping feature operations to permission, entitlement and meter keys.

## Required verification

- Full truth-table tests from `docs/09_TEST_STRATEGY.md`.
- Test denial ordering does not reveal another tenant's entitlement/resource.
- Test enqueue failure releases reservation.
- Architecture test rejects direct plan-name checks and unauthorized quota mutation patterns where practical.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define an access request containing actor, permission, scope/resource, optional entitlement and optional metered quantity/idempotency key.
- [ ] Evaluate authentication/membership, RBAC, entitlement, resource state and quota in a stable order that avoids information leakage and unnecessary reservations.
- [ ] Return a structured decision with public error code and internal reason/provenance.
- [ ] Reserve quota only after permission/entitlement/resource validation and provide a block/yield API that releases on pre-enqueue failure.
- [ ] Make controller/job/API integrations explicit and hard to bypass.
- [ ] Instrument allow/deny/reserve outcomes with bounded labels.
- [ ] Create a developer guide mapping feature operations to permission, entitlement and meter keys.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not collapse all denials into one internal category.
- Do not expose sensitive internal denial details to clients.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 042 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 042 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 042
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



---

---
id: '043'
title: Define the provider-neutral billing contract
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '042'
status: pending
---

# Prompt 043 — Define the provider-neutral billing contract

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `042`
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
ruby tracking/scripts/prompt_tracker.rb start 043
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

Create a billing adapter interface and canonical billing domain that isolates provider payloads, IDs and lifecycle differences from access logic.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/adr/0008_provider_neutral_billing.md`
- `docs/03_ERD.md`

## Required work

1. Define normalized value objects for customer, checkout request/result, subscription snapshot, invoice/transaction link, portal link, provider event and reconciliation result.
2. Define adapter operations and errors for checkout, portal, subscription fetch, cancellation/change where supported and webhook verification/parsing.
3. Create a fake adapter with deterministic scenarios for tests and local development.
4. Create provider mapping records for organization/customer and internal plan version/provider variant.
5. Define canonical subscription statuses and timestamps, preserving raw provider status only as metadata.
6. Set HTTP timeout/retry/idempotency policies by operation safety.
7. Document how a second provider would implement the contract without changing entitlement resolver.

## Required verification

- Shared adapter contract tests against fake implementation.
- Unknown provider/mapping and malformed response tests.
- Serialization/redaction tests for normalized values.
- Architecture test that core access code does not reference Lemon Squeezy classes/IDs.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define normalized value objects for customer, checkout request/result, subscription snapshot, invoice/transaction link, portal link, provider event and reconciliation result.
- [ ] Define adapter operations and errors for checkout, portal, subscription fetch, cancellation/change where supported and webhook verification/parsing.
- [ ] Create a fake adapter with deterministic scenarios for tests and local development.
- [ ] Create provider mapping records for organization/customer and internal plan version/provider variant.
- [ ] Define canonical subscription statuses and timestamps, preserving raw provider status only as metadata.
- [ ] Set HTTP timeout/retry/idempotency policies by operation safety.
- [ ] Document how a second provider would implement the contract without changing entitlement resolver.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not invent a lowest-common-denominator contract that hides required provider facts.
- Do not make the provider API a synchronous dependency of every request.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 043 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 043 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 043
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



---

---
id: '044'
title: Implement the Lemon Squeezy billing client
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '043'
status: pending
---

# Prompt 044 — Implement the Lemon Squeezy billing client

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `043`
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
ruby tracking/scripts/prompt_tracker.rb start 044
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

Implement the first billing adapter with bounded HTTP behavior, exact provider mapping and sanitized contract fixtures.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/adr/0008_provider_neutral_billing.md`

## Required work

1. Implement authenticated Lemon Squeezy API client endpoints required for checkout/customer/subscription/portal/reconciliation using current official API contracts.
2. Configure store/product/variant mappings outside core plan logic and validate uniqueness/environment separation.
3. Apply strict connect/read/write timeouts, response-size/content validation, rate-limit handling and safe retries only for idempotent operations.
4. Use provider idempotency support where available and local idempotency keys for operation correlation.
5. Normalize provider payloads into billing contract objects and retain only necessary raw metadata.
6. Create sanitized fixtures for success, validation, unauthorized, not found, rate limit, server error and malformed response.
7. Emit provider metrics/events with redacted headers/body.

## Required verification

- Run shared billing-adapter contracts against the Lemon Squeezy implementation using stubs.
- Mapping validation tests.
- Timeout/retry/rate-limit tests.
- Secret and PII redaction tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement authenticated Lemon Squeezy API client endpoints required for checkout/customer/subscription/portal/reconciliation using current official API contracts.
- [ ] Configure store/product/variant mappings outside core plan logic and validate uniqueness/environment separation.
- [ ] Apply strict connect/read/write timeouts, response-size/content validation, rate-limit handling and safe retries only for idempotent operations.
- [ ] Use provider idempotency support where available and local idempotency keys for operation correlation.
- [ ] Normalize provider payloads into billing contract objects and retain only necessary raw metadata.
- [ ] Create sanitized fixtures for success, validation, unauthorized, not found, rate limit, server error and malformed response.
- [ ] Emit provider metrics/events with redacted headers/body.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not call real billing APIs in default tests.
- Do not log authorization headers or full customer payloads.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 044 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 044 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 044
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



---

---
id: '045'
title: Implement hosted checkout and customer portal flows
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '044'
status: pending
---

# Prompt 045 — Implement hosted checkout and customer portal flows

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `044`
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
ruby tracking/scripts/prompt_tracker.rb start 045
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

Allow authorized organization billing managers to create secure hosted checkout and portal sessions tied to exact internal plan versions.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/08_INTEGRATIONS_AND_API.md`

## Required work

1. Implement checkout command validating membership, `billing.manage`, target published plan version, currency/interval and organization eligibility.
2. Create/reuse provider customer mapping safely and pass signed/custom metadata required to correlate checkout with organization and plan version.
3. Generate a hosted checkout URL through the adapter and redirect with no-store/referrer-safe behavior.
4. Treat checkout completion redirect as informational only; entitlements change only after verified canonical billing state.
5. Implement customer portal link creation for existing mapped customers.
6. Prevent open redirects, duplicate active checkout confusion and cross-organization customer reuse.
7. Audit checkout/portal creation without storing full URLs or tokens.
8. Build upgrade/manage billing UI states.

## Required verification

- Request/system tests using fake billing adapter.
- Permission, cross-tenant and invalid/retired plan tests.
- Tests proving return redirect does not activate subscription.
- Idempotency/customer mapping race tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement checkout command validating membership, `billing.manage`, target published plan version, currency/interval and organization eligibility.
- [ ] Create/reuse provider customer mapping safely and pass signed/custom metadata required to correlate checkout with organization and plan version.
- [ ] Generate a hosted checkout URL through the adapter and redirect with no-store/referrer-safe behavior.
- [ ] Treat checkout completion redirect as informational only; entitlements change only after verified canonical billing state.
- [ ] Implement customer portal link creation for existing mapped customers.
- [ ] Prevent open redirects, duplicate active checkout confusion and cross-organization customer reuse.
- [ ] Audit checkout/portal creation without storing full URLs or tokens.
- [ ] Build upgrade/manage billing UI states.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never trust browser-return query parameters as payment proof.
- Do not expose provider customer IDs where unnecessary.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 045 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 045 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 045
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



---

---
id: '046'
title: Implement billing webhook ingress, signature verification and durable storage
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '045'
status: pending
---

# Prompt 046 — Implement billing webhook ingress, signature verification and durable storage

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `045`
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
ruby tracking/scripts/prompt_tracker.rb start 046
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

Create a minimal, secure webhook endpoint that verifies the exact raw request, stores accepted events idempotently and acknowledges quickly.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Read the exact raw request body with a strict maximum size before JSON transformation.
2. Verify Lemon Squeezy's current webhook signature format using constant-time comparison and support controlled secret rotation.
3. Reject invalid/missing signatures and malformed/oversized payloads with safe status codes and metrics.
4. Extract provider event ID/type and persist the raw encrypted/protected payload, headers subset, received timestamp, checksum and processing state in one transaction.
5. Enforce uniqueness/idempotency on provider/event ID and detect conflicting duplicate payloads.
6. Enqueue asynchronous projection only after durable commit and return quickly.
7. Create replay/dead-letter/admin visibility foundations.
8. Redact all logs; signature verification tests must use real HMAC behavior over raw bytes.

## Required verification

- Valid, invalid, missing, rotated-secret and modified-byte signature tests.
- Duplicate and conflicting-duplicate concurrency tests.
- Oversized/malformed payload tests.
- Test durable record exists before job enqueue/acknowledgement semantics.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Read the exact raw request body with a strict maximum size before JSON transformation.
- [ ] Verify Lemon Squeezy's current webhook signature format using constant-time comparison and support controlled secret rotation.
- [ ] Reject invalid/missing signatures and malformed/oversized payloads with safe status codes and metrics.
- [ ] Extract provider event ID/type and persist the raw encrypted/protected payload, headers subset, received timestamp, checksum and processing state in one transaction.
- [ ] Enforce uniqueness/idempotency on provider/event ID and detect conflicting duplicate payloads.
- [ ] Enqueue asynchronous projection only after durable commit and return quickly.
- [ ] Create replay/dead-letter/admin visibility foundations.
- [ ] Redact all logs; signature verification tests must use real HMAC behavior over raw bytes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not parse/re-serialize JSON before signature verification.
- Do not perform provider API reconciliation in the webhook request.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 046 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 046 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 046
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



---

---
id: '047'
title: Implement idempotent asynchronous billing event projection
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '046'
status: pending
---

# Prompt 047 — Implement idempotent asynchronous billing event projection

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `046`
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
ruby tracking/scripts/prompt_tracker.rb start 047
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

Project durable provider events into canonical customer/subscription state correctly under duplicates, retries and out-of-order delivery.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/adr/0008_provider_neutral_billing.md`

## Required work

1. Implement event parser/version handling for supported Lemon Squeezy subscription/order events while preserving unknown events safely.
2. Resolve organization and plan version through authenticated provider mappings/custom data; reject ambiguous or cross-environment mappings.
3. Lock canonical subscription/customer rows and apply transitions by provider event/order timestamps plus deterministic precedence.
4. Make projection idempotent and record processing attempt, result, failure category and generated audit/domain events.
5. Handle an event arriving before checkout/customer mapping by retrying/reconciling rather than creating an unsafe guessed tenant.
6. Do not downgrade a newer canonical snapshot with stale event data.
7. Create dead-letter state and controlled replay operation.
8. Trigger entitlement/access revision invalidation only after canonical state changes.

## Required verification

- Event matrix tests for all supported types.
- Duplicate/out-of-order/retry/concurrent projection tests.
- Unknown version/type and missing mapping tests.
- Test stale event cannot overwrite newer subscription state.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement event parser/version handling for supported Lemon Squeezy subscription/order events while preserving unknown events safely.
- [ ] Resolve organization and plan version through authenticated provider mappings/custom data; reject ambiguous or cross-environment mappings.
- [ ] Lock canonical subscription/customer rows and apply transitions by provider event/order timestamps plus deterministic precedence.
- [ ] Make projection idempotent and record processing attempt, result, failure category and generated audit/domain events.
- [ ] Handle an event arriving before checkout/customer mapping by retrying/reconciling rather than creating an unsafe guessed tenant.
- [ ] Do not downgrade a newer canonical snapshot with stale event data.
- [ ] Create dead-letter state and controlled replay operation.
- [ ] Trigger entitlement/access revision invalidation only after canonical state changes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not infer organization from customer email.
- Do not discard unknown events before durable recording.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 047 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 047 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 047
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



---

---
id: 048
title: Implement subscription lifecycle and access policy
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '047'
status: pending
---

# Prompt 048 — Implement subscription lifecycle and access policy

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `047`
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
ruby tracking/scripts/prompt_tracker.rb start 048
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

Translate canonical subscription status into explicit product-access behavior for trials, active service, delinquency, cancellation and expiry.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/03_ERD.md`
- `docs/08_INTEGRATIONS_AND_API.md`

## Required work

1. Implement the canonical status/state machine with provider timestamps, current period, cancellation scheduling and grace policy.
2. Define exact access effects for `trialing`, `active`, `past_due`, `paused`, `canceled`, `incomplete` and `expired`.
3. Preserve read access to existing data where policy allows while pausing new scheduled/billable work.
4. Implement immediate upgrade and scheduled downgrade behavior using target plan versions and reservation snapshots.
5. Handle reactivation, cancellation reversal and provider correction idempotently.
6. Expose customer-facing billing status/remediation without overclaiming provider/tax details.
7. Invalidate entitlement caches/revisions atomically with state transitions.
8. Audit transitions and enqueue notifications through outbox/jobs.

## Required verification

- State-machine transition matrix tests, including impossible transitions.
- Access behavior tests for each status across read/new scan/integration/report actions.
- Upgrade/downgrade during active reservation tests.
- System tests for past-due/canceled/reactivated UI.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement the canonical status/state machine with provider timestamps, current period, cancellation scheduling and grace policy.
- [ ] Define exact access effects for `trialing`, `active`, `past_due`, `paused`, `canceled`, `incomplete` and `expired`.
- [ ] Preserve read access to existing data where policy allows while pausing new scheduled/billable work.
- [ ] Implement immediate upgrade and scheduled downgrade behavior using target plan versions and reservation snapshots.
- [ ] Handle reactivation, cancellation reversal and provider correction idempotently.
- [ ] Expose customer-facing billing status/remediation without overclaiming provider/tax details.
- [ ] Invalidate entitlement caches/revisions atomically with state transitions.
- [ ] Audit transitions and enqueue notifications through outbox/jobs.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not delete customer data automatically on payment failure.
- Do not let a stale browser session preserve old entitlements.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 048 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 048 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 048
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



---

---
id: 049
title: Add billing reconciliation and support operations
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 048
status: pending
---

# Prompt 049 — Add billing reconciliation and support operations

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `048`
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
ruby tracking/scripts/prompt_tracker.rb start 049
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

Detect and repair drift between durable provider state and canonical application state through audited, rate-limited reconciliation.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Implement scheduled reconciliation that fetches provider subscription snapshots for mapped active/recent subscriptions and compares relevant fields.
2. Classify exact match, safe automatic repair, ambiguous drift, missing provider object and provider outage.
3. Apply safe corrections through the same canonical transition service, preserving provider snapshot and audit trail.
4. Create admin screens/actions for event inspection, replay, mapping diagnostics and targeted reconciliation with least privilege/recent authentication.
5. Add alerting metrics for webhook lag, dead letters, repeated projection failure and reconciliation drift.
6. Create data consistency queries for duplicate mappings, subscriber without plan version and entitlement revision mismatch.
7. Document billing incident/recovery runbook.

## Required verification

- Adapter-fake reconciliation scenarios including stale webhook and provider deletion.
- Authorization/recent-auth/audit tests for support actions.
- Rate-limit/backoff tests.
- Run consistency report against fixtures and assert zero unexplained drift.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement scheduled reconciliation that fetches provider subscription snapshots for mapped active/recent subscriptions and compares relevant fields.
- [ ] Classify exact match, safe automatic repair, ambiguous drift, missing provider object and provider outage.
- [ ] Apply safe corrections through the same canonical transition service, preserving provider snapshot and audit trail.
- [ ] Create admin screens/actions for event inspection, replay, mapping diagnostics and targeted reconciliation with least privilege/recent authentication.
- [ ] Add alerting metrics for webhook lag, dead letters, repeated projection failure and reconciliation drift.
- [ ] Create data consistency queries for duplicate mappings, subscriber without plan version and entitlement revision mismatch.
- [ ] Document billing incident/recovery runbook.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No routine direct SQL mutation from support UI.
- Automatic repair must never guess tenant or plan mapping.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 049 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 049 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 049
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



---

---
id: '050'
title: Implement project aggregate and lifecycle
phase: 05 Projects, properties and verification
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 049
status: pending
---

# Prompt 050 — Implement project aggregate and lifecycle

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `049`
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
ruby tracking/scripts/prompt_tracker.rb start 050
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

Create organization-owned product/projects as the principal authorization and reporting boundary for related web and mobile properties.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`

## Required work

1. Create projects with UUID, organization, stable key/slug, name, description, lifecycle state, default locale/timezone and external release key.
2. Define active, archived and pending-deletion transitions with centralized operations.
3. Enforce organization ownership and unique keys through database constraints.
4. Create CRUD/list/detail UI protected by project permissions and pagination/search.
5. Create initial project-scoped role assignment hooks without granting implicit access beyond documented organization roles.
6. Emit audit events and preserve archived history.
7. Add read model placeholders for health, property counts and latest scan without N+1 queries.

## Required verification

- Model/database lifecycle and uniqueness tests.
- Cross-tenant request/index tests.
- Archive/reactivate permission tests.
- System tests for project CRUD.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create projects with UUID, organization, stable key/slug, name, description, lifecycle state, default locale/timezone and external release key.
- [ ] Define active, archived and pending-deletion transitions with centralized operations.
- [ ] Enforce organization ownership and unique keys through database constraints.
- [ ] Create CRUD/list/detail UI protected by project permissions and pagination/search.
- [ ] Create initial project-scoped role assignment hooks without granting implicit access beyond documented organization roles.
- [ ] Emit audit events and preserve archived history.
- [ ] Add read model placeholders for health, property counts and latest scan without N+1 queries.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use projects as billing tenants; organization remains the billing boundary.
- Archived projects do not permit new scans.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 050 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 050 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 050
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



---

---
id: '051'
title: Implement polymorphic property model and typed configurations
phase: 05 Projects, properties and verification
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '050'
status: pending
---

# Prompt 051 — Implement polymorphic property model and typed configurations

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `050`
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
ruby tracking/scripts/prompt_tracker.rb start 051
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

Represent website, web application, Android and iOS discovery surfaces under one project while keeping type-specific configuration validated and explicit.

## Required references

- `docs/03_ERD.md`
- `docs/01_PRD_V1.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`

## Required work

1. Create properties with UUID, project/organization relationship, type, display name, lifecycle and verification status.
2. Use typed associated configuration/value objects for website origin, Android package and iOS bundle/team information rather than an unvalidated JSON blob for core fields.
3. Define property types: website, web_application, android_app and ios_app; allow future types through versioned domain changes.
4. Enforce normalized uniqueness within project/organization.
5. Create property create/edit/list/detail UI with type-specific fields and permission checks.
6. Emit audit events for changes that affect scanning or association validation.
7. Prepare property-level role scope and access resolution.

## Required verification

- Type validation and database consistency tests.
- Cross-tenant project/property creation tests.
- Property-scope authorization tests.
- System tests for each property type.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create properties with UUID, project/organization relationship, type, display name, lifecycle and verification status.
- [ ] Use typed associated configuration/value objects for website origin, Android package and iOS bundle/team information rather than an unvalidated JSON blob for core fields.
- [ ] Define property types: website, web_application, android_app and ios_app; allow future types through versioned domain changes.
- [ ] Enforce normalized uniqueness within project/organization.
- [ ] Create property create/edit/list/detail UI with type-specific fields and permission checks.
- [ ] Emit audit events for changes that affect scanning or association validation.
- [ ] Prepare property-level role scope and access resolution.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not store all type-specific security-critical fields in arbitrary JSON.
- Changing property type after data exists requires an explicit migration operation.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 051 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 051 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 051
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



---

---
id: '052'
title: Implement environments and canonical URL origin normalization
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '051'
status: pending
---

# Prompt 052 — Implement environments and canonical URL origin normalization

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `051`
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
ruby tracking/scripts/prompt_tracker.rb start 052
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

Add development/staging/production environments and a strict URL/origin normalizer that later crawler security can trust.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/03_ERD.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Create project/property environments with stable key, kind, display name, primary flag and lifecycle.
2. Implement canonical HTTP(S) origin parsing: scheme, IDNA hostname handling, normalized port, no userinfo, no path/query/fragment for origin fields.
3. Define default-port collapse, trailing-dot behavior, Unicode display vs ASCII network form and exact subdomain boundaries.
4. Require one primary production environment where applicable and enforce uniqueness transactionally.
5. Build environment management UI with warnings for public vs non-public targets.
6. Keep private/internal origins unsupported for MVP unless an explicit future enterprise policy is introduced.
7. Emit audit events for origin changes because they affect verification and scan trust.

## Required verification

- Extensive normalization table tests for IPv4/IPv6/IDNA/ports/userinfo/malformed input.
- Concurrent primary-environment tests.
- Cross-tenant environment tests.
- Security tests rejecting non-HTTP(S) origins.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create project/property environments with stable key, kind, display name, primary flag and lifecycle.
- [ ] Implement canonical HTTP(S) origin parsing: scheme, IDNA hostname handling, normalized port, no userinfo, no path/query/fragment for origin fields.
- [ ] Define default-port collapse, trailing-dot behavior, Unicode display vs ASCII network form and exact subdomain boundaries.
- [ ] Require one primary production environment where applicable and enforce uniqueness transactionally.
- [ ] Build environment management UI with warnings for public vs non-public targets.
- [ ] Keep private/internal origins unsupported for MVP unless an explicit future enterprise policy is introduced.
- [ ] Emit audit events for origin changes because they affect verification and scan trust.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- URL parsing is not SSRF authorization by itself.
- Do not silently rewrite an invalid hostname into a different target.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 052 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 052 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 052
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



---

---
id: '053'
title: Create the domain verification aggregate and lifecycle
phase: 05 Projects, properties and verification
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '052'
status: pending
---

# Prompt 053 — Create the domain verification aggregate and lifecycle

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `052`
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
ruby tracking/scripts/prompt_tracker.rb start 053
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

Model proof-of-control challenges separately from current verification status so verification is auditable, expiring and re-checkable.

## Required references

- `docs/03_ERD.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create verification challenges/attempts with method, hashed/random token material, expected location/value, expiry, status, attempts and verified timestamp.
2. Support DNS TXT, HTML file, meta tag and Search Console methods through an adapter contract.
3. Define pending, verified, failed, expired and revoked transitions.
4. Bind challenges to exact property/environment origin and invalidate/reverify after material origin change.
5. Rate-limit attempts, record safe evidence and never expose another organization's token/challenge.
6. Define verification freshness policy for high-volume/render scans.
7. Create UI to choose method, view exact instructions, retry and revoke.
8. Emit audit events for issue, success, failure category and revocation.

## Required verification

- Lifecycle/idempotency/expiry tests.
- Cross-tenant challenge access tests.
- Origin-change invalidation tests.
- Rate-limit and secret-redaction tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create verification challenges/attempts with method, hashed/random token material, expected location/value, expiry, status, attempts and verified timestamp.
- [ ] Support DNS TXT, HTML file, meta tag and Search Console methods through an adapter contract.
- [ ] Define pending, verified, failed, expired and revoked transitions.
- [ ] Bind challenges to exact property/environment origin and invalidate/reverify after material origin change.
- [ ] Rate-limit attempts, record safe evidence and never expose another organization's token/challenge.
- [ ] Define verification freshness policy for high-volume/render scans.
- [ ] Create UI to choose method, view exact instructions, retry and revoke.
- [ ] Emit audit events for issue, success, failure category and revocation.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Verification proves control at a point in time, not that all URLs are safe.
- Do not store raw reusable secrets when a digest is sufficient.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 053 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 053 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 053
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



---

---
id: '054'
title: Implement DNS TXT domain verification
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '053'
status: pending
---

# Prompt 054 — Implement DNS TXT domain verification

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `053`
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
ruby tracking/scripts/prompt_tracker.rb start 054
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

Verify domain control through DNS TXT with bounded resolution, exact token matching and clear propagation/error behavior.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/08_INTEGRATIONS_AND_API.md`

## Required work

1. Create a DNS resolver adapter with timeouts, result-size limits, CNAME/delegation bounds and normalized error categories.
2. Generate an unpredictable single-use TXT challenge at a documented hostname and display it safely.
3. Resolve only the intended verification name, normalize TXT record chunks without accepting near/substring matches and require exact token semantics.
4. Handle NXDOMAIN, no record, propagation, transient resolver failure and multiple records distinctly.
5. Prevent DNS responses from being reused across organizations/challenges.
6. Consume/mark challenge atomically and record resolver evidence without full unrelated DNS data.
7. Add periodic recheck hook according to verification freshness policy.
8. Document local fake DNS testing.

## Required verification

- Resolver contract tests for success/NXDOMAIN/timeout/multiple/chunked TXT.
- Token near-match/case/whitespace tests.
- Concurrent verify/replay tests.
- Cross-tenant and redaction tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a DNS resolver adapter with timeouts, result-size limits, CNAME/delegation bounds and normalized error categories.
- [ ] Generate an unpredictable single-use TXT challenge at a documented hostname and display it safely.
- [ ] Resolve only the intended verification name, normalize TXT record chunks without accepting near/substring matches and require exact token semantics.
- [ ] Handle NXDOMAIN, no record, propagation, transient resolver failure and multiple records distinctly.
- [ ] Prevent DNS responses from being reused across organizations/challenges.
- [ ] Consume/mark challenge atomically and record resolver evidence without full unrelated DNS data.
- [ ] Add periodic recheck hook according to verification freshness policy.
- [ ] Document local fake DNS testing.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use DNS TXT verification as permission to access private IP destinations.
- Do not rely on one global mutable resolver cache for security decisions.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 054 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 054 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 054
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



---

---
id: '055'
title: Implement HTML file and meta-tag verification
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '054'
status: pending
---

# Prompt 055 — Implement HTML file and meta-tag verification

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `054`
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
ruby tracking/scripts/prompt_tracker.rb start 055
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

Verify website control through tightly bounded public HTTP fetches using the same network-safety boundary required by the crawler.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Define exact verification file path/content and meta-tag name/value formats with high-entropy challenge values.
2. Fetch only the exact normalized property origin/path through the centralized safe-destination client; validate every redirect and cap redirects/bytes/time/content type.
3. Require exact token match in expected location and avoid executing JavaScript.
4. Handle canonical redirects between approved host variants only according to an explicit policy.
5. Store safe evidence hash/status rather than full potentially sensitive page content.
6. Make challenge one-time/idempotent and support retry/expiry.
7. Provide clear UI instructions and error categories.
8. Reuse security fixtures for private redirect, oversized response and malformed HTML.

## Required verification

- Success tests for file and meta methods.
- SSRF/redirect/content-size/content-type security tests.
- Exact-match and duplicate-meta tests.
- Replay/expiry/cross-tenant tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define exact verification file path/content and meta-tag name/value formats with high-entropy challenge values.
- [ ] Fetch only the exact normalized property origin/path through the centralized safe-destination client; validate every redirect and cap redirects/bytes/time/content type.
- [ ] Require exact token match in expected location and avoid executing JavaScript.
- [ ] Handle canonical redirects between approved host variants only according to an explicit policy.
- [ ] Store safe evidence hash/status rather than full potentially sensitive page content.
- [ ] Make challenge one-time/idempotent and support retry/expiry.
- [ ] Provide clear UI instructions and error categories.
- [ ] Reuse security fixtures for private redirect, oversized response and malformed HTML.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not create a second unrestricted HTTP client.
- Do not execute page scripts for verification.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 055 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 055 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 055
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



---

---
id: '056'
title: Implement Search Console ownership verification
phase: 05 Projects, properties and verification
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '055'
status: pending
---

# Prompt 056 — Implement Search Console ownership verification

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `055`
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
ruby tracking/scripts/prompt_tracker.rb start 056
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

Allow an authorized Search Console connection to serve as property-control evidence without conflating login identity, provider access and SearchOps membership.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Define the verification adapter over a separately consented Search Console integration connection.
2. List/access exact provider property identifiers and match them to the normalized SearchOps site property using documented URL-prefix/domain-property rules.
3. Require the current member to have both integration and property-management permissions.
4. Record provider permission level, checked timestamp and external property identifier.
5. Handle revoked scopes, inaccessible property, provider outage and ambiguous match.
6. Do not retain broader property lists longer than necessary.
7. Reverify on token/account/property-origin changes.
8. Create UI to select an exact eligible property and explain provider-known proof.

## Required verification

- Adapter tests for URL-prefix/domain property matching.
- Permission and cross-tenant connection tests.
- Revoked/insufficient provider permission tests.
- Ambiguous/no-match tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define the verification adapter over a separately consented Search Console integration connection.
- [ ] List/access exact provider property identifiers and match them to the normalized SearchOps site property using documented URL-prefix/domain-property rules.
- [ ] Require the current member to have both integration and property-management permissions.
- [ ] Record provider permission level, checked timestamp and external property identifier.
- [ ] Handle revoked scopes, inaccessible property, provider outage and ambiguous match.
- [ ] Do not retain broader property lists longer than necessary.
- [ ] Reverify on token/account/property-origin changes.
- [ ] Create UI to select an exact eligible property and explain provider-known proof.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- A Google login session is not automatically a Search Console authorization.
- Do not infer sibling-domain ownership.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 056 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 056 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 056
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



---

---
id: '057'
title: Build the guided project and property onboarding wizard
phase: 05 Projects, properties and verification
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '056'
status: pending
---

# Prompt 057 — Build the guided project and property onboarding wizard

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `056`
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
ruby tracking/scripts/prompt_tracker.rb start 057
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

Create a resumable, accessible onboarding path from organization to verified project/property and initial scan readiness.

## Required references

- `docs/01_PRD_V1.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`

## Required work

1. Implement server-side persisted onboarding state for project basics, property type, environment/origin, verification method, crawl settings and review.
2. Allow safe back/forward/resume without trusting hidden state or creating duplicate aggregates.
3. Show plan entitlement/limit effects before creation and reserve no scan credits until actual scan admission.
4. Handle website-only and combined web/mobile product paths.
5. Route invited/scoped users according to permissions and prevent them from escalating configuration.
6. Provide factual readiness checklist: property exists, origin normalized, ownership verified, scan settings valid.
7. Instrument abandonment/step completion with privacy-safe events.
8. Add cancellation cleanup for drafts.

## Required verification

- System tests for website, Android/iOS addition, resume and validation failure.
- Duplicate submission/idempotency tests.
- Permission/entitlement/quota boundary tests.
- No-JavaScript and accessibility checks.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement server-side persisted onboarding state for project basics, property type, environment/origin, verification method, crawl settings and review.
- [ ] Allow safe back/forward/resume without trusting hidden state or creating duplicate aggregates.
- [ ] Show plan entitlement/limit effects before creation and reserve no scan credits until actual scan admission.
- [ ] Handle website-only and combined web/mobile product paths.
- [ ] Route invited/scoped users according to permissions and prevent them from escalating configuration.
- [ ] Provide factual readiness checklist: property exists, origin normalized, ownership verified, scan settings valid.
- [ ] Instrument abandonment/step completion with privacy-safe events.
- [ ] Add cancellation cleanup for drafts.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not claim a property is verified before challenge success.
- Do not start a crawl from a GET or page refresh.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 057 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 057 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 057
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



---

---
id: 058
title: Implement crawl settings and policy configuration
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '057'
status: pending
---

# Prompt 058 — Implement crawl settings and policy configuration

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `057`
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
ruby tracking/scripts/prompt_tracker.rb start 058
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

Store validated per-environment crawl policy with safe defaults, plan bounds and immutable snapshots for each scan.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`

## Required work

1. Model settings for start URLs/sitemaps, include/exclude patterns, maximum URLs/depth, query handling, user agent, rate/concurrency, robots behavior, rendering sampling and artifact retention.
2. Validate all values against global safety caps and effective entitlements; organization settings may reduce but never exceed global policy.
3. Compile patterns safely with complexity/length limits to avoid regex denial of service.
4. Normalize start URLs to the verified allowed origin and reject credentials, fragments or unsupported schemes.
5. Version settings and snapshot the exact effective configuration into each scan.
6. Create settings UI with estimates/credit explanations and safe defaults.
7. Audit changes and provide reset-to-plan-safe-default action.
8. Document which controls are unavailable in MVP, including authenticated/private crawl.

## Required verification

- Validation/property-origin/plan-bound tests.
- Regex/glob complexity security tests.
- Snapshot immutability tests after settings change.
- Cross-tenant settings tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Model settings for start URLs/sitemaps, include/exclude patterns, maximum URLs/depth, query handling, user agent, rate/concurrency, robots behavior, rendering sampling and artifact retention.
- [ ] Validate all values against global safety caps and effective entitlements; organization settings may reduce but never exceed global policy.
- [ ] Compile patterns safely with complexity/length limits to avoid regex denial of service.
- [ ] Normalize start URLs to the verified allowed origin and reject credentials, fragments or unsupported schemes.
- [ ] Version settings and snapshot the exact effective configuration into each scan.
- [ ] Create settings UI with estimates/credit explanations and safe defaults.
- [ ] Audit changes and provide reset-to-plan-safe-default action.
- [ ] Document which controls are unavailable in MVP, including authenticated/private crawl.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not expose an option to ignore global SSRF/network policy.
- User-agent/robots controls must not impersonate unrelated privileged crawlers.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 058 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 058 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 058
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



---

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



---

---
id: '060'
title: Implement archive, deletion and retention workflows
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 059
status: pending
---

# Prompt 060 — Implement archive, deletion and retention workflows

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `059`
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
ruby tracking/scripts/prompt_tracker.rb start 060
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

Define safe lifecycle behavior for projects/properties, including job cancellation, retained evidence and eventual deletion without orphaned artifacts.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/03_ERD.md`

## Required work

1. Implement archive/reactivate and request-deletion/cancel-deletion operations with permissions and recent authentication for destructive actions.
2. Stop new schedules/scans immediately and signal active work for cooperative cancellation.
3. Define retention hold/grace period and what remains readable during it.
4. Create asynchronous deletion workflow ordered across integrations, scans/findings, reports, object artifacts, API keys/webhooks and aggregate records.
5. Use tombstones/audit references where required for billing/security history.
6. Make deletion idempotent, resumable and observable; reconcile failed object deletion.
7. Provide export/delete warnings and final confirmation UI.
8. Document legal/privacy review points rather than asserting universal retention law.

## Required verification

- Lifecycle and authorization tests.
- Active-job cancellation/deletion-resume tests.
- Object-store failure/reconciliation tests.
- Cross-tenant deletion and signed-artifact denial tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement archive/reactivate and request-deletion/cancel-deletion operations with permissions and recent authentication for destructive actions.
- [ ] Stop new schedules/scans immediately and signal active work for cooperative cancellation.
- [ ] Define retention hold/grace period and what remains readable during it.
- [ ] Create asynchronous deletion workflow ordered across integrations, scans/findings, reports, object artifacts, API keys/webhooks and aggregate records.
- [ ] Use tombstones/audit references where required for billing/security history.
- [ ] Make deletion idempotent, resumable and observable; reconcile failed object deletion.
- [ ] Provide export/delete warnings and final confirmation UI.
- [ ] Document legal/privacy review points rather than asserting universal retention law.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not perform large cascades synchronously in a web request.
- Do not delete billing/security audit evidence contrary to documented retention policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 060 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 060 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 060
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



---

---
id: '061'
title: Build project dashboard and baseline readiness views
phase: 05 Projects, properties and verification
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '060'
status: pending
---

# Prompt 061 — Build project dashboard and baseline readiness views

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `060`
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
ruby tracking/scripts/prompt_tracker.rb start 061
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

Create the first useful project dashboard that reflects real state and guides the user to verification/scan actions without fake metrics.

## Required references

- `docs/01_PRD_V1.md`
- `docs/04_RBAC_PERMISSION_MATRIX.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`

## Required work

1. Build a project overview with properties, verification status, latest scan state, finding counts placeholders/read models, usage and integration readiness.
2. Show clear empty states before scans and distinguish unavailable, loading, failed, stale and no-data states.
3. Use permission/entitlement decisions for actions and explain disabled controls.
4. Add property/environment navigation and readiness checklist.
5. Prepare Turbo Stream targets for later scan progress without coupling dashboard queries to queue internals.
6. Optimize queries and add pagination for property/activity lists.
7. Add audit/recent activity summaries from real records.

## Required verification

- View/system tests for empty, ready, archived, quota-exhausted and restricted user states.
- Query-count/N+1 regression test.
- Cross-tenant dashboard test.
- Accessibility/responsive checks.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Build a project overview with properties, verification status, latest scan state, finding counts placeholders/read models, usage and integration readiness.
- [ ] Show clear empty states before scans and distinguish unavailable, loading, failed, stale and no-data states.
- [ ] Use permission/entitlement decisions for actions and explain disabled controls.
- [ ] Add property/environment navigation and readiness checklist.
- [ ] Prepare Turbo Stream targets for later scan progress without coupling dashboard queries to queue internals.
- [ ] Optimize queries and add pagination for property/activity lists.
- [ ] Add audit/recent activity summaries from real records.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fabricate SEO scores before rule execution exists.
- Do not expose raw internal IDs or queue details.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 061 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 061 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 061
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



---

---
id: '062'
title: Implement the scan aggregate and state machine
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '061'
status: pending
---

# Prompt 062 — Implement the scan aggregate and state machine

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `061`
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
ruby tracking/scripts/prompt_tracker.rb start 062
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

Create the scan domain aggregate that coordinates immutable input snapshots, work progress, cancellation, result provenance and terminal outcomes.

## Required references

- `docs/03_ERD.md`
- `docs/02_ARCHITECTURE.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Create scans with organization/project/property/environment, type, initiator, settings/entitlement snapshots, status, timestamps, release/baseline links and counters.
2. Define requested, admitted, queued, running, cancel_requested, canceled, completed, partially_completed and failed transitions with allowed commands.
3. Use optimistic/explicit locking to prevent contradictory transitions.
4. Record engine/rule/config versions and safe failure category.
5. Create scan events/progress records suitable for read models and Turbo updates without high-write amplification.
6. Separate terminal business outcome from individual URL/job failures.
7. Add permission-aware list/detail UI foundations.
8. Emit audit/domain events for request, start, cancel and completion.

## Required verification

- State transition matrix and concurrency tests.
- Snapshot immutability tests.
- Cross-tenant scan list/detail tests.
- Counter/progress consistency tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create scans with organization/project/property/environment, type, initiator, settings/entitlement snapshots, status, timestamps, release/baseline links and counters.
- [ ] Define requested, admitted, queued, running, cancel_requested, canceled, completed, partially_completed and failed transitions with allowed commands.
- [ ] Use optimistic/explicit locking to prevent contradictory transitions.
- [ ] Record engine/rule/config versions and safe failure category.
- [ ] Create scan events/progress records suitable for read models and Turbo updates without high-write amplification.
- [ ] Separate terminal business outcome from individual URL/job failures.
- [ ] Add permission-aware list/detail UI foundations.
- [ ] Emit audit/domain events for request, start, cancel and completion.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not infer scan completion only from queue emptiness.
- Do not permit terminal states to be silently reopened.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 062 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 062 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 062
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



---

---
id: '063'
title: Implement scan admission, idempotency and preflight
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '062'
status: pending
---

# Prompt 063 — Implement scan admission, idempotency and preflight

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `062`
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
ruby tracking/scripts/prompt_tracker.rb start 063
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

Turn a user/schedule/release request into one admitted scan only after access, verification, safety, capacity and quota checks pass.

## Required references

- `AGENTS.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Define scan request command with idempotency key, source, target property/environment, scan type and optional baseline/release.
2. Use unified permission-entitlement-quota boundary and verified-origin freshness policy.
3. Validate effective crawl settings/global caps and estimate weighted credit reservation.
4. Enforce organization/project/global concurrent scan limits using transactional admission.
5. Run bounded preflight for origin resolution/reachability without consuming full scan.
6. Persist scan and reservation atomically enough to recover from enqueue failure; use an outbox or after-commit pattern.
7. Return existing scan for safe duplicate idempotency key.
8. Create UI/API error contracts for forbidden, unverified, quota, capacity and unsafe target.

## Required verification

- Duplicate/concurrent admission tests.
- Quota reservation/enqueue failure recovery tests.
- Verification-expiry and unsafe-origin tests.
- Concurrent-scan limit tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define scan request command with idempotency key, source, target property/environment, scan type and optional baseline/release.
- [ ] Use unified permission-entitlement-quota boundary and verified-origin freshness policy.
- [ ] Validate effective crawl settings/global caps and estimate weighted credit reservation.
- [ ] Enforce organization/project/global concurrent scan limits using transactional admission.
- [ ] Run bounded preflight for origin resolution/reachability without consuming full scan.
- [ ] Persist scan and reservation atomically enough to recover from enqueue failure; use an outbox or after-commit pattern.
- [ ] Return existing scan for safe duplicate idempotency key.
- [ ] Create UI/API error contracts for forbidden, unverified, quota, capacity and unsafe target.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No side effects before tenant/resource authorization.
- A failed preflight must not leave unrecoverable held credits.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 063 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 063 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 063
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



---

---
id: '064'
title: Implement the PostgreSQL crawl frontier with leasing
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '063'
status: pending
---

# Prompt 064 — Implement the PostgreSQL crawl frontier with leasing

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `063`
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
ruby tracking/scripts/prompt_tracker.rb start 064
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

Create a durable high-volume crawl frontier using PostgreSQL row leasing and `FOR UPDATE SKIP LOCKED` with recovery and fair scheduling.

## Required references

- `docs/02_ARCHITECTURE.md`
- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Create high-volume crawl URL/frontier tables using bigint where appropriate, normalized URL digest, depth, priority, discovery source, state, lease owner/expiry, attempts and result references.
2. Enforce uniqueness per scan/normalized URL and organization/project consistency.
3. Implement batch discovery/upsert and lease acquisition with `SKIP LOCKED`, ordered by priority/depth/discovery sequence.
4. Implement heartbeat/lease extension, success/failure/retry, terminal exhaustion and stale lease recovery.
5. Prevent two workers from fetching the same frontier item concurrently under normal operation.
6. Add organization/host fairness inputs so one large scan cannot monopolize all workers.
7. Design indexes and retention/partition notes using representative query plans.
8. Expose aggregate progress without counting the entire frontier on every request.

## Required verification

- Real PostgreSQL multi-worker leasing tests.
- Stale lease/crash/retry/idempotency tests.
- Duplicate discovery concurrency tests.
- `EXPLAIN`/performance test on representative dataset.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create high-volume crawl URL/frontier tables using bigint where appropriate, normalized URL digest, depth, priority, discovery source, state, lease owner/expiry, attempts and result references.
- [ ] Enforce uniqueness per scan/normalized URL and organization/project consistency.
- [ ] Implement batch discovery/upsert and lease acquisition with `SKIP LOCKED`, ordered by priority/depth/discovery sequence.
- [ ] Implement heartbeat/lease extension, success/failure/retry, terminal exhaustion and stale lease recovery.
- [ ] Prevent two workers from fetching the same frontier item concurrently under normal operation.
- [ ] Add organization/host fairness inputs so one large scan cannot monopolize all workers.
- [ ] Design indexes and retention/partition notes using representative query plans.
- [ ] Expose aggregate progress without counting the entire frontier on every request.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use in-memory queues as source of truth.
- Leases must have bounded duration and owner identity.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 064 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 064 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 064
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



---

---
id: '065'
title: Implement canonical URL normalization and scope policy
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '064'
status: pending
---

# Prompt 065 — Implement canonical URL normalization and scope policy

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `064`
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
ruby tracking/scripts/prompt_tracker.rb start 065
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

Create the deterministic URL identity and crawl-scope rules used by frontier deduplication, evidence and security checks.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Implement parsing/normalization for HTTP(S): lowercase/IDNA host, default ports, dot segments, percent-encoding policy, fragment removal and empty path.
2. Define query parameter ordering, tracking-parameter removal and configured allow/deny behavior without changing semantic values unexpectedly.
3. Keep fetch URL and normalized identity URL distinct when necessary.
4. Implement same-origin/allowed-host/path/include/exclude/depth policy with explicit reason codes.
5. Reject userinfo, control characters, ambiguous IP forms, invalid ports and unsupported schemes.
6. Create stable digest/fingerprint versioning so normalization changes do not silently corrupt old scans.
7. Document canonical normalization versus HTML canonical recommendation as separate concepts.

## Required verification

- Large table-driven normalization test corpus.
- Property-based/fuzz tests for parser crashes and idempotence.
- Scope boundary tests for sibling/lookalike domains and encoded paths.
- Backward-version fixture tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement parsing/normalization for HTTP(S): lowercase/IDNA host, default ports, dot segments, percent-encoding policy, fragment removal and empty path.
- [ ] Define query parameter ordering, tracking-parameter removal and configured allow/deny behavior without changing semantic values unexpectedly.
- [ ] Keep fetch URL and normalized identity URL distinct when necessary.
- [ ] Implement same-origin/allowed-host/path/include/exclude/depth policy with explicit reason codes.
- [ ] Reject userinfo, control characters, ambiguous IP forms, invalid ports and unsupported schemes.
- [ ] Create stable digest/fingerprint versioning so normalization changes do not silently corrupt old scans.
- [ ] Document canonical normalization versus HTML canonical recommendation as separate concepts.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never use regex alone to parse URLs.
- Do not treat an HTML canonical URL as authorization to leave crawl scope.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 065 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 065 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 065
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



---

---
id: '066'
title: Implement RFC 9309 robots parsing and policy
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '065'
status: pending
---

# Prompt 066 — Implement RFC 9309 robots parsing and policy

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `065`
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
ruby tracking/scripts/prompt_tracker.rb start 066
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

Parse and evaluate robots rules reproducibly while explaining that robots exclusion is crawl policy, not authorization or data protection.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Implement or integrate a maintained parser validated against RFC 9309 semantics for user-agent groups, allow/disallow precedence, percent encoding and file size/redirect/error limits.
2. Define the SearchOps user-agent token and HTTP identification/contact policy.
3. Cache robots responses per scan/origin with retrieval status, timestamp and artifact hash.
4. Evaluate each URL with an explicit allow/deny/unknown reason and record robots source version.
5. Define behavior for unavailable, 4xx, 5xx, timeout, oversized and malformed robots responses according to documented policy.
6. Support customer setting to respect robots by default; any verified-owner override must be explicit, plan/policy controlled and still subject to network safety.
7. Parse sitemap directives for discovery without treating them as trusted/safe.
8. Create customer-facing explanation that robots is not access control.

## Required verification

- RFC/example fixture tests and precedence cases.
- Response-status/redirect/size/error behavior tests.
- Security tests for malicious sitemap URLs in robots.
- Rule/output provenance tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement or integrate a maintained parser validated against RFC 9309 semantics for user-agent groups, allow/disallow precedence, percent encoding and file size/redirect/error limits.
- [ ] Define the SearchOps user-agent token and HTTP identification/contact policy.
- [ ] Cache robots responses per scan/origin with retrieval status, timestamp and artifact hash.
- [ ] Evaluate each URL with an explicit allow/deny/unknown reason and record robots source version.
- [ ] Define behavior for unavailable, 4xx, 5xx, timeout, oversized and malformed robots responses according to documented policy.
- [ ] Support customer setting to respect robots by default; any verified-owner override must be explicit, plan/policy controlled and still subject to network safety.
- [ ] Parse sitemap directives for discovery without treating them as trusted/safe.
- [ ] Create customer-facing explanation that robots is not access control.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Robots permission never bypasses SSRF/network policy.
- Do not claim blocked URLs are absent from search indexes.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 066 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 066 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 066
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



---

---
id: '067'
title: Implement sitemap discovery and bounded XML parsing
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '066'
status: pending
---

# Prompt 067 — Implement sitemap discovery and bounded XML parsing

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `066`
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
ruby tracking/scripts/prompt_tracker.rb start 067
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

Discover and parse sitemap/index files safely, incrementally and within configured origin, size, count and recursion limits.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Discover configured sitemap URLs and robots sitemap directives, then optionally standard well-known candidates according to policy.
2. Fetch through the safe HTTP boundary and validate every destination/redirect.
3. Parse XML with a hardened streaming parser that disables external entities/network access and bounds bytes, entries, nesting and index recursion.
4. Support sitemap index, URL set, gzip only within decompression limits, `lastmod` provenance and parse warnings.
5. Normalize/deduplicate discovered URLs and apply crawl scope before frontier insertion.
6. Record sitemap graph/artifacts/status for SEO rules.
7. Handle malformed, partial and circular indexes without crashing the scan.
8. Meter fetches and keep per-scan counters.

## Required verification

- Fixtures for valid index/urlset/gzip, malformed XML, XXE attempt and decompression bomb.
- Limit/circular recursion tests.
- Out-of-scope/private redirect tests.
- Duplicate/frontier insertion tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Discover configured sitemap URLs and robots sitemap directives, then optionally standard well-known candidates according to policy.
- [ ] Fetch through the safe HTTP boundary and validate every destination/redirect.
- [ ] Parse XML with a hardened streaming parser that disables external entities/network access and bounds bytes, entries, nesting and index recursion.
- [ ] Support sitemap index, URL set, gzip only within decompression limits, `lastmod` provenance and parse warnings.
- [ ] Normalize/deduplicate discovered URLs and apply crawl scope before frontier insertion.
- [ ] Record sitemap graph/artifacts/status for SEO rules.
- [ ] Handle malformed, partial and circular indexes without crashing the scan.
- [ ] Meter fetches and keep per-scan counters.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never enable XML external entities.
- A URL appearing in a sitemap is not proof it is safe or owned.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 067 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 067 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 067
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



---

---
id: 068
title: Implement the SSRF-safe destination resolver and connection policy
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '067'
status: pending
---

# Prompt 068 — Implement the SSRF-safe destination resolver and connection policy

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `067`
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
ruby tracking/scripts/prompt_tracker.rb start 068
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

Build the central security boundary that resolves and authorizes every crawler/browser outbound destination, including every redirect and resource request.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Create a destination-policy service for HTTP(S) URLs that canonicalizes hostname, resolves A/AAAA records and rejects loopback, private, link-local, multicast, unspecified, documentation/reserved and cloud metadata destinations.
2. Handle IPv4-in-IPv6, integer/octal/hex-like forms rejected by the parser, zone identifiers, IDNA and trailing-dot edge cases.
3. Return approved IP set/port and require the HTTP transport to connect consistently with validated resolution while preserving Host/SNI.
4. Re-resolve and revalidate every redirect hop; cap hops and reject scheme/credential/origin policy violations.
5. Mitigate DNS rebinding/TOCTOU with transport-level controls and network egress defense in depth.
6. Record a safe denial reason and resolution provenance without logging sensitive DNS payloads.
7. Create a local malicious DNS/HTTP fixture suite.
8. Make direct target HTTP clients inaccessible by architecture convention/check.

## Required verification

- Comprehensive IPv4/IPv6/private/reserved test matrix.
- DNS rebinding and public-to-private redirect tests asserting no forbidden connection.
- Host/SNI/approved-IP transport tests.
- Fuzz/property tests and security CI integration.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a destination-policy service for HTTP(S) URLs that canonicalizes hostname, resolves A/AAAA records and rejects loopback, private, link-local, multicast, unspecified, documentation/reserved and cloud metadata destinations.
- [ ] Handle IPv4-in-IPv6, integer/octal/hex-like forms rejected by the parser, zone identifiers, IDNA and trailing-dot edge cases.
- [ ] Return approved IP set/port and require the HTTP transport to connect consistently with validated resolution while preserving Host/SNI.
- [ ] Re-resolve and revalidate every redirect hop; cap hops and reject scheme/credential/origin policy violations.
- [ ] Mitigate DNS rebinding/TOCTOU with transport-level controls and network egress defense in depth.
- [ ] Record a safe denial reason and resolution provenance without logging sensitive DNS payloads.
- [ ] Create a local malicious DNS/HTTP fixture suite.
- [ ] Make direct target HTTP clients inaccessible by architecture convention/check.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- This is a security-critical prompt: do not approximate IP classification.
- Application validation must be backed by infrastructure egress restrictions.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 068 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 068 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 068
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



---

---
id: 069
title: Implement the bounded HTTP fetcher and redirect handling
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 068
status: pending
---

# Prompt 069 — Implement the bounded HTTP fetcher and redirect handling

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `068`
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
ruby tracking/scripts/prompt_tracker.rb start 069
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

Create the crawler HTTP transport on top of approved destinations with strict resource limits, provenance and safe retry semantics.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Implement GET/HEAD behavior using only the destination resolver's approved connection plan.
2. Set connect/TLS/header/body/total deadlines, maximum header/body size, decompression ratio/bytes and supported content encodings.
3. Validate TLS by default and record categorized failures; do not add global disable-verification options.
4. Follow redirects manually through revalidation and record each hop/status/location/timing.
5. Stream/hash artifacts without loading unbounded bodies in memory.
6. Normalize response metadata, media type/charset and fetch outcome; treat misleading content types defensively.
7. Define retries only for safe transient failures with bounded attempts/backoff and scan cancellation checks.
8. Use an explicit, honest SearchOps user agent and optional contact URL.

## Required verification

- Timeout/slowloris/oversized/decompression/redirect-loop tests.
- TLS/certificate failure tests using local fixtures.
- Cancellation and retry/idempotency tests.
- Memory/streaming test on bounded large body.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement GET/HEAD behavior using only the destination resolver's approved connection plan.
- [ ] Set connect/TLS/header/body/total deadlines, maximum header/body size, decompression ratio/bytes and supported content encodings.
- [ ] Validate TLS by default and record categorized failures; do not add global disable-verification options.
- [ ] Follow redirects manually through revalidation and record each hop/status/location/timing.
- [ ] Stream/hash artifacts without loading unbounded bodies in memory.
- [ ] Normalize response metadata, media type/charset and fetch outcome; treat misleading content types defensively.
- [ ] Define retries only for safe transient failures with bounded attempts/backoff and scan cancellation checks.
- [ ] Use an explicit, honest SearchOps user agent and optional contact URL.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No global TLS verification bypass.
- Do not automatically submit forms, authenticate or execute JavaScript.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 069 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 069 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 069
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



---

---
id: '070'
title: Implement private artifact storage and lifecycle
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 069
status: pending
---

# Prompt 070 — Implement private artifact storage and lifecycle

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `069`
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
ruby tracking/scripts/prompt_tracker.rb start 070
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

Store crawl/render/report artifacts in S3-compatible object storage with tenant-safe metadata, authorization and retention.

## Required references

- `docs/03_ERD.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/adr/0005_object_storage_for_large_artifacts.md`

## Required work

1. Define artifact metadata with organization/project/scan/source, kind, media type, byte count, content hash, storage key, encryption/version and retention state.
2. Implement provider-neutral artifact store adapter plus local/test fake.
3. Stream uploads/downloads; generate opaque keys without raw URL/query/customer names.
4. Use private objects and short-lived signed retrieval only after current authorization.
5. Deduplicate by content hash only within safe tenant/security boundaries; do not create cross-tenant side channels.
6. Implement retention expiry, deletion queue, missing-object/orphan reconciliation and legal-hold placeholder policy.
7. Redact/sanitize downloadable filenames and response headers.
8. Add storage metrics and cost attribution.

## Required verification

- Adapter contract tests including partial upload/failure/retry.
- Cross-tenant signed URL and metadata tests.
- Retention/deletion/idempotency reconciliation tests.
- Secret/key/URL leakage tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define artifact metadata with organization/project/scan/source, kind, media type, byte count, content hash, storage key, encryption/version and retention state.
- [ ] Implement provider-neutral artifact store adapter plus local/test fake.
- [ ] Stream uploads/downloads; generate opaque keys without raw URL/query/customer names.
- [ ] Use private objects and short-lived signed retrieval only after current authorization.
- [ ] Deduplicate by content hash only within safe tenant/security boundaries; do not create cross-tenant side channels.
- [ ] Implement retention expiry, deletion queue, missing-object/orphan reconciliation and legal-hold placeholder policy.
- [ ] Redact/sanitize downloadable filenames and response headers.
- [ ] Add storage metrics and cost attribution.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No public bucket/object ACL.
- Do not store large artifact bodies in PostgreSQL.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 070 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 070 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 070
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



---

---
id: '071'
title: Implement host politeness, concurrency and rate controls
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '070'
status: pending
---

# Prompt 071 — Implement host politeness, concurrency and rate controls

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `070`
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
ruby tracking/scripts/prompt_tracker.rb start 071
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

Enforce fair, bounded crawl pressure per host, organization, scan and global fleet using PostgreSQL-coordinated controls.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`

## Required work

1. Define global, organization-plan, scan and host concurrency/rate limits with the most restrictive effective value.
2. Implement host-key normalization including scheme/hostname/port and safe coordination across workers.
3. Use token/leasing or scheduled-next-fetch state in PostgreSQL with atomic acquisition and expiry.
4. Respect configured delay and Retry-After/provider response signals within bounds.
5. Prevent one tenant/host from starving others through fair lease selection.
6. Back off on 429/503/network failures without infinite scan duration.
7. Expose customer-visible throttled state and operator metrics.
8. Add emergency global/host kill switches that are audited and not tenant-controllable.

## Required verification

- Concurrent workers prove host/global limits are never exceeded beyond documented tolerance.
- Fairness tests across two organizations and hosts.
- Retry-After/backoff/cancellation tests.
- Stale permit recovery tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define global, organization-plan, scan and host concurrency/rate limits with the most restrictive effective value.
- [ ] Implement host-key normalization including scheme/hostname/port and safe coordination across workers.
- [ ] Use token/leasing or scheduled-next-fetch state in PostgreSQL with atomic acquisition and expiry.
- [ ] Respect configured delay and Retry-After/provider response signals within bounds.
- [ ] Prevent one tenant/host from starving others through fair lease selection.
- [ ] Back off on 429/503/network failures without infinite scan duration.
- [ ] Expose customer-visible throttled state and operator metrics.
- [ ] Add emergency global/host kill switches that are audited and not tenant-controllable.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not rely only on per-process memory counters.
- Never let a paid plan bypass global safety caps.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 071 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 071 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 071
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



---

---
id: '072'
title: Integrate weighted credit reservation with scan execution
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '071'
status: pending
---

# Prompt 072 — Integrate weighted credit reservation with scan execution

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `071`
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
ruby tracking/scripts/prompt_tracker.rb start 072
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

Connect static fetch, render, Lighthouse and artifact operations to the usage ledger without double charging or unbounded cost.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Define exact meter/weight lookup from versioned configuration and include it in scan snapshots.
2. Reserve estimated scan credits at admission and charge/finalize actual operations through idempotent source keys.
3. Track HTTP fetch attempts vs successful billable fetches according to documented policy.
4. Reserve incremental credits before expanding beyond estimate; pause/cancel safely if unavailable.
5. Release unused reservation at terminal scan state and recover after crashes.
6. Expose per-scan cost breakdown and organization usage aggregation.
7. Ensure provider/internal retries do not create duplicate usage events.
8. Add audit/support adjustment path through compensating events only.

## Required verification

- End-to-end scan reservation → operations → finalization tests.
- Retry/duplicate/cancellation/failure tests.
- Mid-scan quota exhaustion/pause behavior tests.
- Concurrent scans near quota boundary tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define exact meter/weight lookup from versioned configuration and include it in scan snapshots.
- [ ] Reserve estimated scan credits at admission and charge/finalize actual operations through idempotent source keys.
- [ ] Track HTTP fetch attempts vs successful billable fetches according to documented policy.
- [ ] Reserve incremental credits before expanding beyond estimate; pause/cancel safely if unavailable.
- [ ] Release unused reservation at terminal scan state and recover after crashes.
- [ ] Expose per-scan cost breakdown and organization usage aggregation.
- [ ] Ensure provider/internal retries do not create duplicate usage events.
- [ ] Add audit/support adjustment path through compensating events only.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not charge simply for enqueuing a job.
- Credit weights are versioned facts of the scan, not mutable global lookups after execution.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 072 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 072 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 072
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



---

---
id: '073'
title: Implement static crawl orchestration
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '072'
status: pending
---

# Prompt 073 — Implement static crawl orchestration

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `072`
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
ruby tracking/scripts/prompt_tracker.rb start 073
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

Coordinate robots, sitemap/frontier discovery, bounded HTTP fetches, extraction, retries and terminal scan accounting into the first working crawl.

## Required references

- `docs/02_ARCHITECTURE.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Implement orchestration jobs/services that transition admitted scan to running, initialize robots/sitemaps/start URLs and lease frontier batches.
2. Fetch through the safe transport, persist normalized response/page snapshot metadata and artifact references.
3. Enqueue extraction/discovery idempotently and stop at settings/plan/global URL/depth/credit limits.
4. Check cancellation between units and prevent new work after cancel request.
5. Aggregate progress and determine terminal state from durable counters/states, including partial completion.
6. Handle worker crashes, stale leases and poison URLs without losing the scan.
7. Emit structured events/Turbo updates at bounded frequency.
8. Create manual scan UI from request through live progress and terminal summary.

## Required verification

- End-to-end local-site crawl system/integration test.
- Crash/retry/cancellation/limit/quota tests.
- Duplicate job/frontier idempotency tests.
- Cross-tenant scan/job/artifact tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement orchestration jobs/services that transition admitted scan to running, initialize robots/sitemaps/start URLs and lease frontier batches.
- [ ] Fetch through the safe transport, persist normalized response/page snapshot metadata and artifact references.
- [ ] Enqueue extraction/discovery idempotently and stop at settings/plan/global URL/depth/credit limits.
- [ ] Check cancellation between units and prevent new work after cancel request.
- [ ] Aggregate progress and determine terminal state from durable counters/states, including partial completion.
- [ ] Handle worker crashes, stale leases and poison URLs without losing the scan.
- [ ] Emit structured events/Turbo updates at bounded frequency.
- [ ] Create manual scan UI from request through live progress and terminal summary.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No target network call from web process.
- Do not mark scan complete while durable runnable frontier work remains.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 073 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 073 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 073
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



---

---
id: '074'
title: Implement HTML extraction and internal link graph
phase: 06 Safe crawling and rendering
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '073'
status: pending
---

# Prompt 074 — Implement HTML extraction and internal link graph

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `073`
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
ruby tracking/scripts/prompt_tracker.rb start 074
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

Extract normalized page facts and links from untrusted HTML for rule evaluation and graph analysis without executing scripts.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/03_ERD.md`

## Required work

1. Parse bounded HTML using a maintained tolerant parser and capture title, meta directives, headings, canonical, hreflang, links, images, structured-data blocks and language hints.
2. Resolve relative URLs against the effective document/base URL using explicit rules and apply normalization/scope before discovery.
3. Persist page snapshots/facts and directed internal/external link edges with source locator, rel, anchor summary and nofollow metadata.
4. Bound node counts, attribute/text lengths and structured data size; sanitize all displayed snippets.
5. Record parser/version/content hash and distinguish absent, malformed and unavailable facts.
6. Detect duplicate edges efficiently and prepare graph read models for broken/orphan/internal depth rules.
7. Do not store full visible text in PostgreSQL unless a bounded derived representation is required.
8. Add extraction fixtures for malformed/adversarial HTML.

## Required verification

- Fixture tests for relative/base/canonical/hreflang/link/image/schema extraction.
- Malformed/huge DOM/attribute/XSS display tests.
- URL discovery and graph deduplication tests.
- Performance test on a large bounded document.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Parse bounded HTML using a maintained tolerant parser and capture title, meta directives, headings, canonical, hreflang, links, images, structured-data blocks and language hints.
- [ ] Resolve relative URLs against the effective document/base URL using explicit rules and apply normalization/scope before discovery.
- [ ] Persist page snapshots/facts and directed internal/external link edges with source locator, rel, anchor summary and nofollow metadata.
- [ ] Bound node counts, attribute/text lengths and structured data size; sanitize all displayed snippets.
- [ ] Record parser/version/content hash and distinguish absent, malformed and unavailable facts.
- [ ] Detect duplicate edges efficiently and prepare graph read models for broken/orphan/internal depth rules.
- [ ] Do not store full visible text in PostgreSQL unless a bounded derived representation is required.
- [ ] Add extraction fixtures for malformed/adversarial HTML.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Parsing HTML is not authorization to fetch every referenced URL.
- Never render unescaped evidence snippets.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 074 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 074 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 074
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



---

---
id: '075'
title: Implement dedicated Chromium/Ferrum render workers
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '074'
status: pending
---

# Prompt 075 — Implement dedicated Chromium/Ferrum render workers

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `074`
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
ruby tracking/scripts/prompt_tracker.rb start 075
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

Add opt-in JavaScript rendering as an isolated, metered worker capability with reproducible provenance and no execution in web/default workers.

## Required references

- `docs/02_ARCHITECTURE.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0007_isolated_browser_workers.md`

## Required work

1. Install/pin Chromium and Ferrum-compatible dependencies and record exact versions in image/result provenance.
2. Define render job input from an approved static-fetch URL/destination and scan snapshot.
3. Launch/reuse browser safely according to isolation policy, creating a fresh incognito/context/page per target.
4. Navigate with strict wall-clock/request/byte limits, wait strategy and cancellation.
5. Capture final URL, DOM artifact, screenshot when enabled, console/page errors, timing and selected network summary.
6. Run the same extraction pipeline over rendered DOM and persist source-vs-render relationships.
7. Charge weighted credits idempotently and cap sampling per settings/plan.
8. Create dedicated queue/process command and health metrics.

## Required verification

- End-to-end render of a local JavaScript fixture.
- Queue-routing test proving render job never executes in web/default worker.
- Timeout/crash/cancellation/credit tests.
- Version/provenance and artifact tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Install/pin Chromium and Ferrum-compatible dependencies and record exact versions in image/result provenance.
- [ ] Define render job input from an approved static-fetch URL/destination and scan snapshot.
- [ ] Launch/reuse browser safely according to isolation policy, creating a fresh incognito/context/page per target.
- [ ] Navigate with strict wall-clock/request/byte limits, wait strategy and cancellation.
- [ ] Capture final URL, DOM artifact, screenshot when enabled, console/page errors, timing and selected network summary.
- [ ] Run the same extraction pipeline over rendered DOM and persist source-vs-render relationships.
- [ ] Charge weighted credits idempotently and cap sampling per settings/plan.
- [ ] Create dedicated queue/process command and health metrics.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not pass application/provider secrets into browser environment.
- Do not enable arbitrary browser flags supplied by customers.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 075 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 075 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 075
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



---

---
id: '076'
title: Harden browser network interception and sandbox limits
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '075'
status: pending
---

# Prompt 076 — Harden browser network interception and sandbox limits

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `075`
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
ruby tracking/scripts/prompt_tracker.rb start 076
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

Prevent rendered pages and their subresources from reaching forbidden networks, abusing browser capabilities or persisting state across customers.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/adr/0007_isolated_browser_workers.md`

## Required work

1. Intercept every browser request, normalize/resolve destination and enforce the same public-network/origin policy before continuation.
2. Block private/link-local/metadata, unsupported schemes, downloads, popups, permission prompts, WebRTC/local discovery and unexpected external hosts according to scan policy.
3. Use network/container egress restrictions as defense in depth; document exact rules and test from inside the render runtime.
4. Disable or isolate service workers, persistent profiles, shared cookies/cache/storage and cross-job browser state.
5. Set CPU/memory/process/file/network request limits and kill the page/browser cleanly on breach.
6. Sanitize console/network errors and artifact content metadata.
7. Detect browser crash loops and quarantine/restart workers with bounded retries.
8. Add a required browser-security CI suite using malicious fixture pages.

## Required verification

- Subresource redirect/DNS rebinding/private-IP tests asserting blocked connection.
- Cross-context cookie/storage/service-worker leakage tests.
- Popup/download/permission/WebRTC tests.
- Resource exhaustion/crash/recovery tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Intercept every browser request, normalize/resolve destination and enforce the same public-network/origin policy before continuation.
- [ ] Block private/link-local/metadata, unsupported schemes, downloads, popups, permission prompts, WebRTC/local discovery and unexpected external hosts according to scan policy.
- [ ] Use network/container egress restrictions as defense in depth; document exact rules and test from inside the render runtime.
- [ ] Disable or isolate service workers, persistent profiles, shared cookies/cache/storage and cross-job browser state.
- [ ] Set CPU/memory/process/file/network request limits and kill the page/browser cleanly on breach.
- [ ] Sanitize console/network errors and artifact content metadata.
- [ ] Detect browser crash loops and quarantine/restart workers with bounded retries.
- [ ] Add a required browser-security CI suite using malicious fixture pages.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Application interception alone is insufficient; verify egress defense.
- Do not weaken Chromium sandbox casually to make containers start.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 076 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 076 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 076
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



---

---
id: '077'
title: Implement scan cancellation, recovery and targeted rescan
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '076'
status: pending
---

# Prompt 077 — Implement scan cancellation, recovery and targeted rescan

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `076`
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
ruby tracking/scripts/prompt_tracker.rb start 077
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

Complete operational scan control so expensive asynchronous work can stop, recover after failures and recheck a bounded set of URLs safely.

## Required references

- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/03_ERD.md`

## Required work

1. Implement cooperative cancellation token/state checks for frontier, fetch, extraction, render and downstream analysis jobs.
2. Stop leasing new work, terminate active browser pages within a bound and finalize/release credits accurately.
3. Implement stale scan/lease/job recovery after process loss with idempotent resumption or terminal failure according to attempt policy.
4. Create targeted rescan request for selected findings/URLs using the same authorization, verification, safety and quota boundary.
5. Link targeted scan to source issue/finding and preserve independent snapshots/provenance.
6. Provide UI/admin operations for cancel, retry eligible failures and diagnose stuck work.
7. Add watchdog recurring task and alert metrics.
8. Document operator recovery runbook.

## Required verification

- Cancellation at every pipeline stage.
- Process-crash/stale lease recovery test.
- Targeted-rescan cross-tenant/quota/idempotency tests.
- Credit finalization/release consistency tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement cooperative cancellation token/state checks for frontier, fetch, extraction, render and downstream analysis jobs.
- [ ] Stop leasing new work, terminate active browser pages within a bound and finalize/release credits accurately.
- [ ] Implement stale scan/lease/job recovery after process loss with idempotent resumption or terminal failure according to attempt policy.
- [ ] Create targeted rescan request for selected findings/URLs using the same authorization, verification, safety and quota boundary.
- [ ] Link targeted scan to source issue/finding and preserve independent snapshots/provenance.
- [ ] Provide UI/admin operations for cancel, retry eligible failures and diagnose stuck work.
- [ ] Add watchdog recurring task and alert metrics.
- [ ] Document operator recovery runbook.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not implement forceful database state edits as normal recovery.
- A retry must not overwrite the historical failed scan.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 077 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 077 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 077
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



---

---
id: 078
title: Implement the versioned SEO rule registry and result contract
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '077'
status: pending
---

# Prompt 078 — Implement the versioned SEO rule registry and result contract

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `077`
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
ruby tracking/scripts/prompt_tracker.rb start 078
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

Create the deterministic rule-engine foundation that loads validated rule metadata, declares inputs/applicability and emits explainable versioned results.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `config_blueprints/seo_rules.yml`
- `schemas/seo_rule_result.schema.json`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Create a rule registry with stable key, semantic implementation version, category, supported property/source types, required inputs, default severity/confidence, title, description, remediation and verification method.
2. Load/validate `config_blueprints/seo_rules.yml`; detect duplicate/unknown/deprecated keys and unsafe removal of rules present in historical findings.
3. Define the normalized rule result matching `schemas/seo_rule_result.schema.json`, including applicability and unknown—not only pass/fail.
4. Create a base rule interface that is pure over versioned input snapshots and cannot perform arbitrary network/database writes.
5. Implement deterministic evidence locators/fingerprints and bounded sanitized values.
6. Record engine/catalog checksum and source versions with each analysis run.
7. Create shared contract tests and a fixture/golden-output workflow.
8. Expose rule catalog/read-only details in the application.

## Required verification

- Validate all 96 configured rule definitions.
- Run shared contract tests against a sample rule.
- Test deterministic output/fingerprint across repeated runs.
- Test historical rule-removal/version-change safety.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a rule registry with stable key, semantic implementation version, category, supported property/source types, required inputs, default severity/confidence, title, description, remediation and verification method.
- [ ] Load/validate `config_blueprints/seo_rules.yml`; detect duplicate/unknown/deprecated keys and unsafe removal of rules present in historical findings.
- [ ] Define the normalized rule result matching `schemas/seo_rule_result.schema.json`, including applicability and unknown—not only pass/fail.
- [ ] Create a base rule interface that is pure over versioned input snapshots and cannot perform arbitrary network/database writes.
- [ ] Implement deterministic evidence locators/fingerprints and bounded sanitized values.
- [ ] Record engine/catalog checksum and source versions with each analysis run.
- [ ] Create shared contract tests and a fixture/golden-output workflow.
- [ ] Expose rule catalog/read-only details in the application.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Rules do not mutate workflow state directly.
- Never reduce unavailable input to an automatic pass.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 078 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 078 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 078
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



---

---
id: 079
title: Implement HTTP status and redirect rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 078
status: pending
---

# Prompt 079 — Implement HTTP status and redirect rules

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `078`
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
ruby tracking/scripts/prompt_tracker.rb start 079
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

Implement the first rule family over fetch and redirect-chain snapshots with clear severity, evidence and verification.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Implement configured rules for unreachable URLs, 4xx/5xx responses, soft-error indicators only where evidence is explicit, redirect chains, loops, temporary/permanent mismatch and HTTPS downgrade.
2. Use final and hop response facts from the fetcher; never refetch inside a rule.
3. Differentiate internal entry URL, redirect hop and final URL subjects.
4. Create deterministic fingerprints that remain stable when irrelevant timing/header data changes.
5. Provide bounded evidence showing statuses/locations and remediation grounded in the observed chain.
6. Mark rules not applicable or unknown when required data is missing.
7. Add rule catalog version/source notes and UI grouping.

## Required verification

- Golden fixtures for success, each failure and malformed/incomplete chain.
- Fingerprint stability tests.
- Evidence escaping/size tests.
- Batch execution performance test.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement configured rules for unreachable URLs, 4xx/5xx responses, soft-error indicators only where evidence is explicit, redirect chains, loops, temporary/permanent mismatch and HTTPS downgrade.
- [ ] Use final and hop response facts from the fetcher; never refetch inside a rule.
- [ ] Differentiate internal entry URL, redirect hop and final URL subjects.
- [ ] Create deterministic fingerprints that remain stable when irrelevant timing/header data changes.
- [ ] Provide bounded evidence showing statuses/locations and remediation grounded in the observed chain.
- [ ] Mark rules not applicable or unknown when required data is missing.
- [ ] Add rule catalog version/source notes and UI grouping.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not label a transient fetch failure as a permanent search-engine outcome.
- Do not expose sensitive query values in evidence.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 079 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 079 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 079
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



---

---
id: 080
title: Implement robots, indexability and sitemap rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 079
status: pending
---

# Prompt 080 — Implement robots, indexability and sitemap rules

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `079`
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
ruby tracking/scripts/prompt_tracker.rb start 080
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

Evaluate crawl/index directives and sitemap consistency from captured HTTP, robots, HTML and sitemap facts without overstating search-engine behavior.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Implement configured robots availability/syntax/directive and URL allow/deny findings from the recorded RFC 9309 policy.
2. Implement robots meta and `X-Robots-Tag` conflict/indexability findings with explicit source precedence according to documented behavior.
3. Implement sitemap missing/unreachable/malformed, non-indexable URL included, canonical target mismatch and discovered-not-in-sitemap rules where data is sufficient.
4. Distinguish crawler accessibility, declared indexability and actual Google-known indexed state.
5. Preserve per-source evidence and mark unknown when headers/body/provider data are absent.
6. Handle wildcard/user-agent groups and duplicate/conflicting directives deterministically.
7. Create overview read models for indexable/non-indexable URL counts.

## Required verification

- Golden fixtures covering conflicting header/meta/robots/sitemap combinations.
- Unknown/not-applicable tests.
- Rule explanations avoid claims that robots guarantees deindexing.
- Performance test on a large sitemap/page batch.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement configured robots availability/syntax/directive and URL allow/deny findings from the recorded RFC 9309 policy.
- [ ] Implement robots meta and `X-Robots-Tag` conflict/indexability findings with explicit source precedence according to documented behavior.
- [ ] Implement sitemap missing/unreachable/malformed, non-indexable URL included, canonical target mismatch and discovered-not-in-sitemap rules where data is sufficient.
- [ ] Distinguish crawler accessibility, declared indexability and actual Google-known indexed state.
- [ ] Preserve per-source evidence and mark unknown when headers/body/provider data are absent.
- [ ] Handle wildcard/user-agent groups and duplicate/conflicting directives deterministically.
- [ ] Create overview read models for indexable/non-indexable URL counts.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Robots exclusion is not authentication.
- Do not call a page indexed or deindexed without provider evidence.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 080 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 080 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 080
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



---

---
id: 081
title: Implement canonical and hreflang rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 080
status: pending
---

# Prompt 081 — Implement canonical and hreflang rules

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `080`
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
ruby tracking/scripts/prompt_tracker.rb start 081
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

Analyze canonical clusters and internationalization declarations using normalized graph facts and explicit uncertainty.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/03_ERD.md`

## Required work

1. Implement missing/multiple/malformed/out-of-scope/canonical-to-error/canonical-chain/canonical-loop and inconsistent canonical rules.
2. Build canonical graph components from scan snapshots without treating declared canonical as crawl authorization.
3. Implement hreflang syntax, self-reference, reciprocal return-link, language/region code, target status/indexability and canonical consistency rules.
4. Support HTTP header and HTML link sources with provenance.
5. Handle partial scan coverage by reducing confidence or returning unknown rather than asserting a broken return link.
6. Create cluster-level subjects/fingerprints and evidence bounded to representative URLs with downloadable detail.
7. Prepare canonical/hreflang overview UI.

## Required verification

- Graph fixtures for chain, loop, cluster and partial coverage.
- Hreflang reciprocal/code/canonical combination fixtures.
- Scope/security tests for external targets.
- Determinism/performance tests on representative graphs.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement missing/multiple/malformed/out-of-scope/canonical-to-error/canonical-chain/canonical-loop and inconsistent canonical rules.
- [ ] Build canonical graph components from scan snapshots without treating declared canonical as crawl authorization.
- [ ] Implement hreflang syntax, self-reference, reciprocal return-link, language/region code, target status/indexability and canonical consistency rules.
- [ ] Support HTTP header and HTML link sources with provenance.
- [ ] Handle partial scan coverage by reducing confidence or returning unknown rather than asserting a broken return link.
- [ ] Create cluster-level subjects/fingerprints and evidence bounded to representative URLs with downloadable detail.
- [ ] Prepare canonical/hreflang overview UI.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fetch external canonical/hreflang targets outside approved scan scope just to complete a rule.
- Confidence must reflect incomplete crawl coverage.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 081 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 081 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 081
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



---

---
id: 082
title: Implement metadata, content-structure and mobile rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 081
status: pending
---

# Prompt 082 — Implement metadata, content-structure and mobile rules

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `081`
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
ruby tracking/scripts/prompt_tracker.rb start 082
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

Implement explainable on-page rules over static/rendered snapshots while avoiding arbitrary ranking formulas and unsafe content display.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/01_PRD_V1.md`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Implement configured title, description, H1/heading, language, viewport and basic content-presence rules.
2. Use documented configurable thresholds as heuristic metadata, not provider guarantees; version threshold changes.
3. Detect duplicate titles/descriptions through normalized bounded hashes and representative clusters.
4. Compare static and rendered metadata only when both sources exist.
5. Sanitize/truncate evidence and never render captured HTML as trusted markup.
6. Distinguish exact absence, empty value, duplicate and unknown/unavailable source.
7. Create category summary/read models without one opaque overall ranking score.
8. Document limitations for client-rendered/personalized content.

## Required verification

- Golden fixtures for boundaries, duplicates, malformed markup and missing inputs.
- XSS/evidence escaping tests.
- Threshold versioning tests.
- Cluster performance tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement configured title, description, H1/heading, language, viewport and basic content-presence rules.
- [ ] Use documented configurable thresholds as heuristic metadata, not provider guarantees; version threshold changes.
- [ ] Detect duplicate titles/descriptions through normalized bounded hashes and representative clusters.
- [ ] Compare static and rendered metadata only when both sources exist.
- [ ] Sanitize/truncate evidence and never render captured HTML as trusted markup.
- [ ] Distinguish exact absence, empty value, duplicate and unknown/unavailable source.
- [ ] Create category summary/read models without one opaque overall ranking score.
- [ ] Document limitations for client-rendered/personalized content.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not claim an ideal title/description length guarantees ranking.
- Do not store or display unbounded page text.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 082 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 082 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 082
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



---

---
id: 083
title: Implement internal link and image rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 082
status: pending
---

# Prompt 083 — Implement internal link and image rules

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `082`
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
ruby tracking/scripts/prompt_tracker.rb start 083
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

Analyze the internal graph and image facts for broken links, orphan-risk indicators and accessibility/performance-relevant metadata.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/03_ERD.md`

## Required work

1. Implement broken internal link, redirected internal link, excessive chain, nofollow inconsistency and depth-related rules using captured graph/fetch results.
2. Define orphan-risk only relative to known entry sources/sitemap/crawl coverage and surface that limitation.
3. Implement missing/empty alt, missing dimensions, oversized artifact when measured and lazy-loading misuse rules from available facts.
4. Deduplicate cluster-level findings and include representative source/target evidence.
5. Exclude mailto/tel/javascript/data and unsupported schemes according to explicit applicability.
6. Use bounded anchor/alt snippets and sanitize hostile values.
7. Create internal-link and image summary views with filters/export-ready read models.

## Required verification

- Graph fixtures for broken/redirect/orphan/depth scenarios.
- Coverage-confidence tests.
- Image rule boundary and unknown-byte-size tests.
- Evidence escaping and large-graph performance tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement broken internal link, redirected internal link, excessive chain, nofollow inconsistency and depth-related rules using captured graph/fetch results.
- [ ] Define orphan-risk only relative to known entry sources/sitemap/crawl coverage and surface that limitation.
- [ ] Implement missing/empty alt, missing dimensions, oversized artifact when measured and lazy-loading misuse rules from available facts.
- [ ] Deduplicate cluster-level findings and include representative source/target evidence.
- [ ] Exclude mailto/tel/javascript/data and unsupported schemes according to explicit applicability.
- [ ] Use bounded anchor/alt snippets and sanitize hostile values.
- [ ] Create internal-link and image summary views with filters/export-ready read models.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not infer true orphan status from an incomplete crawl as a certainty.
- Do not fetch arbitrary external images for size analysis without an approved policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 083 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 083 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 083
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



---

---
id: 084
title: Implement structured-data extraction and validation rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 083
status: pending
---

# Prompt 084 — Implement structured-data extraction and validation rules

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `083`
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
ruby tracking/scripts/prompt_tracker.rb start 084
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

Validate bounded JSON-LD/microdata/RDFa facts for syntax and supported search-feature requirements while preserving source/version provenance.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Parse JSON-LD with depth/key/string/byte limits and no remote context/network resolution.
2. Represent extracted structured data as normalized bounded facts and store full source only as protected artifact when needed.
3. Implement syntax, missing required/recommended property, invalid value/type, duplicate entity and mismatch-with-visible-content indicators where evidence supports them.
4. Separate schema.org vocabulary validity from a provider's supported rich-result eligibility.
5. Version provider-specific supported-type requirements and cite source/effective date in rule metadata.
6. Treat unknown/custom types safely and avoid marking extra schema as inherently beneficial.
7. Escape all values in UI and provide source locators.
8. Create fixture suite for malicious/deep/cyclic-like JSON and mixed markup.

## Required verification

- Valid/invalid/boundary golden fixtures.
- Depth/size/parser-bomb and no-network tests.
- Provider-version change tests.
- Visible-content mismatch tests with explicit confidence.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Parse JSON-LD with depth/key/string/byte limits and no remote context/network resolution.
- [ ] Represent extracted structured data as normalized bounded facts and store full source only as protected artifact when needed.
- [ ] Implement syntax, missing required/recommended property, invalid value/type, duplicate entity and mismatch-with-visible-content indicators where evidence supports them.
- [ ] Separate schema.org vocabulary validity from a provider's supported rich-result eligibility.
- [ ] Version provider-specific supported-type requirements and cite source/effective date in rule metadata.
- [ ] Treat unknown/custom types safely and avoid marking extra schema as inherently beneficial.
- [ ] Escape all values in UI and provide source locators.
- [ ] Create fixture suite for malicious/deep/cyclic-like JSON and mixed markup.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never resolve remote JSON-LD contexts.
- Do not promise rich results or ranking eligibility.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 084 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 084 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 084
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



---

---
id: 085
title: Implement source-versus-rendered parity rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 084
status: pending
---

# Prompt 085 — Implement source-versus-rendered parity rules

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `084`
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
ruby tracking/scripts/prompt_tracker.rb start 085
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

Compare static HTML and rendered DOM to detect JavaScript-dependent search visibility risks without assuming every difference is an error.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/adr/0007_isolated_browser_workers.md`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Create matched static/render snapshots using normalized URL, response lineage and scan version.
2. Implement configured parity rules for title, description, canonical, robots, headings, primary links, structured data and materially absent content.
3. Define normalization and significance thresholds per field; version them.
4. Classify additions, removals and conflicts, with lower confidence for nondeterministic/personalized pages.
5. Record browser/static provenance and bounded side-by-side evidence.
6. Identify render failure/timeout separately from content parity.
7. Create parity summary and per-URL diff UI.
8. Allow targeted re-render verification with quota.

## Required verification

- Fixtures for equivalent formatting, meaningful conflict, dynamic noise and missing snapshots.
- Deterministic diff/fingerprint tests.
- Evidence XSS/size tests.
- Targeted verification quota/idempotency tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create matched static/render snapshots using normalized URL, response lineage and scan version.
- [ ] Implement configured parity rules for title, description, canonical, robots, headings, primary links, structured data and materially absent content.
- [ ] Define normalization and significance thresholds per field; version them.
- [ ] Classify additions, removals and conflicts, with lower confidence for nondeterministic/personalized pages.
- [ ] Record browser/static provenance and bounded side-by-side evidence.
- [ ] Identify render failure/timeout separately from content parity.
- [ ] Create parity summary and per-URL diff UI.
- [ ] Allow targeted re-render verification with quota.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Differences are evidence, not automatic proof of indexing failure.
- Rules must not execute new browser work during analysis.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 085 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 085 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 085
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



---

---
id: 086
title: Implement AI crawler policy matrix
phase: 07 Rules, findings and issue workflow
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 085
status: pending
---

# Prompt 086 — Implement AI crawler policy matrix

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `085`
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
ruby tracking/scripts/prompt_tracker.rb start 086
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

Report explicit crawler-access policies for major configured bots while keeping search inclusion, training use and user-triggered fetch semantics separate.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Create versioned crawler-agent definitions from current official documentation, including distinct OpenAI agents where behavior differs.
2. Evaluate robots groups/directives for each configured agent plus generic user agent.
3. Show allow/deny/unknown at origin/path with exact matched rule and robots snapshot date.
4. Implement conflict/missing-policy findings as informational/recommendation levels rather than a fabricated GEO score.
5. Separate technical accessibility from likely citation, inclusion, ranking or training outcomes.
6. Allow catalog updates without rewriting historical reports by snapshotting agent definitions.
7. Create policy matrix UI and export data.
8. Add source/effective-date metadata.

## Required verification

- Robots precedence fixtures for multiple agents.
- Historical agent-definition version tests.
- Customer-facing language tests/snapshots avoiding guarantees.
- Unknown/unavailable robots behavior tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create versioned crawler-agent definitions from current official documentation, including distinct OpenAI agents where behavior differs.
- [ ] Evaluate robots groups/directives for each configured agent plus generic user agent.
- [ ] Show allow/deny/unknown at origin/path with exact matched rule and robots snapshot date.
- [ ] Implement conflict/missing-policy findings as informational/recommendation levels rather than a fabricated GEO score.
- [ ] Separate technical accessibility from likely citation, inclusion, ranking or training outcomes.
- [ ] Allow catalog updates without rewriting historical reports by snapshotting agent definitions.
- [ ] Create policy matrix UI and export data.
- [ ] Add source/effective-date metadata.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not conflate OAI-SearchBot, GPTBot and user-triggered agents.
- Do not claim access permission guarantees AI visibility.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 086 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 086 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 086
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



---

---
id: 087
title: Implement finding persistence, deduplication and occurrences
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 086
status: pending
---

# Prompt 087 — Implement finding persistence, deduplication and occurrences

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `086`
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
ruby tracking/scripts/prompt_tracker.rb start 087
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

Persist rule results as stable findings with per-scan occurrences, evidence lineage and lifecycle behavior across changing scans/rule versions.

## Required references

- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Create findings as organization/project/property-level identities and finding occurrences linked to scan, subject, rule key/version, outcome, evidence and timestamps.
2. Define deterministic fingerprint inputs and version; prevent cross-tenant collisions.
3. Upsert occurrences idempotently and update first/last seen/count/status without overwriting historical evidence.
4. Represent present, absent-in-latest, verification-pending, resolved-candidate, suppressed and reopened behavior explicitly.
5. Handle rule-version/fingerprint migrations conservatively.
6. Store large evidence as artifacts and bounded searchable summaries in PostgreSQL.
7. Create list/detail filters by severity/category/status/property/scan.
8. Add indexes/partition/retention strategy.

## Required verification

- First/repeat/disappear/reappear/idempotent occurrence tests.
- Rule-version and fingerprint migration tests.
- Concurrent upsert tests.
- Cross-tenant and high-volume query tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create findings as organization/project/property-level identities and finding occurrences linked to scan, subject, rule key/version, outcome, evidence and timestamps.
- [ ] Define deterministic fingerprint inputs and version; prevent cross-tenant collisions.
- [ ] Upsert occurrences idempotently and update first/last seen/count/status without overwriting historical evidence.
- [ ] Represent present, absent-in-latest, verification-pending, resolved-candidate, suppressed and reopened behavior explicitly.
- [ ] Handle rule-version/fingerprint migrations conservatively.
- [ ] Store large evidence as artifacts and bounded searchable summaries in PostgreSQL.
- [ ] Create list/detail filters by severity/category/status/property/scan.
- [ ] Add indexes/partition/retention strategy.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never overwrite prior scan evidence.
- Absence from a partial/failed scan is not automatic resolution.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 087 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 087 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 087
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



---

---
id: 088
title: Implement severity, confidence and priority scoring
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 087
status: pending
---

# Prompt 088 — Implement severity, confidence and priority scoring

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `087`
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
ruby tracking/scripts/prompt_tracker.rb start 088
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

Create transparent prioritization that combines rule severity, evidence confidence, affected scope/traffic, recurrence and effort without hiding raw facts.

## Required references

- `docs/01_PRD_V1.md`
- `docs/06_SEO_RULE_CATALOG.md`
- `docs/03_ERD.md`

## Required work

1. Define immutable value objects and versioned formula/configuration for severity weight, confidence, affected-page/traffic factor, recurrence and estimated effort.
2. Keep raw rule severity/confidence visible independently from computed priority.
3. Handle missing traffic/effort explicitly with documented neutral/default behavior.
4. Bound every factor and protect against outliers/manipulated provider data.
5. Persist score version and components with occurrence/read model so historical ordering is explainable.
6. Allow authorized project-level severity/effort adjustments as audited overlays, not mutation of rule truth.
7. Create sortable priority UI with explanation breakdown.
8. Add recalculation job for formula-version changes without rewriting occurrence facts.

## Required verification

- Table-driven scoring and boundary tests.
- Missing/outlier input tests.
- Historical score-version reproducibility.
- Authorization/audit tests for overrides.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define immutable value objects and versioned formula/configuration for severity weight, confidence, affected-page/traffic factor, recurrence and estimated effort.
- [ ] Keep raw rule severity/confidence visible independently from computed priority.
- [ ] Handle missing traffic/effort explicitly with documented neutral/default behavior.
- [ ] Bound every factor and protect against outliers/manipulated provider data.
- [ ] Persist score version and components with occurrence/read model so historical ordering is explainable.
- [ ] Allow authorized project-level severity/effort adjustments as audited overlays, not mutation of rule truth.
- [ ] Create sortable priority UI with explanation breakdown.
- [ ] Add recalculation job for formula-version changes without rewriting occurrence facts.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No single score may replace underlying evidence.
- Do not imply calculated priority equals guaranteed traffic/revenue impact.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 088 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 088 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 088
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



---

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



---

---
id: 090
title: Implement scan baselines, diffs and regressions
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 089
status: pending
---

# Prompt 090 — Implement scan baselines, diffs and regressions

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `089`
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
ruby tracking/scripts/prompt_tracker.rb start 090
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

Compare compatible scan snapshots to identify new, resolved, worsened and unchanged findings with explicit coverage/confidence.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Create baseline selection rules by project/property/environment/scan type/rule catalog and optional release.
2. Persist immutable comparison records with source/target scan IDs, versions, coverage metrics and completion quality.
3. Classify new, resolved-candidate, recurring, severity/priority changed and evidence changed findings.
4. Prevent partial/failed target scans from declaring broad resolution; surface coverage differences.
5. Compare URL inventory, indexability, redirects, canonical/schema and performance summary metrics where compatible.
6. Create regression summary/read models and per-finding diff evidence.
7. Allow approved baseline pin/unpin with audit.
8. Emit domain events for confirmed critical/high regressions.

## Required verification

- Compatibility and partial-coverage matrix tests.
- New/resolved/reopened/version-changed fixtures.
- Baseline authorization/audit tests.
- Large comparison performance/idempotency tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create baseline selection rules by project/property/environment/scan type/rule catalog and optional release.
- [ ] Persist immutable comparison records with source/target scan IDs, versions, coverage metrics and completion quality.
- [ ] Classify new, resolved-candidate, recurring, severity/priority changed and evidence changed findings.
- [ ] Prevent partial/failed target scans from declaring broad resolution; surface coverage differences.
- [ ] Compare URL inventory, indexability, redirects, canonical/schema and performance summary metrics where compatible.
- [ ] Create regression summary/read models and per-finding diff evidence.
- [ ] Allow approved baseline pin/unpin with audit.
- [ ] Emit domain events for confirmed critical/high regressions.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not compare incompatible rule/normalization versions silently.
- A missing URL in a failed scan is not resolved.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 090 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 090 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 090
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



---

---
id: 091
title: Implement encrypted integration credentials and token refresh
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 090
status: pending
---

# Prompt 091 — Implement encrypted integration credentials and token refresh

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `090`
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
ruby tracking/scripts/prompt_tracker.rb start 091
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

Create the reusable integration-connection security boundary for Search Console and later providers, including encryption, least scopes, refresh locking and revocation.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Create integration connections/credentials with organization, optional project/property scope, provider, external account, scopes, status, expiry and health metadata.
2. Encrypt access/refresh tokens with Active Record Encryption or documented envelope approach and support key version/rotation.
3. Never expose decrypted tokens outside the adapter execution boundary.
4. Implement refresh with row/advisory locking so concurrent jobs do not reuse/overwrite refresh tokens incorrectly.
5. Handle revoked/expired/insufficient scopes and mark reauthorization required.
6. Create disconnect/revoke operation and deletion policy.
7. Add credential redaction and audit events.
8. Define shared adapter execution wrapper for timeout/rate-limit/health metrics.

## Required verification

- Encryption-at-rest and no-log tests.
- Concurrent refresh/rotated refresh-token tests.
- Revocation/reauthorization lifecycle tests.
- Cross-tenant connection-scope tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create integration connections/credentials with organization, optional project/property scope, provider, external account, scopes, status, expiry and health metadata.
- [ ] Encrypt access/refresh tokens with Active Record Encryption or documented envelope approach and support key version/rotation.
- [ ] Never expose decrypted tokens outside the adapter execution boundary.
- [ ] Implement refresh with row/advisory locking so concurrent jobs do not reuse/overwrite refresh tokens incorrectly.
- [ ] Handle revoked/expired/insufficient scopes and mark reauthorization required.
- [ ] Create disconnect/revoke operation and deletion policy.
- [ ] Add credential redaction and audit events.
- [ ] Define shared adapter execution wrapper for timeout/rate-limit/health metrics.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not store tokens in session cookies.
- Do not retry a refresh operation blindly after an ambiguous response.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 091 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 091 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 091
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



---

---
id: 092
title: Implement Search Console connection and property mapping
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 091
status: pending
---

# Prompt 092 — Implement Search Console connection and property mapping

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `091`
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
ruby tracking/scripts/prompt_tracker.rb start 092
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

Add separately consented Search Console OAuth, exact accessible-property selection and tenant-safe mapping to SearchOps properties.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Implement authorization start/callback using the integration credential boundary, state/PKCE/exact redirect and least current scopes.
2. Keep Search Console authorization separate from Google login identity.
3. Fetch accessible sites/properties through a bounded adapter and display only during authorized selection.
4. Map an exact provider property to one SearchOps website property/environment using documented matching rules.
5. Record permission level, mapping actor/time and health status.
6. Handle duplicate mapping, revoked access, scope change and organization/project transfer restrictions.
7. Create connect/reauthorize/disconnect UI protected by integration permissions.
8. Audit all mapping changes.

## Required verification

- OAuth/integration callback security tests.
- URL-prefix/domain-property exact matching fixtures.
- Cross-tenant connection/mapping tests.
- Revocation/reauthorization system tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement authorization start/callback using the integration credential boundary, state/PKCE/exact redirect and least current scopes.
- [ ] Keep Search Console authorization separate from Google login identity.
- [ ] Fetch accessible sites/properties through a bounded adapter and display only during authorized selection.
- [ ] Map an exact provider property to one SearchOps website property/environment using documented matching rules.
- [ ] Record permission level, mapping actor/time and health status.
- [ ] Handle duplicate mapping, revoked access, scope change and organization/project transfer restrictions.
- [ ] Create connect/reauthorize/disconnect UI protected by integration permissions.
- [ ] Audit all mapping changes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not treat social login consent as Search Console consent.
- Do not store or expose all accessible provider properties indefinitely.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 092 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 092 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 092
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



---

---
id: 093
title: Implement Search Analytics import and read models
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 092
status: pending
---

# Prompt 093 — Implement Search Analytics import and read models

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `092`
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
ruby tracking/scripts/prompt_tracker.rb start 093
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

Import Search Console performance aggregates with provenance, quotas and explicit disclosure that returned rows may not be exhaustive.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/03_ERD.md`

## Required work

1. Implement bounded adapter requests for configured date ranges/dimensions/filters, pagination/row limits and aggregation type.
2. Persist import run, request dimensions, provider property, data date/freshness, returned rows and metrics using appropriate numeric precision.
3. Use idempotent keys so retries do not duplicate rows; support incremental re-import/correction windows.
4. Associate page dimensions to normalized known URLs where safe while retaining unmatched rows.
5. Respect provider quotas/rate limits and schedule fairly across organizations.
6. Create project/page/query read models for clicks, impressions, CTR and average position with no unsupported causal claims.
7. Display source freshness, filters, top-row limitation and no-data/error states.
8. Meter/store cost only if configured by plan.

## Required verification

- Adapter pagination/rate-limit/malformed response contracts.
- Idempotent incremental/correction import tests.
- Precision/aggregation/date-boundary tests.
- Cross-tenant read-model and authorization tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement bounded adapter requests for configured date ranges/dimensions/filters, pagination/row limits and aggregation type.
- [ ] Persist import run, request dimensions, provider property, data date/freshness, returned rows and metrics using appropriate numeric precision.
- [ ] Use idempotent keys so retries do not duplicate rows; support incremental re-import/correction windows.
- [ ] Associate page dimensions to normalized known URLs where safe while retaining unmatched rows.
- [ ] Respect provider quotas/rate limits and schedule fairly across organizations.
- [ ] Create project/page/query read models for clicks, impressions, CTR and average position with no unsupported causal claims.
- [ ] Display source freshness, filters, top-row limitation and no-data/error states.
- [ ] Meter/store cost only if configured by plan.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not present the dataset as all search queries.
- Do not mix differently aggregated rows without labeling.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 093 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 093 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 093
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



---

---
id: 094
title: Implement URL Inspection import
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 093
status: pending
---

# Prompt 094 — Implement URL Inspection import

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `093`
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
ruby tracking/scripts/prompt_tracker.rb start 094
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

Import bounded Google-known indexed state for authorized URLs and keep it visibly separate from SearchOps live technical state.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Implement adapter request/response normalization for the current URL Inspection API fields and permission/errors.
2. Allow inspection only for URLs within the mapped authorized property and configured bounded batch.
3. Persist inspected URL, provider-known state, response/source version, timestamp and relevant sitemap/referrer metadata.
4. Use provider quota-aware queueing, idempotency and backoff.
5. Create side-by-side UI: SearchOps live fetch/render facts versus Google-known indexed state and timestamp.
6. Generate comparison findings only where semantics are explicit, such as live indexability conflicting with provider-known status, with confidence caveats.
7. Handle no data, inaccessible URL/property and stale records.
8. Audit manual bulk requests and meter them if plan-controlled.

## Required verification

- Adapter fixture tests for representative provider states/errors.
- Out-of-property/cross-tenant denial tests.
- Freshness/no-data UI tests.
- Tests ensuring provider state is never labelled live fetch.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement adapter request/response normalization for the current URL Inspection API fields and permission/errors.
- [ ] Allow inspection only for URLs within the mapped authorized property and configured bounded batch.
- [ ] Persist inspected URL, provider-known state, response/source version, timestamp and relevant sitemap/referrer metadata.
- [ ] Use provider quota-aware queueing, idempotency and backoff.
- [ ] Create side-by-side UI: SearchOps live fetch/render facts versus Google-known indexed state and timestamp.
- [ ] Generate comparison findings only where semantics are explicit, such as live indexability conflicting with provider-known status, with confidence caveats.
- [ ] Handle no data, inaccessible URL/property and stale records.
- [ ] Audit manual bulk requests and meter them if plan-controlled.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use this API as an unrestricted real-time index checker.
- Do not claim an inspection response guarantees current ranking.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 094 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 094 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 094
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



---

---
id: 095
title: Implement CrUX field-data client and history
phase: 08 Search and performance integrations
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 094
status: pending
---

# Prompt 095 — Implement CrUX field-data client and history

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `094`
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
ruby tracking/scripts/prompt_tracker.rb start 095
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

Import available real-user Core Web Vitals data by URL/origin with period, form-factor and no-data semantics.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/06_SEO_RULE_CATALOG.md`

## Required work

1. Implement adapters for current CrUX API and CrUX History API contracts with bounded HTTP, quota and error handling.
2. Normalize source scope (URL/origin), form factor, collection period, metric distributions and percentile values.
3. Persist versioned field-data snapshots and explicit no-data state.
4. Map only exact normalized URL/origin and avoid substituting origin data without labeling.
5. Create history/read models for LCP, INP and CLS plus good/needs-improvement/poor thresholds sourced/versioned from official guidance.
6. Display collection period/sample limitations and separate mobile/desktop.
7. Schedule fair refresh and handle corrections/idempotency.
8. Add provider health and freshness metrics.

## Required verification

- Adapter fixtures for URL, origin, history, no-data, quota and malformed cases.
- Threshold/boundary/version tests.
- Mapping/labeling tests preventing URL-origin confusion.
- Cross-tenant history tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement adapters for current CrUX API and CrUX History API contracts with bounded HTTP, quota and error handling.
- [ ] Normalize source scope (URL/origin), form factor, collection period, metric distributions and percentile values.
- [ ] Persist versioned field-data snapshots and explicit no-data state.
- [ ] Map only exact normalized URL/origin and avoid substituting origin data without labeling.
- [ ] Create history/read models for LCP, INP and CLS plus good/needs-improvement/poor thresholds sourced/versioned from official guidance.
- [ ] Display collection period/sample limitations and separate mobile/desktop.
- [ ] Schedule fair refresh and handle corrections/idempotency.
- [ ] Add provider health and freshness metrics.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fabricate field data from Lighthouse.
- Thresholds are versioned source-backed values, not hardcoded marketing claims.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 095 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 095 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 095
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



---

---
id: 096
title: Implement isolated Lighthouse runner
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 095
status: pending
---

# Prompt 096 — Implement isolated Lighthouse runner

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `095`
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
ruby tracking/scripts/prompt_tracker.rb start 096
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

Run Lighthouse as a controlled, versioned lab analysis in dedicated workers with network safety, metering and artifact provenance.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0007_isolated_browser_workers.md`

## Required work

1. Pin Node/Lighthouse/Chromium versions in the render/performance image and record them per run.
2. Define Lighthouse job admission from an approved property URL and representative-page sampling policy.
3. Apply the safe destination/browser egress controls, wall time, CPU/memory, request and artifact limits.
4. Run selected categories/configuration with deterministic device/network profile metadata.
5. Persist normalized metrics/audits and store full JSON as private artifact.
6. Classify tool crash, page failure, timeout and no-result separately.
7. Charge credits idempotently and support cancellation/retry bounds.
8. Create operator metrics and customer lab-result UI.

## Required verification

- Local fixture end-to-end run.
- Unsafe subresource/private redirect tests.
- Timeout/crash/cancellation/credit tests.
- Provenance/artifact authorization tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Pin Node/Lighthouse/Chromium versions in the render/performance image and record them per run.
- [ ] Define Lighthouse job admission from an approved property URL and representative-page sampling policy.
- [ ] Apply the safe destination/browser egress controls, wall time, CPU/memory, request and artifact limits.
- [ ] Run selected categories/configuration with deterministic device/network profile metadata.
- [ ] Persist normalized metrics/audits and store full JSON as private artifact.
- [ ] Classify tool crash, page failure, timeout and no-result separately.
- [ ] Charge credits idempotently and support cancellation/retry bounds.
- [ ] Create operator metrics and customer lab-result UI.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Lighthouse is lab data, not real-user field data.
- Do not run it in the web/default worker.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 096 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 096 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 096
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



---

---
id: 097
title: Build the field, lab and crawl performance read model
phase: 08 Search and performance integrations
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 096
status: pending
---

# Prompt 097 — Build the field, lab and crawl performance read model

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `096`
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
ruby tracking/scripts/prompt_tracker.rb start 097
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

Present performance evidence from CrUX, Lighthouse and crawler timings as distinct sources with compatible trends and honest uncertainty.

## Required references

- `docs/01_PRD_V1.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Create read models grouping field data, lab runs and crawl/network timings without merging them into one unlabeled number.
2. Normalize units and metric names while preserving source, device/profile, URL/origin scope, period and version.
3. Display current value, threshold classification, trend and no-data/error/stale states.
4. Allow representative-page/template grouping with explicit selection metadata.
5. Create performance findings only from source-appropriate rules and confidence.
6. Add accessible tables and lightweight charts with textual equivalents.
7. Optimize queries and cache read models using revision-based invalidation.
8. Document interpretation limitations.

## Required verification

- View/read-model tests for all source/no-data combinations.
- Unit conversion and threshold boundary tests.
- Accessibility tests for charts/tables.
- Query-count/performance tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create read models grouping field data, lab runs and crawl/network timings without merging them into one unlabeled number.
- [ ] Normalize units and metric names while preserving source, device/profile, URL/origin scope, period and version.
- [ ] Display current value, threshold classification, trend and no-data/error/stale states.
- [ ] Allow representative-page/template grouping with explicit selection metadata.
- [ ] Create performance findings only from source-appropriate rules and confidence.
- [ ] Add accessible tables and lightweight charts with textual equivalents.
- [ ] Optimize queries and cache read models using revision-based invalidation.
- [ ] Document interpretation limitations.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not average incompatible field and lab measurements.
- Do not imply correlation proves an SEO ranking cause.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 097 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 097 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 097
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



---

---
id: 098
title: Implement traffic-aware finding prioritization
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 097
status: pending
---

# Prompt 098 — Implement traffic-aware finding prioritization

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `097`
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
ruby tracking/scripts/prompt_tracker.rb start 098
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

Enrich priority with Search Console evidence while preserving explainability, privacy and sane behavior when data is missing or sampled.

## Required references

- `docs/01_PRD_V1.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/03_ERD.md`

## Required work

1. Map finding subjects to exact page performance rows with normalized URL/version and a bounded lookback window.
2. Define traffic factor from impressions/clicks or page importance with robust caps and explicit missing-data default.
3. Prevent a high-traffic low-confidence heuristic from automatically outranking verified critical safety/indexability issues without policy.
4. Persist factor source/date/coverage with score version.
5. Recompute asynchronously after imports without mutating finding evidence.
6. Display why traffic affected priority and disclose top-row/incomplete provider coverage.
7. Allow authorized manual business importance overlay with audit.
8. Add batch performance/indexes.

## Required verification

- Scoring fixtures for high/low/missing/outlier traffic.
- Provider partial-data disclosure tests.
- Recalculation idempotency/version tests.
- Cross-tenant mapping and manual-override authorization tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Map finding subjects to exact page performance rows with normalized URL/version and a bounded lookback window.
- [ ] Define traffic factor from impressions/clicks or page importance with robust caps and explicit missing-data default.
- [ ] Prevent a high-traffic low-confidence heuristic from automatically outranking verified critical safety/indexability issues without policy.
- [ ] Persist factor source/date/coverage with score version.
- [ ] Recompute asynchronously after imports without mutating finding evidence.
- [ ] Display why traffic affected priority and disclose top-row/incomplete provider coverage.
- [ ] Allow authorized manual business importance overlay with audit.
- [ ] Add batch performance/indexes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Missing provider rows do not mean zero traffic.
- Do not expose raw search queries to users lacking project access.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 098 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 098 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 098
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



---

---
id: 099
title: Implement scheduled scans and dynamic recurring tasks
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 098
status: pending
---

# Prompt 099 — Implement scheduled scans and dynamic recurring tasks

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `098`
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
ruby tracking/scripts/prompt_tracker.rb start 099
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

Allow entitled organizations to schedule scans reliably with timezone-aware recurrence, fair admission, deduplication and missed-run policy.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Create schedules with project/property/environment, scan type, timezone, recurrence, enabled state, next/last run and creator.
2. Validate frequency and concurrency against effective entitlements/global caps.
3. Use Solid Queue recurring/dynamic scheduling or a deterministic dispatcher with database locking; document the chosen current Rails/Solid capability.
4. Generate a stable idempotency key per scheduled occurrence and pass through normal scan admission.
5. Define missed/late run, DST, disabled/archived/past-due and overlapping-scan behavior.
6. Create schedule UI with next-run preview and audit history.
7. Add dispatcher lag/failure metrics and operator repair task.
8. Do not let a scheduler bypass verification, safety, quota or capacity checks.

## Required verification

- Timezone/DST/duplicate dispatcher tests.
- Entitlement downgrade and past-due behavior tests.
- Overlapping/missed-run policy tests.
- Multi-scheduler locking/fairness tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create schedules with project/property/environment, scan type, timezone, recurrence, enabled state, next/last run and creator.
- [ ] Validate frequency and concurrency against effective entitlements/global caps.
- [ ] Use Solid Queue recurring/dynamic scheduling or a deterministic dispatcher with database locking; document the chosen current Rails/Solid capability.
- [ ] Generate a stable idempotency key per scheduled occurrence and pass through normal scan admission.
- [ ] Define missed/late run, DST, disabled/archived/past-due and overlapping-scan behavior.
- [ ] Create schedule UI with next-run preview and audit history.
- [ ] Add dispatcher lag/failure metrics and operator repair task.
- [ ] Do not let a scheduler bypass verification, safety, quota or capacity checks.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not enqueue unlimited catch-up scans after an outage.
- Schedules are intents; every run still passes current admission policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 099 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 099 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 099
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



---

---
id: '100'
title: Implement Android property and Digital Asset Links validation
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 099
status: pending
---

# Prompt 100 — Implement Android property and Digital Asset Links validation

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `099`
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
ruby tracking/scripts/prompt_tracker.rb start 100
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

Validate the association between an Android package/signing certificate and verified website hosts using bounded `assetlinks.json` retrieval and exact semantics.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Complete Android property fields for package name and one or more expected SHA-256 signing fingerprints with safe formatting/validation.
2. Fetch `/.well-known/assetlinks.json` from each approved verified HTTPS host through the safe HTTP boundary with redirect/content/size limits.
3. Parse bounded JSON and evaluate exact namespace/package/fingerprint/relation entries.
4. Implement missing, invalid, package mismatch, fingerprint mismatch and host coverage rules from the catalog.
5. Store file hash, retrieval time, source version and bounded evidence; never expose confidential unrelated statements.
6. Support multiple production signing certificates/rotation explicitly.
7. Create Android association overview and targeted recheck.
8. Meter rechecks and audit configuration changes.

## Required verification

- Fixtures for valid/multiple/malformed/oversized/mismatch files.
- HTTPS/redirect/private-target security tests.
- Fingerprint normalization/rotation tests.
- Cross-tenant host/property tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Complete Android property fields for package name and one or more expected SHA-256 signing fingerprints with safe formatting/validation.
- [ ] Fetch `/.well-known/assetlinks.json` from each approved verified HTTPS host through the safe HTTP boundary with redirect/content/size limits.
- [ ] Parse bounded JSON and evaluate exact namespace/package/fingerprint/relation entries.
- [ ] Implement missing, invalid, package mismatch, fingerprint mismatch and host coverage rules from the catalog.
- [ ] Store file hash, retrieval time, source version and bounded evidence; never expose confidential unrelated statements.
- [ ] Support multiple production signing certificates/rotation explicitly.
- [ ] Create Android association overview and targeted recheck.
- [ ] Meter rechecks and audit configuration changes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not accept an arbitrary assetlinks URL.
- A matching file does not prove the installed app build uses the same signing key without manifest/build evidence.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 100 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 100 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 100
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



---

---
id: '101'
title: Implement Android manifest import and App Links analysis
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '100'
status: pending
---

# Prompt 101 — Implement Android manifest import and App Links analysis

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `100`
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
ruby tracking/scripts/prompt_tracker.rb start 101
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

Analyze customer-supplied Android manifest/build metadata to compare declared intent filters with hosted Digital Asset Links.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Define a safe upload/API format for parsed manifest data or bounded XML manifest; document that binary APK/AAB analysis is outside initial scope unless explicitly added.
2. Parse with XXE disabled and strict size/depth/count limits.
3. Extract package, activities, intent filters, schemes/hosts/paths, categories and `autoVerify` metadata needed for App Links.
4. Compare declared hosts/routes with verified website properties and assetlinks statements.
5. Implement autoVerify missing, host unverified, overly broad/narrow route and fallback-risk findings with Android-version caveats.
6. Version the analyzer and retain source artifact hash/release association.
7. Create upload/history/diff UI with authorization and retention.
8. Sanitize all component/path evidence.

## Required verification

- Manifest fixtures for valid, missing autoVerify, multiple hosts/path rules and malformed/XXE.
- Package/property mismatch and cross-tenant tests.
- Analyzer version/diff tests.
- Upload size/content-type/XSS tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define a safe upload/API format for parsed manifest data or bounded XML manifest; document that binary APK/AAB analysis is outside initial scope unless explicitly added.
- [ ] Parse with XXE disabled and strict size/depth/count limits.
- [ ] Extract package, activities, intent filters, schemes/hosts/paths, categories and `autoVerify` metadata needed for App Links.
- [ ] Compare declared hosts/routes with verified website properties and assetlinks statements.
- [ ] Implement autoVerify missing, host unverified, overly broad/narrow route and fallback-risk findings with Android-version caveats.
- [ ] Version the analyzer and retain source artifact hash/release association.
- [ ] Create upload/history/diff UI with authorization and retention.
- [ ] Sanitize all component/path evidence.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not execute uploaded Android code.
- Do not claim device verification across every Android version without actual device evidence.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 101 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 101 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 101
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



---

---
id: '102'
title: Implement iOS AASA and Associated Domains validation
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '101'
status: pending
---

# Prompt 102 — Implement iOS AASA and Associated Domains validation

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `101`
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
ruby tracking/scripts/prompt_tracker.rb start 102
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

Validate iOS Universal Links using exact app identifiers, declared domains and bounded Apple App Site Association retrieval.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Complete iOS property fields for Team ID, Bundle ID and expected associated domains with strict validation.
2. Fetch AASA from supported well-known/root locations on approved verified HTTPS hosts through safe HTTP policy.
3. Parse bounded JSON without remote resolution and evaluate `applinks` details/components/paths for exact app identifiers and routes.
4. Implement missing, invalid, app ID mismatch, associated-domain missing and route coverage findings.
5. Support multiple app IDs/environments deliberately and version parser semantics.
6. Store source hash/retrieval time/evidence and create overview/targeted recheck UI.
7. Accept a customer-supplied entitlement export/config in a bounded non-executable format for comparison.
8. Audit changes and meter validations.

## Required verification

- Fixtures for valid legacy/current structures, malformed/oversized and route mismatch.
- HTTPS/redirect/private-network tests.
- Team+Bundle identifier exact-match tests.
- Cross-tenant configuration/upload tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Complete iOS property fields for Team ID, Bundle ID and expected associated domains with strict validation.
- [ ] Fetch AASA from supported well-known/root locations on approved verified HTTPS hosts through safe HTTP policy.
- [ ] Parse bounded JSON without remote resolution and evaluate `applinks` details/components/paths for exact app identifiers and routes.
- [ ] Implement missing, invalid, app ID mismatch, associated-domain missing and route coverage findings.
- [ ] Support multiple app IDs/environments deliberately and version parser semantics.
- [ ] Store source hash/retrieval time/evidence and create overview/targeted recheck UI.
- [ ] Accept a customer-supplied entitlement export/config in a bounded non-executable format for comparison.
- [ ] Audit changes and meter validations.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not execute uploaded iOS artifacts.
- Do not claim on-device Universal Link success without device testing.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 102 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 102 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 102
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



---

---
id: '103'
title: Implement App Store listing snapshots and audit
phase: 09 Mobile discovery and release guard
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '102'
status: pending
---

# Prompt 103 — Implement App Store listing snapshots and audit

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `102`
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
ruby tracking/scripts/prompt_tracker.rb start 103
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

Capture authorized/manual Apple App Store product metadata snapshots, version changes and bounded ASO checks without scraping prohibited data.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Define provider/manual import adapter based on currently permitted App Store Connect/public metadata access and document required credentials/agreements.
2. Persist listing snapshots by app, locale, store territory/source, version and retrieval time.
3. Normalize name, subtitle, keyword field when authorized, description, promotional text, categories and media metadata needed for rules.
4. Implement current documented length/completeness/localization checks with source/effective date and no ranking guarantees.
5. Create snapshot diff/history and release association.
6. Handle missing/private fields as unknown rather than inferred.
7. Encrypt credentials through integration connection boundary and respect provider quotas.
8. Create listing overview UI and audit events.

## Required verification

- Adapter/manual import contracts and sanitized fixtures.
- Length-boundary/source-version tests.
- Snapshot idempotency/diff tests.
- Credential/cross-tenant/permission tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define provider/manual import adapter based on currently permitted App Store Connect/public metadata access and document required credentials/agreements.
- [ ] Persist listing snapshots by app, locale, store territory/source, version and retrieval time.
- [ ] Normalize name, subtitle, keyword field when authorized, description, promotional text, categories and media metadata needed for rules.
- [ ] Implement current documented length/completeness/localization checks with source/effective date and no ranking guarantees.
- [ ] Create snapshot diff/history and release association.
- [ ] Handle missing/private fields as unknown rather than inferred.
- [ ] Encrypt credentials through integration connection boundary and respect provider quotas.
- [ ] Create listing overview UI and audit events.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not scrape or automate beyond provider terms.
- Do not claim metadata changes guarantee App Store ranking.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 103 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 103 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 103
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



---

---
id: '104'
title: Implement Google Play listing snapshots and audit
phase: 09 Mobile discovery and release guard
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '103'
status: pending
---

# Prompt 104 — Implement Google Play listing snapshots and audit

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `103`
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
ruby tracking/scripts/prompt_tracker.rb start 104
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

Capture permitted Google Play listing metadata by locale/track/source and produce transparent ASO checks and diffs.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Define provider/manual import adapter using currently permitted Google Play Developer/Console mechanisms and least scopes.
2. Persist snapshots by app, locale, track/territory where available, version and retrieval time.
3. Normalize title, short/full description, categories/tags and media metadata required by configured rules.
4. Implement current documented length/completeness/localization/asset-presence checks with source/effective date.
5. Create listing diff/history and release association.
6. Treat unavailable review/ranking data explicitly and avoid scraping unsupported endpoints.
7. Use encrypted integration credentials and provider quota controls.
8. Create listing overview UI and audit events.

## Required verification

- Adapter/manual import contracts and fixtures.
- Boundary/version tests for current limits.
- Snapshot idempotency/diff tests.
- Credential/cross-tenant/permission tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define provider/manual import adapter using currently permitted Google Play Developer/Console mechanisms and least scopes.
- [ ] Persist snapshots by app, locale, track/territory where available, version and retrieval time.
- [ ] Normalize title, short/full description, categories/tags and media metadata required by configured rules.
- [ ] Implement current documented length/completeness/localization/asset-presence checks with source/effective date.
- [ ] Create listing diff/history and release association.
- [ ] Treat unavailable review/ranking data explicitly and avoid scraping unsupported endpoints.
- [ ] Use encrypted integration credentials and provider quota controls.
- [ ] Create listing overview UI and audit events.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not violate Play provider terms through scraping.
- Do not combine Android technical link validation with store ranking claims.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 104 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 104 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 104
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



---

---
id: '105'
title: Implement the web-to-app route map
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '104'
status: pending
---

# Prompt 105 — Implement the web-to-app route map

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `104`
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
ruby tracking/scripts/prompt_tracker.rb start 105
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

Model expected relationships between public web URLs, Android App Links, iOS Universal Links and web fallbacks, then verify them from available evidence.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`
- `docs/06_SEO_RULE_CATALOG.md`

## Required work

1. Create route-map entries/patterns scoped to project and environment with web pattern, Android target, iOS target, fallback and priority.
2. Use a safe bounded path-pattern language; reject catastrophic regex or ambiguous overlapping routes.
3. Compile expected route samples from configured templates/known URLs without generating unbounded combinations.
4. Compare web inventory, Android intent filters/assetlinks and iOS entitlements/AASA coverage.
5. Implement missing app destination, missing web landing/fallback, route conflict and inconsistent locale/identifier findings with confidence.
6. Create visual/table route coverage UI with representative evidence and release history.
7. Support CSV/JSON import/export through schema validation and permissions.
8. Allow targeted verification and audit changes.

## Required verification

- Pattern parser/overlap/complexity tests.
- Cross-platform coverage fixtures.
- Partial-evidence confidence tests.
- Cross-tenant import/export/verification tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create route-map entries/patterns scoped to project and environment with web pattern, Android target, iOS target, fallback and priority.
- [ ] Use a safe bounded path-pattern language; reject catastrophic regex or ambiguous overlapping routes.
- [ ] Compile expected route samples from configured templates/known URLs without generating unbounded combinations.
- [ ] Compare web inventory, Android intent filters/assetlinks and iOS entitlements/AASA coverage.
- [ ] Implement missing app destination, missing web landing/fallback, route conflict and inconsistent locale/identifier findings with confidence.
- [ ] Create visual/table route coverage UI with representative evidence and release history.
- [ ] Support CSV/JSON import/export through schema validation and permissions.
- [ ] Allow targeted verification and audit changes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not attempt to launch native apps from server-side validation.
- Route maps describe expectations and evidence, not guaranteed device behavior.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 105 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 105 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 105
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



---

---
id: '106'
title: Implement releases and authenticated incoming deployment webhooks
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '105'
status: pending
---

# Prompt 106 — Implement releases and authenticated incoming deployment webhooks

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `105`
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
ruby tracking/scripts/prompt_tracker.rb start 106
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

Accept idempotent release notifications from CI/CD, map them to a project/environment and trigger authorized regression workflows.

## Required references

- `schemas/release_event.schema.json`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create release records with external event ID, project/environment, identifier, commit/branch/url metadata, occurred/received times, status and source.
2. Implement incoming endpoint conforming to `schemas/release_event.schema.json` with strict size/content/schema bounds.
3. Authenticate using per-project secret HMAC and timestamp/replay window or scoped API key according to documented contract.
4. Hash/store secrets, support rotation and compare signatures over exact raw bytes.
5. Enforce unique event ID/idempotency and detect conflicting duplicates.
6. Validate changed URLs remain within approved environment; treat them only as scan hints.
7. Trigger configured targeted/full scan through normal admission, not directly.
8. Create release list/detail UI, audit events and provider-neutral status callback interface.

## Required verification

- Signature/raw-body/timestamp/replay tests.
- Schema/size/out-of-scope URL tests.
- Duplicate/conflicting event concurrency tests.
- Cross-project secret and scan-admission tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create release records with external event ID, project/environment, identifier, commit/branch/url metadata, occurred/received times, status and source.
- [ ] Implement incoming endpoint conforming to `schemas/release_event.schema.json` with strict size/content/schema bounds.
- [ ] Authenticate using per-project secret HMAC and timestamp/replay window or scoped API key according to documented contract.
- [ ] Hash/store secrets, support rotation and compare signatures over exact raw bytes.
- [ ] Enforce unique event ID/idempotency and detect conflicting duplicates.
- [ ] Validate changed URLs remain within approved environment; treat them only as scan hints.
- [ ] Trigger configured targeted/full scan through normal admission, not directly.
- [ ] Create release list/detail UI, audit events and provider-neutral status callback interface.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- A release webhook never bypasses RBAC/entitlement/quota/safety.
- Do not trust commit URLs or metadata as HTML.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 106 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 106 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 106
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



---

---
id: '107'
title: Implement release guard policies and status publishing
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '106'
status: pending
---

# Prompt 107 — Implement release guard policies and status publishing

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `106`
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
ruby tracking/scripts/prompt_tracker.rb start 107
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

Evaluate scan regressions against versioned project policies and publish an explainable pass/warn/fail result to CI/CD.

## Required references

- `config_blueprints/release_policy.example.yml`
- `docs/01_PRD_V1.md`
- `docs/08_INTEGRATIONS_AND_API.md`

## Required work

1. Model versioned release policies based on `config_blueprints/release_policy.example.yml`, with thresholds for new critical/high findings, URL/indexability loss, redirects, schema and performance regressions.
2. Validate policy keys/types/bounds and preserve the exact policy snapshot on each evaluation.
3. Evaluate only compatible completed/partial scans with explicit coverage rules and produce pass, warn, fail or inconclusive.
4. List every contributing condition and evidence; do not hide results behind one score.
5. Allow advisory mode before blocking mode and require explicit project authorization to enable blocking.
6. Implement provider-neutral status publisher/webhook callback with retries, signing and idempotency.
7. Create release result UI and downloadable machine-readable result.
8. Audit policy changes and blocking activation.

## Required verification

- Policy parser/boundary/version tests.
- Pass/warn/fail/inconclusive fixtures including partial scan.
- Publisher retry/idempotency/signature tests.
- Authorization and advisory-to-blocking transition tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Model versioned release policies based on `config_blueprints/release_policy.example.yml`, with thresholds for new critical/high findings, URL/indexability loss, redirects, schema and performance regressions.
- [ ] Validate policy keys/types/bounds and preserve the exact policy snapshot on each evaluation.
- [ ] Evaluate only compatible completed/partial scans with explicit coverage rules and produce pass, warn, fail or inconclusive.
- [ ] List every contributing condition and evidence; do not hide results behind one score.
- [ ] Allow advisory mode before blocking mode and require explicit project authorization to enable blocking.
- [ ] Implement provider-neutral status publisher/webhook callback with retries, signing and idempotency.
- [ ] Create release result UI and downloadable machine-readable result.
- [ ] Audit policy changes and blocking activation.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fail a release from missing/incompatible evidence without an explicit inconclusive policy.
- Never claim the gate guarantees ranking impact.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 107 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 107 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 107
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



---

---
id: '108'
title: Implement immutable report snapshots and export
phase: 10 Reporting, API and administration
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '107'
status: pending
---

# Prompt 108 — Implement immutable report snapshots and export

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `107`
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
ruby tracking/scripts/prompt_tracker.rb start 108
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

Generate reproducible organization/project reports from frozen read-model inputs with private artifacts, source dates and evidence caveats.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create report definitions/runs/snapshots with organization/project scope, template version, filters, requested/started/completed state and source data cutoffs.
2. Snapshot metrics/findings/comparisons used by a report so later data changes do not rewrite historical output.
3. Generate accessible HTML first and PDF only through a controlled renderer if required; store artifacts privately.
4. Include methodology, coverage, data freshness, rule/catalog versions and limitations.
5. Support technical summary, executive summary, regression and web/mobile route reports according to entitlements.
6. Ensure all customer-controlled content is escaped/sanitized and external resources are not fetched during report rendering.
7. Create authorized download with short-lived URL and retention.
8. Meter generation and make jobs idempotent/cancelable.

## Required verification

- Snapshot immutability and reproducibility tests.
- Cross-tenant artifact/download tests.
- XSS/external-resource/report-size tests.
- Job retry/cancellation/usage tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create report definitions/runs/snapshots with organization/project scope, template version, filters, requested/started/completed state and source data cutoffs.
- [ ] Snapshot metrics/findings/comparisons used by a report so later data changes do not rewrite historical output.
- [ ] Generate accessible HTML first and PDF only through a controlled renderer if required; store artifacts privately.
- [ ] Include methodology, coverage, data freshness, rule/catalog versions and limitations.
- [ ] Support technical summary, executive summary, regression and web/mobile route reports according to entitlements.
- [ ] Ensure all customer-controlled content is escaped/sanitized and external resources are not fetched during report rendering.
- [ ] Create authorized download with short-lived URL and retention.
- [ ] Meter generation and make jobs idempotent/cancelable.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not regenerate an old report silently from current data.
- Report rendering must not become an SSRF path.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 108 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 108 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 108
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



---

---
id: '109'
title: Implement scheduled reports and delivery
phase: 10 Reporting, API and administration
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '108'
status: pending
---

# Prompt 109 — Implement scheduled reports and delivery

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `108`
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
ruby tracking/scripts/prompt_tracker.rb start 109
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

Allow entitled organizations to schedule immutable reports and deliver them safely by email or later notification channels.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create report schedules with template, filters, recipients policy, timezone/recurrence, next run and enabled state.
2. Validate frequency, retention and white-label options against current entitlements.
3. Dispatch idempotently with DST/missed-run/overlap behavior parallel to scan schedules.
4. Generate report snapshot before delivery and record delivery attempts/outcomes.
5. Allow only current organization members or explicitly approved addresses according to policy; prevent data exfiltration through arbitrary recipients on lower plans.
6. Use expiring authenticated links rather than large sensitive attachments by default.
7. Create schedule/delivery-history UI and audit changes.
8. Add metrics and repair/retry operation.

## Required verification

- Timezone/DST/duplicate schedule tests.
- Recipient authorization/exfiltration tests.
- Delivery retry/idempotency/link expiry tests.
- Entitlement downgrade behavior tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create report schedules with template, filters, recipients policy, timezone/recurrence, next run and enabled state.
- [ ] Validate frequency, retention and white-label options against current entitlements.
- [ ] Dispatch idempotently with DST/missed-run/overlap behavior parallel to scan schedules.
- [ ] Generate report snapshot before delivery and record delivery attempts/outcomes.
- [ ] Allow only current organization members or explicitly approved addresses according to policy; prevent data exfiltration through arbitrary recipients on lower plans.
- [ ] Use expiring authenticated links rather than large sensitive attachments by default.
- [ ] Create schedule/delivery-history UI and audit changes.
- [ ] Add metrics and repair/retry operation.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not email raw confidential artifacts by default.
- Past-due/archived behavior must follow canonical access policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 109 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 109 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 109
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



---

---
id: '110'
title: Implement email, Slack and in-app notifications
phase: 10 Reporting, API and administration
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '109'
status: pending
---

# Prompt 110 — Implement email, Slack and in-app notifications

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `109`
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
ruby tracking/scripts/prompt_tracker.rb start 110
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

Create a preference-aware notification system for issues, regressions, billing and operational events with bounded retries and no secret leakage.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Define notification event types, audience resolution, per-user/project preferences, urgency and channel eligibility.
2. Implement durable notification records and channel deliveries with idempotency keys.
3. Add email delivery and in-app inbox/counts; add Slack connection/webhook adapter through encrypted integration credentials and entitlement checks.
4. Sign/validate Slack OAuth or webhook setup according to chosen current integration method and least scopes.
5. Sanitize/truncate customer evidence and link back to authorized application pages rather than embedding sensitive content.
6. Implement digest/throttle/suppression rules to avoid alert storms.
7. Record delivery outcome, retry/backoff and permanent failure/reauthorization state.
8. Create notification preference and integration UI.

## Required verification

- Audience/permission/preference resolution tests.
- Duplicate/digest/throttle tests.
- Channel adapter timeout/retry/redaction tests.
- Cross-tenant Slack connection and notification-link tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define notification event types, audience resolution, per-user/project preferences, urgency and channel eligibility.
- [ ] Implement durable notification records and channel deliveries with idempotency keys.
- [ ] Add email delivery and in-app inbox/counts; add Slack connection/webhook adapter through encrypted integration credentials and entitlement checks.
- [ ] Sign/validate Slack OAuth or webhook setup according to chosen current integration method and least scopes.
- [ ] Sanitize/truncate customer evidence and link back to authorized application pages rather than embedding sensitive content.
- [ ] Implement digest/throttle/suppression rules to avoid alert storms.
- [ ] Record delivery outcome, retry/backoff and permanent failure/reauthorization state.
- [ ] Create notification preference and integration UI.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not post OAuth tokens, raw page bodies or private report URLs to Slack.
- Notifications do not authorize access; links still require application authorization.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 110 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 110 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 110
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



---

---
id: '111'
title: Implement API keys, public API, outgoing webhooks and IndexNow
phase: 10 Reporting, API and administration
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '110'
status: pending
---

# Prompt 111 — Implement API keys, public API, outgoing webhooks and IndexNow

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `110`
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
ruby tracking/scripts/prompt_tracker.rb start 111
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

Expose a bounded versioned API and signed event delivery while preserving scoped authorization, rate limits, auditability and provider semantics.

## Required references

- `schemas/outgoing_webhook_envelope.schema.json`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create hashed API keys with organization/project scope, explicit permission set, name, prefix, expiry, last use and revocation; show secret once.
2. Implement versioned JSON API foundations with stable errors, pagination, idempotency keys and request IDs.
3. Expose only MVP endpoints justified for projects, scans, findings/issues, reports and release results; apply RBAC/entitlement/quota independently.
4. Create outgoing webhook endpoints/subscriptions with encrypted signing secret, event allowlist, delivery queue, HMAC/timestamp, retries and disable-on-failure policy using the envelope schema.
5. Implement SSRF-safe validation/delivery for webhook destinations, including revalidation on redirects and no private networks.
6. Add IndexNow adapter for changed/deleted URLs with key ownership/config, batching/rate limits and accurate 'submitted, not guaranteed indexed' language.
7. Create audit/usage metrics and developer documentation with sanitized examples.
8. Add key rotation/replay tooling.

## Required verification

- API key hash/scope/expiry/revocation and cross-tenant tests.
- API contract/idempotency/rate-limit tests.
- Outgoing webhook signature/retry/replay/SSRF tests.
- IndexNow batching/error/wording tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create hashed API keys with organization/project scope, explicit permission set, name, prefix, expiry, last use and revocation; show secret once.
- [ ] Implement versioned JSON API foundations with stable errors, pagination, idempotency keys and request IDs.
- [ ] Expose only MVP endpoints justified for projects, scans, findings/issues, reports and release results; apply RBAC/entitlement/quota independently.
- [ ] Create outgoing webhook endpoints/subscriptions with encrypted signing secret, event allowlist, delivery queue, HMAC/timestamp, retries and disable-on-failure policy using the envelope schema.
- [ ] Implement SSRF-safe validation/delivery for webhook destinations, including revalidation on redirects and no private networks.
- [ ] Add IndexNow adapter for changed/deleted URLs with key ownership/config, batching/rate limits and accurate 'submitted, not guaranteed indexed' language.
- [ ] Create audit/usage metrics and developer documentation with sanitized examples.
- [ ] Add key rotation/replay tooling.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not allow arbitrary internal webhook destinations.
- IndexNow acknowledgement is not indexing proof.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 111 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 111 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 111
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



---

---
id: '112'
title: Implement safe administration and operations dashboards
phase: 10 Reporting, API and administration
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '111'
status: pending
---

# Prompt 112 — Implement safe administration and operations dashboards

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `111`
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
ruby tracking/scripts/prompt_tracker.rb start 112
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

Provide least-privileged support tooling for diagnosing tenants, jobs, integrations, billing and consistency without normalizing direct database edits.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/03_ERD.md`

## Required work

1. Create a separate administration namespace with explicit operator authorization, recent authentication and audited access.
2. Expose safe summaries for organizations, subscriptions, webhook events, queues, stuck scans, integrations, usage reservations, reports and consistency checks.
3. Implement narrowly scoped operations already defined by domain services: replay event, reconcile subscription, retry eligible delivery/job, cancel scan, expire reservation and revoke credential.
4. Require reason/confirmation for high-impact operations and display before/after result.
5. Redact tokens, signatures, page artifacts, personal data and provider payloads by default; gate exceptional access through a separate documented process.
6. Prevent cross-environment actions and accidental bulk operations.
7. Add operator metrics links/runbook references and immutable audit.
8. Create support diagnostic bundle containing IDs/statuses only, no secrets.

## Required verification

- Operator authorization/recent-auth tests.
- Audit and redaction tests for every operation.
- Domain-invariant tests proving admin UI cannot bypass rules.
- Cross-environment/tenant selection safety tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a separate administration namespace with explicit operator authorization, recent authentication and audited access.
- [ ] Expose safe summaries for organizations, subscriptions, webhook events, queues, stuck scans, integrations, usage reservations, reports and consistency checks.
- [ ] Implement narrowly scoped operations already defined by domain services: replay event, reconcile subscription, retry eligible delivery/job, cancel scan, expire reservation and revoke credential.
- [ ] Require reason/confirmation for high-impact operations and display before/after result.
- [ ] Redact tokens, signatures, page artifacts, personal data and provider payloads by default; gate exceptional access through a separate documented process.
- [ ] Prevent cross-environment actions and accidental bulk operations.
- [ ] Add operator metrics links/runbook references and immutable audit.
- [ ] Create support diagnostic bundle containing IDs/statuses only, no secrets.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No generic SQL console or arbitrary model editor.
- Support convenience never overrides tenant isolation or billing mapping identity.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 112 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 112 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 112
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



---

---
id: '113'
title: Implement audit retention, privacy export and deletion workflows
phase: 10 Reporting, API and administration
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '112'
status: pending
---

# Prompt 113 — Implement audit retention, privacy export and deletion workflows

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `112`
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
ruby tracking/scripts/prompt_tracker.rb start 113
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

Complete tenant/user data governance with documented retention, export and deletion operations that preserve required integrity and remove artifacts safely.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/03_ERD.md`

## Required work

1. Classify stored data by domain, sensitivity, owner, default retention, deletion trigger and legal/operational hold placeholder.
2. Implement configurable retention jobs for sessions, OAuth transactions, crawl artifacts, rendered artifacts, provider payloads, notifications, reports and high-volume occurrences according to entitlements/policy.
3. Create user/organization export manifests with authorized bounded asynchronous generation and private expiring download.
4. Implement account deletion/anonymization workflow that handles active ownership, memberships, identity links, comments/audit attribution and billing records.
5. Preserve minimal security/billing evidence only under documented policy and pseudonymize where appropriate.
6. Make deletion/export idempotent, resumable and observable across PostgreSQL/object storage.
7. Create customer UI and operator runbook.
8. Add reconciliation for orphaned/missing objects.

## Required verification

- Retention boundary and legal-hold placeholder tests.
- Export cross-tenant/authorization/artifact tests.
- Deletion ownership/block/resume/anonymization tests.
- Object/database reconciliation tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Classify stored data by domain, sensitivity, owner, default retention, deletion trigger and legal/operational hold placeholder.
- [ ] Implement configurable retention jobs for sessions, OAuth transactions, crawl artifacts, rendered artifacts, provider payloads, notifications, reports and high-volume occurrences according to entitlements/policy.
- [ ] Create user/organization export manifests with authorized bounded asynchronous generation and private expiring download.
- [ ] Implement account deletion/anonymization workflow that handles active ownership, memberships, identity links, comments/audit attribution and billing records.
- [ ] Preserve minimal security/billing evidence only under documented policy and pseudonymize where appropriate.
- [ ] Make deletion/export idempotent, resumable and observable across PostgreSQL/object storage.
- [ ] Create customer UI and operator runbook.
- [ ] Add reconciliation for orphaned/missing objects.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not assert legal compliance without counsel.
- Do not erase immutable billing/security evidence outside documented policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 113 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 113 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 113
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



---

---
id: '114'
title: Complete observability, metrics, tracing and alert definitions
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '113'
status: pending
---

# Prompt 114 — Complete observability, metrics, tracing and alert definitions

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `113`
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
ruby tracking/scripts/prompt_tracker.rb start 114
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

Instrument every critical customer and security path with low-cardinality metrics, correlated structured events and actionable alerts/runbooks.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Implement/request/job correlation and tracing across web, outbox/enqueue, workers, provider calls and status publishing using a provider-neutral interface.
2. Add metrics listed in `docs/10_DEPLOYMENT_AND_OPERATIONS.md` for auth, billing, queue, scan, DNS/SSRF denials, fetch/render, usage, rules, reports, integrations and database health.
3. Hash or omit tenant identifiers according to privacy policy and prevent customer strings from metric labels.
4. Define dashboards for web control plane, billing, crawl fleet, render fleet, integrations and database.
5. Define symptom/customer-impact alerts with thresholds initially marked hypotheses and links to runbooks.
6. Add synthetic low-risk checks for health, queue, object storage and key provider configuration.
7. Test redaction/cardinality and failure behavior when observability provider is unavailable.
8. Document release annotations and incident correlation.

## Required verification

- Instrumentation unit/integration tests on critical paths.
- Redaction and cardinality-budget tests.
- Observability-provider outage test proving product path degrades safely.
- Validate every paging alert references a runbook.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement/request/job correlation and tracing across web, outbox/enqueue, workers, provider calls and status publishing using a provider-neutral interface.
- [ ] Add metrics listed in `docs/10_DEPLOYMENT_AND_OPERATIONS.md` for auth, billing, queue, scan, DNS/SSRF denials, fetch/render, usage, rules, reports, integrations and database health.
- [ ] Hash or omit tenant identifiers according to privacy policy and prevent customer strings from metric labels.
- [ ] Define dashboards for web control plane, billing, crawl fleet, render fleet, integrations and database.
- [ ] Define symptom/customer-impact alerts with thresholds initially marked hypotheses and links to runbooks.
- [ ] Add synthetic low-risk checks for health, queue, object storage and key provider configuration.
- [ ] Test redaction/cardinality and failure behavior when observability provider is unavailable.
- [ ] Document release annotations and incident correlation.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Telemetry must not contain page bodies, tokens or unbounded URLs/queries.
- Do not block customer requests on optional telemetry delivery.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 114 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 114 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 114
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



---

---
id: '115'
title: Optimize indexes, query plans, partitioning and retention
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '114'
status: pending
---

# Prompt 115 — Optimize indexes, query plans, partitioning and retention

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `114`
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
ruby tracking/scripts/prompt_tracker.rb start 115
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

Validate the PostgreSQL design against representative data volumes and make measured, documented performance changes before launch.

## Required references

- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Generate deterministic representative datasets for organizations/projects, million-scale frontier rows and multi-million finding/usage occurrences without production data.
2. Capture `EXPLAIN (ANALYZE, BUFFERS)` for critical tenant lists, frontier leasing, finding filters, dashboard aggregates, usage checks, schedules and report snapshots.
3. Add/adjust composite, partial and covering indexes only from measured query shapes; check write amplification.
4. Implement or document partitioning/retention for the highest-volume tables with safe migration path.
5. Eliminate N+1 and unbounded queries; add pagination and statement timeouts.
6. Review foreign keys/cascades and deletion jobs for lock risk.
7. Set performance regression tests/budgets for key operations.
8. Document autovacuum/analyze/bloat and connection-pool monitoring.

## Required verification

- Benchmark before/after with dataset and environment recorded.
- Migration safety/lock-time review.
- Run full tests and representative concurrent frontier/quota workloads.
- Verify indexes are used and no tenant filter is missing.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Generate deterministic representative datasets for organizations/projects, million-scale frontier rows and multi-million finding/usage occurrences without production data.
- [ ] Capture `EXPLAIN (ANALYZE, BUFFERS)` for critical tenant lists, frontier leasing, finding filters, dashboard aggregates, usage checks, schedules and report snapshots.
- [ ] Add/adjust composite, partial and covering indexes only from measured query shapes; check write amplification.
- [ ] Implement or document partitioning/retention for the highest-volume tables with safe migration path.
- [ ] Eliminate N+1 and unbounded queries; add pagination and statement timeouts.
- [ ] Review foreign keys/cascades and deletion jobs for lock risk.
- [ ] Set performance regression tests/budgets for key operations.
- [ ] Document autovacuum/analyze/bloat and connection-pool monitoring.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not add indexes speculatively without query evidence.
- Do not disable database constraints for speed.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 115 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 115 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 115
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



---

---
id: '116'
title: Build hardened production images and process topology
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '115'
status: pending
---

# Prompt 116 — Build hardened production images and process topology

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `115`
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
ruby tracking/scripts/prompt_tracker.rb start 116
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

Produce reproducible non-root application/browser images and executable process definitions for web, scheduler and specialized workers.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/adr/0007_isolated_browser_workers.md`
- `docs/adr/0010_docker_and_kamal_deployment.md`

## Required work

1. Create multi-stage Dockerfile(s) pinning Ruby, Bundler, system packages, Node/Lighthouse and Chromium versions with release metadata.
2. Minimize final images, remove build credentials/caches and run as non-root with explicit writable temp directories.
3. Configure correct signal handling, graceful shutdown and health checks for each role.
4. Define process commands/queue filters for web, scheduler, default, crawl, render, analysis and report roles.
5. Set browser container security/resource/egress assumptions and document host requirements.
6. Generate SBOM and run container/dependency vulnerability scans in CI; triage findings rather than suppressing globally.
7. Prove assets, migrations and boots do not require network access beyond documented runtime dependencies.
8. Add local compose or scripts for production-like smoke without making compose the production orchestrator.

## Required verification

- Build images from clean cache.
- Run as non-root/read-only where configured and probe `/up`/`ready`.
- Execute one job per worker role and one render fixture.
- Run image/SBOM/vulnerability checks and record results.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create multi-stage Dockerfile(s) pinning Ruby, Bundler, system packages, Node/Lighthouse and Chromium versions with release metadata.
- [ ] Minimize final images, remove build credentials/caches and run as non-root with explicit writable temp directories.
- [ ] Configure correct signal handling, graceful shutdown and health checks for each role.
- [ ] Define process commands/queue filters for web, scheduler, default, crawl, render, analysis and report roles.
- [ ] Set browser container security/resource/egress assumptions and document host requirements.
- [ ] Generate SBOM and run container/dependency vulnerability scans in CI; triage findings rather than suppressing globally.
- [ ] Prove assets, migrations and boots do not require network access beyond documented runtime dependencies.
- [ ] Add local compose or scripts for production-like smoke without making compose the production orchestrator.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never bake Rails credentials/provider secrets into images.
- Do not disable the browser sandbox merely for convenience.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 116 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 116 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 116
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



---

---
id: '117'
title: Configure staging and production deployment with Kamal
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '116'
status: pending
---

# Prompt 117 — Configure staging and production deployment with Kamal

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `116`
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
ruby tracking/scripts/prompt_tracker.rb start 117
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

Create environment-separated Kamal deployment configuration, secret contracts, role topology, health checks and rollback commands without embedding real infrastructure credentials.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/adr/0010_docker_and_kamal_deployment.md`

## Required work

1. Verify the current compatible Kamal release/documentation before pinning.
2. Create production and staging destination/config templates for web and specialized worker roles using immutable image tags.
3. Configure Kamal Proxy routing/TLS/health readiness, deploy timeouts, drain behavior and rolling strategy.
4. Define accessories only where truly operated by Kamal; prefer managed PostgreSQL/object storage in production.
5. Integrate secrets through the deployment secret mechanism with placeholder references and rotation notes.
6. Implement pre-deploy migration and post-deploy smoke hooks using safe expand/migrate/contract practices.
7. Create `bin/deploy`, `bin/rollback` and dry-run/config validation helpers with guardrails against wrong environment.
8. Document first deploy, routine deploy, rollback and host replacement.

## Required verification

- Run Kamal config validation for staging/production templates.
- Perform a local/test-host dry run without real production mutation.
- Test wrong-environment/untagged-image guardrails.
- Verify rollback references a known immutable prior image.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Verify the current compatible Kamal release/documentation before pinning.
- [ ] Create production and staging destination/config templates for web and specialized worker roles using immutable image tags.
- [ ] Configure Kamal Proxy routing/TLS/health readiness, deploy timeouts, drain behavior and rolling strategy.
- [ ] Define accessories only where truly operated by Kamal; prefer managed PostgreSQL/object storage in production.
- [ ] Integrate secrets through the deployment secret mechanism with placeholder references and rotation notes.
- [ ] Implement pre-deploy migration and post-deploy smoke hooks using safe expand/migrate/contract practices.
- [ ] Create `bin/deploy`, `bin/rollback` and dry-run/config validation helpers with guardrails against wrong environment.
- [ ] Document first deploy, routine deploy, rollback and host replacement.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not run an actual production deploy without explicit operator credentials/approval.
- No secrets or real host keys in Git.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 117 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 117 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 117
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



---

---
id: '118'
title: Execute production security, backup and disaster-recovery hardening
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '117'
status: pending
---

# Prompt 118 — Execute production security, backup and disaster-recovery hardening

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `117`
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
ruby tracking/scripts/prompt_tracker.rb start 118
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

Turn the threat model and operations plan into verified launch controls, recovery evidence and incident runbooks.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Perform a focused security review of tenant isolation, OAuth, session, webhook, API key, quota, SSRF, browser, uploads/parsers, artifacts, admin and deployment paths.
2. Run Brakeman, dependency/container scans and all dedicated security suites; remediate or document owned expiring exceptions.
3. Verify infrastructure-level egress blocking from crawl/render runtimes, private object storage, TLS and least-privileged database/storage credentials.
4. Configure backup/PITR policy templates and execute an isolated restore drill using production-like data.
5. Verify encrypted fields can decrypt after restore and key custody/rotation procedure is documented.
6. Execute rollback, stuck-scan, billing-reconciliation and leaked-secret tabletop/runbook drills.
7. Create incident severity/communications/evidence-preservation process and named ownership placeholders.
8. Update threat model with residual risks and launch blockers.

## Required verification

- All security test suites and scanners.
- Network egress tests from actual runtime containers.
- Documented restore verification with measured RPO/RTO evidence.
- Rollback/reconciliation runbook exercises.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Perform a focused security review of tenant isolation, OAuth, session, webhook, API key, quota, SSRF, browser, uploads/parsers, artifacts, admin and deployment paths.
- [ ] Run Brakeman, dependency/container scans and all dedicated security suites; remediate or document owned expiring exceptions.
- [ ] Verify infrastructure-level egress blocking from crawl/render runtimes, private object storage, TLS and least-privileged database/storage credentials.
- [ ] Configure backup/PITR policy templates and execute an isolated restore drill using production-like data.
- [ ] Verify encrypted fields can decrypt after restore and key custody/rotation procedure is documented.
- [ ] Execute rollback, stuck-scan, billing-reconciliation and leaked-secret tabletop/runbook drills.
- [ ] Create incident severity/communications/evidence-preservation process and named ownership placeholders.
- [ ] Update threat model with residual risks and launch blockers.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not mark an unperformed restore as tested.
- Critical unresolved isolation/SSRF/billing corruption risk blocks launch.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 118 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 118 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 118
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



---

---
id: '119'
title: Run final acceptance, pilot readiness and production MVP release review
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '118'
status: pending
---

# Prompt 119 — Run final acceptance, pilot readiness and production MVP release review

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `118`
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
ruby tracking/scripts/prompt_tracker.rb start 119
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

Perform an evidence-based end-to-end review of every milestone, close or explicitly block gaps, and produce the release/pilot handoff without pretending incomplete work is done.

## Required references

- `docs/01_PRD_V1.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/11_ROADMAP_AND_DEFINITION_OF_DONE.md`

## Required work

1. Validate all 120 prompt states, result records, dependencies, documentation/config schemas and repository cleanliness.
2. Run the complete CI-equivalent suite: lint, unit/integration/job/system, tenant isolation, auth, billing, crawler/browser security, assets and production image smoke.
3. Execute end-to-end staging journeys from social login and organization creation through billing, verified crawl, issue verification, integrations, mobile links, release guard, report and API/webhook.
4. Review every launch-scope requirement and non-functional gate in PRD/roadmap with evidence links; mark pass, fail, accepted risk or out of scope.
5. Create `docs/implementation/PRODUCTION_MVP_ACCEPTANCE.md` with versions, test commands/results, known limitations, residual risks, rollback, support/on-call and pilot criteria.
6. Verify legal/commercial placeholders—terms, privacy, retention, billing/tax/provider agreements—are assigned for qualified review and not falsely claimed complete.
7. Create pilot onboarding/runbook and monitoring checklist for the first organizations.
8. Make a factual go/no-go recommendation. Do not deploy automatically.

## Required verification

- Run `ruby tracking/scripts/prompt_tracker.rb validate` and archive status output.
- Run every required CI/security/system command and record exact outcomes.
- Run production image/container/Kamal configuration smoke.
- Review acceptance file against `docs/11_ROADMAP_AND_DEFINITION_OF_DONE.md`.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Validate all 120 prompt states, result records, dependencies, documentation/config schemas and repository cleanliness.
- [ ] Run the complete CI-equivalent suite: lint, unit/integration/job/system, tenant isolation, auth, billing, crawler/browser security, assets and production image smoke.
- [ ] Execute end-to-end staging journeys from social login and organization creation through billing, verified crawl, issue verification, integrations, mobile links, release guard, report and API/webhook.
- [ ] Review every launch-scope requirement and non-functional gate in PRD/roadmap with evidence links; mark pass, fail, accepted risk or out of scope.
- [ ] Create `docs/implementation/PRODUCTION_MVP_ACCEPTANCE.md` with versions, test commands/results, known limitations, residual risks, rollback, support/on-call and pilot criteria.
- [ ] Verify legal/commercial placeholders—terms, privacy, retention, billing/tax/provider agreements—are assigned for qualified review and not falsely claimed complete.
- [ ] Create pilot onboarding/runbook and monitoring checklist for the first organizations.
- [ ] Make a factual go/no-go recommendation. Do not deploy automatically.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not mark this prompt complete if any required test is unrun without a documented blocking reason.
- Do not deploy to production as an implicit step of acceptance.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 119 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 119 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 119
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



---
