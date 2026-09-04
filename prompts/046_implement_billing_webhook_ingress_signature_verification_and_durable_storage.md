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
