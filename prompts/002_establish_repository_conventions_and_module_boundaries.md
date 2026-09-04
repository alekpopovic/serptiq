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
