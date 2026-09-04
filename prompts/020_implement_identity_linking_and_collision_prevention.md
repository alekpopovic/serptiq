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
