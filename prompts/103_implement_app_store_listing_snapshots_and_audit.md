---
id: '103'
title: Implement App Store listing snapshots and audit
phase: 09 Mobile discovery and release guard
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '102'
status: pending
---

# Prompt 103 — Implement App Store listing snapshots and audit

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `102`
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
ruby tracking/scripts/prompt_tracker.rb start 103
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

Capture authorized/manual Apple App Store product metadata snapshots, version changes and bounded ASO checks without scraping prohibited data.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Define provider/manual import adapter based on currently permitted App Store Connect/public metadata access and document required credentials/agreements.
2. Persist listing snapshots by app, locale, store territory/source, version and retrieval time.
3. Normalize name, subtitle, keyword field when authorized, description, promotional text, categories and media metadata needed for rules.
4. Implement current documented length/completeness/localization checks with source/effective date and no ranking guarantees.
5. Create snapshot diff/history and release association.
6. Handle missing/private fields as unknown rather than inferred.
7. Encrypt credentials through integration connection boundary and respect provider quotas.
8. Create listing overview UI and audit events.

## Required verification

- Adapter/manual import contracts and sanitized fixtures.
- Length-boundary/source-version tests.
- Snapshot idempotency/diff tests.
- Credential/cross-tenant/permission tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define provider/manual import adapter based on currently permitted App Store Connect/public metadata access and document required credentials/agreements.
- [ ] Persist listing snapshots by app, locale, store territory/source, version and retrieval time.
- [ ] Normalize name, subtitle, keyword field when authorized, description, promotional text, categories and media metadata needed for rules.
- [ ] Implement current documented length/completeness/localization checks with source/effective date and no ranking guarantees.
- [ ] Create snapshot diff/history and release association.
- [ ] Handle missing/private fields as unknown rather than inferred.
- [ ] Encrypt credentials through integration connection boundary and respect provider quotas.
- [ ] Create listing overview UI and audit events.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not scrape or automate beyond provider terms.
- Do not claim metadata changes guarantee App Store ranking.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 103 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 103 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 103
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
