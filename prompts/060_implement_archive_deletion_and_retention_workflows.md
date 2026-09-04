---
id: '060'
title: Implement archive, deletion and retention workflows
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 059
status: pending
---

# Prompt 060 — Implement archive, deletion and retention workflows

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `059`
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
ruby tracking/scripts/prompt_tracker.rb start 060
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

Define safe lifecycle behavior for projects/properties, including job cancellation, retained evidence and eventual deletion without orphaned artifacts.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/03_ERD.md`

## Required work

1. Implement archive/reactivate and request-deletion/cancel-deletion operations with permissions and recent authentication for destructive actions.
2. Stop new schedules/scans immediately and signal active work for cooperative cancellation.
3. Define retention hold/grace period and what remains readable during it.
4. Create asynchronous deletion workflow ordered across integrations, scans/findings, reports, object artifacts, API keys/webhooks and aggregate records.
5. Use tombstones/audit references where required for billing/security history.
6. Make deletion idempotent, resumable and observable; reconcile failed object deletion.
7. Provide export/delete warnings and final confirmation UI.
8. Document legal/privacy review points rather than asserting universal retention law.

## Required verification

- Lifecycle and authorization tests.
- Active-job cancellation/deletion-resume tests.
- Object-store failure/reconciliation tests.
- Cross-tenant deletion and signed-artifact denial tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement archive/reactivate and request-deletion/cancel-deletion operations with permissions and recent authentication for destructive actions.
- [ ] Stop new schedules/scans immediately and signal active work for cooperative cancellation.
- [ ] Define retention hold/grace period and what remains readable during it.
- [ ] Create asynchronous deletion workflow ordered across integrations, scans/findings, reports, object artifacts, API keys/webhooks and aggregate records.
- [ ] Use tombstones/audit references where required for billing/security history.
- [ ] Make deletion idempotent, resumable and observable; reconcile failed object deletion.
- [ ] Provide export/delete warnings and final confirmation UI.
- [ ] Document legal/privacy review points rather than asserting universal retention law.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not perform large cascades synchronously in a web request.
- Do not delete billing/security audit evidence contrary to documented retention policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 060 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 060 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 060
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
