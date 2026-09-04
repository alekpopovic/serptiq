---
id: 094
title: Implement URL Inspection import
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 093
status: pending
---

# Prompt 094 — Implement URL Inspection import

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `093`
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
ruby tracking/scripts/prompt_tracker.rb start 094
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

Import bounded Google-known indexed state for authorized URLs and keep it visibly separate from SearchOps live technical state.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Implement adapter request/response normalization for the current URL Inspection API fields and permission/errors.
2. Allow inspection only for URLs within the mapped authorized property and configured bounded batch.
3. Persist inspected URL, provider-known state, response/source version, timestamp and relevant sitemap/referrer metadata.
4. Use provider quota-aware queueing, idempotency and backoff.
5. Create side-by-side UI: SearchOps live fetch/render facts versus Google-known indexed state and timestamp.
6. Generate comparison findings only where semantics are explicit, such as live indexability conflicting with provider-known status, with confidence caveats.
7. Handle no data, inaccessible URL/property and stale records.
8. Audit manual bulk requests and meter them if plan-controlled.

## Required verification

- Adapter fixture tests for representative provider states/errors.
- Out-of-property/cross-tenant denial tests.
- Freshness/no-data UI tests.
- Tests ensuring provider state is never labelled live fetch.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement adapter request/response normalization for the current URL Inspection API fields and permission/errors.
- [ ] Allow inspection only for URLs within the mapped authorized property and configured bounded batch.
- [ ] Persist inspected URL, provider-known state, response/source version, timestamp and relevant sitemap/referrer metadata.
- [ ] Use provider quota-aware queueing, idempotency and backoff.
- [ ] Create side-by-side UI: SearchOps live fetch/render facts versus Google-known indexed state and timestamp.
- [ ] Generate comparison findings only where semantics are explicit, such as live indexability conflicting with provider-known status, with confidence caveats.
- [ ] Handle no data, inaccessible URL/property and stale records.
- [ ] Audit manual bulk requests and meter them if plan-controlled.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use this API as an unrestricted real-time index checker.
- Do not claim an inspection response guarantees current ranking.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 094 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 094 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 094
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
