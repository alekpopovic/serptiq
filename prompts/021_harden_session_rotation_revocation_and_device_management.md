---
id: '021'
title: Harden session rotation, revocation and device management
phase: 02 Identity and sessions
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '020'
status: pending
---

# Prompt 021 — Harden session rotation, revocation and device management

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `020`
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
ruby tracking/scripts/prompt_tracker.rb start 021
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

Complete session security with device/session visibility, rotation and revocation behavior suitable for future organization privilege changes.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Implement session inventory showing safe approximate device/client, creation, last activity and current-session marker.
2. Allow users to revoke one other session or all other sessions, with recent authentication where policy requires.
3. Implement reusable hooks to rotate/revoke sessions after identity changes, ownership transfer, sensitive role changes and suspected compromise.
4. Bound idle and absolute expiry; update last-seen without excessive writes.
5. Protect session-management routes with CSRF, authorization and anti-enumeration behavior.
6. Create maintenance cleanup for expired/revoked sessions.
7. Add structured/audit events for creation, rotation and revocation without raw tokens.

## Required verification

- Request/system tests for session inventory and revocation.
- Tests for idle/absolute expiry and throttled last-seen updates.
- Concurrency tests for current-session rotation and revocation.
- Verify old tokens cannot be replayed.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement session inventory showing safe approximate device/client, creation, last activity and current-session marker.
- [ ] Allow users to revoke one other session or all other sessions, with recent authentication where policy requires.
- [ ] Implement reusable hooks to rotate/revoke sessions after identity changes, ownership transfer, sensitive role changes and suspected compromise.
- [ ] Bound idle and absolute expiry; update last-seen without excessive writes.
- [ ] Protect session-management routes with CSRF, authorization and anti-enumeration behavior.
- [ ] Create maintenance cleanup for expired/revoked sessions.
- [ ] Add structured/audit events for creation, rotation and revocation without raw tokens.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fingerprint users invasively.
- Do not display raw IP histories beyond documented privacy policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 021 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 021 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 021
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
