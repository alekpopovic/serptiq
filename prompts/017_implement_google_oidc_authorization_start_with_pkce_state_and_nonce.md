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
