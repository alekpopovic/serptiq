---
id: 099
title: Implement scheduled scans and dynamic recurring tasks
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 098
status: pending
---

# Prompt 099 — Implement scheduled scans and dynamic recurring tasks

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `098`
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
ruby tracking/scripts/prompt_tracker.rb start 099
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

Allow entitled organizations to schedule scans reliably with timezone-aware recurrence, fair admission, deduplication and missed-run policy.

## Required references

- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Create schedules with project/property/environment, scan type, timezone, recurrence, enabled state, next/last run and creator.
2. Validate frequency and concurrency against effective entitlements/global caps.
3. Use Solid Queue recurring/dynamic scheduling or a deterministic dispatcher with database locking; document the chosen current Rails/Solid capability.
4. Generate a stable idempotency key per scheduled occurrence and pass through normal scan admission.
5. Define missed/late run, DST, disabled/archived/past-due and overlapping-scan behavior.
6. Create schedule UI with next-run preview and audit history.
7. Add dispatcher lag/failure metrics and operator repair task.
8. Do not let a scheduler bypass verification, safety, quota or capacity checks.

## Required verification

- Timezone/DST/duplicate dispatcher tests.
- Entitlement downgrade and past-due behavior tests.
- Overlapping/missed-run policy tests.
- Multi-scheduler locking/fairness tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create schedules with project/property/environment, scan type, timezone, recurrence, enabled state, next/last run and creator.
- [ ] Validate frequency and concurrency against effective entitlements/global caps.
- [ ] Use Solid Queue recurring/dynamic scheduling or a deterministic dispatcher with database locking; document the chosen current Rails/Solid capability.
- [ ] Generate a stable idempotency key per scheduled occurrence and pass through normal scan admission.
- [ ] Define missed/late run, DST, disabled/archived/past-due and overlapping-scan behavior.
- [ ] Create schedule UI with next-run preview and audit history.
- [ ] Add dispatcher lag/failure metrics and operator repair task.
- [ ] Do not let a scheduler bypass verification, safety, quota or capacity checks.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not enqueue unlimited catch-up scans after an outage.
- Schedules are intents; every run still passes current admission policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 099 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 099 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 099
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
