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
