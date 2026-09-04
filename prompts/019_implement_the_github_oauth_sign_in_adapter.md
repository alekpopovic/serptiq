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
