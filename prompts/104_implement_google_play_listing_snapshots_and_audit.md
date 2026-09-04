---
id: '104'
title: Implement Google Play listing snapshots and audit
phase: 09 Mobile discovery and release guard
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '103'
status: pending
---

# Prompt 104 — Implement Google Play listing snapshots and audit

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `103`
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
ruby tracking/scripts/prompt_tracker.rb start 104
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

Capture permitted Google Play listing metadata by locale/track/source and produce transparent ASO checks and diffs.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Define provider/manual import adapter using currently permitted Google Play Developer/Console mechanisms and least scopes.
2. Persist snapshots by app, locale, track/territory where available, version and retrieval time.
3. Normalize title, short/full description, categories/tags and media metadata required by configured rules.
4. Implement current documented length/completeness/localization/asset-presence checks with source/effective date.
5. Create listing diff/history and release association.
6. Treat unavailable review/ranking data explicitly and avoid scraping unsupported endpoints.
7. Use encrypted integration credentials and provider quota controls.
8. Create listing overview UI and audit events.

## Required verification

- Adapter/manual import contracts and fixtures.
- Boundary/version tests for current limits.
- Snapshot idempotency/diff tests.
- Credential/cross-tenant/permission tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define provider/manual import adapter using currently permitted Google Play Developer/Console mechanisms and least scopes.
- [ ] Persist snapshots by app, locale, track/territory where available, version and retrieval time.
- [ ] Normalize title, short/full description, categories/tags and media metadata required by configured rules.
- [ ] Implement current documented length/completeness/localization/asset-presence checks with source/effective date.
- [ ] Create listing diff/history and release association.
- [ ] Treat unavailable review/ranking data explicitly and avoid scraping unsupported endpoints.
- [ ] Use encrypted integration credentials and provider quota controls.
- [ ] Create listing overview UI and audit events.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not violate Play provider terms through scraping.
- Do not combine Android technical link validation with store ranking claims.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 104 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 104 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 104
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
