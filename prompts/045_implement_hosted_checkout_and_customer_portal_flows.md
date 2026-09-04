---
id: '045'
title: Implement hosted checkout and customer portal flows
phase: 04 Plans, entitlements, usage and billing
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '044'
status: pending
---

# Prompt 045 — Implement hosted checkout and customer portal flows

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `044`
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
ruby tracking/scripts/prompt_tracker.rb start 045
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

Allow authorized organization billing managers to create secure hosted checkout and portal sessions tied to exact internal plan versions.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/08_INTEGRATIONS_AND_API.md`

## Required work

1. Implement checkout command validating membership, `billing.manage`, target published plan version, currency/interval and organization eligibility.
2. Create/reuse provider customer mapping safely and pass signed/custom metadata required to correlate checkout with organization and plan version.
3. Generate a hosted checkout URL through the adapter and redirect with no-store/referrer-safe behavior.
4. Treat checkout completion redirect as informational only; entitlements change only after verified canonical billing state.
5. Implement customer portal link creation for existing mapped customers.
6. Prevent open redirects, duplicate active checkout confusion and cross-organization customer reuse.
7. Audit checkout/portal creation without storing full URLs or tokens.
8. Build upgrade/manage billing UI states.

## Required verification

- Request/system tests using fake billing adapter.
- Permission, cross-tenant and invalid/retired plan tests.
- Tests proving return redirect does not activate subscription.
- Idempotency/customer mapping race tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement checkout command validating membership, `billing.manage`, target published plan version, currency/interval and organization eligibility.
- [ ] Create/reuse provider customer mapping safely and pass signed/custom metadata required to correlate checkout with organization and plan version.
- [ ] Generate a hosted checkout URL through the adapter and redirect with no-store/referrer-safe behavior.
- [ ] Treat checkout completion redirect as informational only; entitlements change only after verified canonical billing state.
- [ ] Implement customer portal link creation for existing mapped customers.
- [ ] Prevent open redirects, duplicate active checkout confusion and cross-organization customer reuse.
- [ ] Audit checkout/portal creation without storing full URLs or tokens.
- [ ] Build upgrade/manage billing UI states.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never trust browser-return query parameters as payment proof.
- Do not expose provider customer IDs where unnecessary.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 045 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 045 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 045
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
