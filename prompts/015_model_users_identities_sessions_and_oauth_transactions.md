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
