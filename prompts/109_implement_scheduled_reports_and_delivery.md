---
id: '109'
title: Implement scheduled reports and delivery
phase: 10 Reporting, API and administration
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '108'
status: pending
---

# Prompt 109 — Implement scheduled reports and delivery

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `108`
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
ruby tracking/scripts/prompt_tracker.rb start 109
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

Allow entitled organizations to schedule immutable reports and deliver them safely by email or later notification channels.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create report schedules with template, filters, recipients policy, timezone/recurrence, next run and enabled state.
2. Validate frequency, retention and white-label options against current entitlements.
3. Dispatch idempotently with DST/missed-run/overlap behavior parallel to scan schedules.
4. Generate report snapshot before delivery and record delivery attempts/outcomes.
5. Allow only current organization members or explicitly approved addresses according to policy; prevent data exfiltration through arbitrary recipients on lower plans.
6. Use expiring authenticated links rather than large sensitive attachments by default.
7. Create schedule/delivery-history UI and audit changes.
8. Add metrics and repair/retry operation.

## Required verification

- Timezone/DST/duplicate schedule tests.
- Recipient authorization/exfiltration tests.
- Delivery retry/idempotency/link expiry tests.
- Entitlement downgrade behavior tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create report schedules with template, filters, recipients policy, timezone/recurrence, next run and enabled state.
- [ ] Validate frequency, retention and white-label options against current entitlements.
- [ ] Dispatch idempotently with DST/missed-run/overlap behavior parallel to scan schedules.
- [ ] Generate report snapshot before delivery and record delivery attempts/outcomes.
- [ ] Allow only current organization members or explicitly approved addresses according to policy; prevent data exfiltration through arbitrary recipients on lower plans.
- [ ] Use expiring authenticated links rather than large sensitive attachments by default.
- [ ] Create schedule/delivery-history UI and audit changes.
- [ ] Add metrics and repair/retry operation.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not email raw confidential artifacts by default.
- Past-due/archived behavior must follow canonical access policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 109 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 109 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 109
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
