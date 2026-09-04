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
