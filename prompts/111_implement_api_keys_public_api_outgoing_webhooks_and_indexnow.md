---
id: '111'
title: Implement API keys, public API, outgoing webhooks and IndexNow
phase: 10 Reporting, API and administration
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '110'
status: pending
---

# Prompt 111 — Implement API keys, public API, outgoing webhooks and IndexNow

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `110`
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
ruby tracking/scripts/prompt_tracker.rb start 111
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

Expose a bounded versioned API and signed event delivery while preserving scoped authorization, rate limits, auditability and provider semantics.

## Required references

- `schemas/outgoing_webhook_envelope.schema.json`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create hashed API keys with organization/project scope, explicit permission set, name, prefix, expiry, last use and revocation; show secret once.
2. Implement versioned JSON API foundations with stable errors, pagination, idempotency keys and request IDs.
3. Expose only MVP endpoints justified for projects, scans, findings/issues, reports and release results; apply RBAC/entitlement/quota independently.
4. Create outgoing webhook endpoints/subscriptions with encrypted signing secret, event allowlist, delivery queue, HMAC/timestamp, retries and disable-on-failure policy using the envelope schema.
5. Implement SSRF-safe validation/delivery for webhook destinations, including revalidation on redirects and no private networks.
6. Add IndexNow adapter for changed/deleted URLs with key ownership/config, batching/rate limits and accurate 'submitted, not guaranteed indexed' language.
7. Create audit/usage metrics and developer documentation with sanitized examples.
8. Add key rotation/replay tooling.

## Required verification

- API key hash/scope/expiry/revocation and cross-tenant tests.
- API contract/idempotency/rate-limit tests.
- Outgoing webhook signature/retry/replay/SSRF tests.
- IndexNow batching/error/wording tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create hashed API keys with organization/project scope, explicit permission set, name, prefix, expiry, last use and revocation; show secret once.
- [ ] Implement versioned JSON API foundations with stable errors, pagination, idempotency keys and request IDs.
- [ ] Expose only MVP endpoints justified for projects, scans, findings/issues, reports and release results; apply RBAC/entitlement/quota independently.
- [ ] Create outgoing webhook endpoints/subscriptions with encrypted signing secret, event allowlist, delivery queue, HMAC/timestamp, retries and disable-on-failure policy using the envelope schema.
- [ ] Implement SSRF-safe validation/delivery for webhook destinations, including revalidation on redirects and no private networks.
- [ ] Add IndexNow adapter for changed/deleted URLs with key ownership/config, batching/rate limits and accurate 'submitted, not guaranteed indexed' language.
- [ ] Create audit/usage metrics and developer documentation with sanitized examples.
- [ ] Add key rotation/replay tooling.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not allow arbitrary internal webhook destinations.
- IndexNow acknowledgement is not indexing proof.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 111 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 111 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 111
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
