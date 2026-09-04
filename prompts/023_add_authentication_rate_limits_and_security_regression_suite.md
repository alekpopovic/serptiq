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
