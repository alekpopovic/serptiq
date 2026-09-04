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
