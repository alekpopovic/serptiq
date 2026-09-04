---
id: '112'
title: Implement safe administration and operations dashboards
phase: 10 Reporting, API and administration
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '111'
status: pending
---

# Prompt 112 — Implement safe administration and operations dashboards

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `111`
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
ruby tracking/scripts/prompt_tracker.rb start 112
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

Provide least-privileged support tooling for diagnosing tenants, jobs, integrations, billing and consistency without normalizing direct database edits.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/03_ERD.md`

## Required work

1. Create a separate administration namespace with explicit operator authorization, recent authentication and audited access.
2. Expose safe summaries for organizations, subscriptions, webhook events, queues, stuck scans, integrations, usage reservations, reports and consistency checks.
3. Implement narrowly scoped operations already defined by domain services: replay event, reconcile subscription, retry eligible delivery/job, cancel scan, expire reservation and revoke credential.
4. Require reason/confirmation for high-impact operations and display before/after result.
5. Redact tokens, signatures, page artifacts, personal data and provider payloads by default; gate exceptional access through a separate documented process.
6. Prevent cross-environment actions and accidental bulk operations.
7. Add operator metrics links/runbook references and immutable audit.
8. Create support diagnostic bundle containing IDs/statuses only, no secrets.

## Required verification

- Operator authorization/recent-auth tests.
- Audit and redaction tests for every operation.
- Domain-invariant tests proving admin UI cannot bypass rules.
- Cross-environment/tenant selection safety tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a separate administration namespace with explicit operator authorization, recent authentication and audited access.
- [ ] Expose safe summaries for organizations, subscriptions, webhook events, queues, stuck scans, integrations, usage reservations, reports and consistency checks.
- [ ] Implement narrowly scoped operations already defined by domain services: replay event, reconcile subscription, retry eligible delivery/job, cancel scan, expire reservation and revoke credential.
- [ ] Require reason/confirmation for high-impact operations and display before/after result.
- [ ] Redact tokens, signatures, page artifacts, personal data and provider payloads by default; gate exceptional access through a separate documented process.
- [ ] Prevent cross-environment actions and accidental bulk operations.
- [ ] Add operator metrics links/runbook references and immutable audit.
- [ ] Create support diagnostic bundle containing IDs/statuses only, no secrets.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No generic SQL console or arbitrary model editor.
- Support convenience never overrides tenant isolation or billing mapping identity.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 112 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 112 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 112
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
