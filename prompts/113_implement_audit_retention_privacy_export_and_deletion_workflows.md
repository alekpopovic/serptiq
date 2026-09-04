---
id: '113'
title: Implement audit retention, privacy export and deletion workflows
phase: 10 Reporting, API and administration
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '112'
status: pending
---

# Prompt 113 — Implement audit retention, privacy export and deletion workflows

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `112`
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
ruby tracking/scripts/prompt_tracker.rb start 113
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

Complete tenant/user data governance with documented retention, export and deletion operations that preserve required integrity and remove artifacts safely.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/03_ERD.md`

## Required work

1. Classify stored data by domain, sensitivity, owner, default retention, deletion trigger and legal/operational hold placeholder.
2. Implement configurable retention jobs for sessions, OAuth transactions, crawl artifacts, rendered artifacts, provider payloads, notifications, reports and high-volume occurrences according to entitlements/policy.
3. Create user/organization export manifests with authorized bounded asynchronous generation and private expiring download.
4. Implement account deletion/anonymization workflow that handles active ownership, memberships, identity links, comments/audit attribution and billing records.
5. Preserve minimal security/billing evidence only under documented policy and pseudonymize where appropriate.
6. Make deletion/export idempotent, resumable and observable across PostgreSQL/object storage.
7. Create customer UI and operator runbook.
8. Add reconciliation for orphaned/missing objects.

## Required verification

- Retention boundary and legal-hold placeholder tests.
- Export cross-tenant/authorization/artifact tests.
- Deletion ownership/block/resume/anonymization tests.
- Object/database reconciliation tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Classify stored data by domain, sensitivity, owner, default retention, deletion trigger and legal/operational hold placeholder.
- [ ] Implement configurable retention jobs for sessions, OAuth transactions, crawl artifacts, rendered artifacts, provider payloads, notifications, reports and high-volume occurrences according to entitlements/policy.
- [ ] Create user/organization export manifests with authorized bounded asynchronous generation and private expiring download.
- [ ] Implement account deletion/anonymization workflow that handles active ownership, memberships, identity links, comments/audit attribution and billing records.
- [ ] Preserve minimal security/billing evidence only under documented policy and pseudonymize where appropriate.
- [ ] Make deletion/export idempotent, resumable and observable across PostgreSQL/object storage.
- [ ] Create customer UI and operator runbook.
- [ ] Add reconciliation for orphaned/missing objects.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not assert legal compliance without counsel.
- Do not erase immutable billing/security evidence outside documented policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 113 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 113 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 113
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
