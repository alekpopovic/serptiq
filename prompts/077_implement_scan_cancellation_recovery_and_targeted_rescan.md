---
id: '077'
title: Implement scan cancellation, recovery and targeted rescan
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '076'
status: pending
---

# Prompt 077 — Implement scan cancellation, recovery and targeted rescan

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `076`
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
ruby tracking/scripts/prompt_tracker.rb start 077
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

Complete operational scan control so expensive asynchronous work can stop, recover after failures and recheck a bounded set of URLs safely.

## Required references

- `docs/09_TEST_STRATEGY.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/03_ERD.md`

## Required work

1. Implement cooperative cancellation token/state checks for frontier, fetch, extraction, render and downstream analysis jobs.
2. Stop leasing new work, terminate active browser pages within a bound and finalize/release credits accurately.
3. Implement stale scan/lease/job recovery after process loss with idempotent resumption or terminal failure according to attempt policy.
4. Create targeted rescan request for selected findings/URLs using the same authorization, verification, safety and quota boundary.
5. Link targeted scan to source issue/finding and preserve independent snapshots/provenance.
6. Provide UI/admin operations for cancel, retry eligible failures and diagnose stuck work.
7. Add watchdog recurring task and alert metrics.
8. Document operator recovery runbook.

## Required verification

- Cancellation at every pipeline stage.
- Process-crash/stale lease recovery test.
- Targeted-rescan cross-tenant/quota/idempotency tests.
- Credit finalization/release consistency tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement cooperative cancellation token/state checks for frontier, fetch, extraction, render and downstream analysis jobs.
- [ ] Stop leasing new work, terminate active browser pages within a bound and finalize/release credits accurately.
- [ ] Implement stale scan/lease/job recovery after process loss with idempotent resumption or terminal failure according to attempt policy.
- [ ] Create targeted rescan request for selected findings/URLs using the same authorization, verification, safety and quota boundary.
- [ ] Link targeted scan to source issue/finding and preserve independent snapshots/provenance.
- [ ] Provide UI/admin operations for cancel, retry eligible failures and diagnose stuck work.
- [ ] Add watchdog recurring task and alert metrics.
- [ ] Document operator recovery runbook.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not implement forceful database state edits as normal recovery.
- A retry must not overwrite the historical failed scan.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 077 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 077 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 077
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
