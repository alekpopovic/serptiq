---
id: '012'
title: Implement structured events and error taxonomy
phase: 01 Rails and operational foundation
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '011'
status: pending
---

# Prompt 012 — Implement structured events and error taxonomy

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `011`
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
ruby tracking/scripts/prompt_tracker.rb start 012
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

Create a consistent observability foundation that records useful operational context while protecting tenant data and credentials.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`

## Required work

1. Define stable application error categories for validation, authentication, authorization, entitlement, quota, conflict, external provider, transient infrastructure, unsafe destination and internal faults.
2. Implement structured event emission with request/job/release correlation and optional safe organization/project/scan identifiers.
3. Add parameter/header/query/payload redaction and tests for OAuth, billing, API key and crawler-sensitive data.
4. Create request and job middleware/hooks that attach correlation context and clear it reliably.
5. Map expected domain errors to safe HTTP responses and user-facing messages without leaking internals.
6. Record exception causes for operators while presenting stable public error codes.
7. Document event naming/versioning, cardinality limits and prohibited fields.

## Required verification

- Test redaction against representative nested payloads and URLs.
- Test request and job context is cleared between executions.
- Test expected domain errors and unexpected faults produce correct status/public code.
- Run logging tests and full suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define stable application error categories for validation, authentication, authorization, entitlement, quota, conflict, external provider, transient infrastructure, unsafe destination and internal faults.
- [ ] Implement structured event emission with request/job/release correlation and optional safe organization/project/scan identifiers.
- [ ] Add parameter/header/query/payload redaction and tests for OAuth, billing, API key and crawler-sensitive data.
- [ ] Create request and job middleware/hooks that attach correlation context and clear it reliably.
- [ ] Map expected domain errors to safe HTTP responses and user-facing messages without leaking internals.
- [ ] Record exception causes for operators while presenting stable public error codes.
- [ ] Document event naming/versioning, cardinality limits and prohibited fields.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not log raw page bodies by default.
- Do not use customer-controlled strings as metric names or unbounded labels.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 012 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 012 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 012
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
