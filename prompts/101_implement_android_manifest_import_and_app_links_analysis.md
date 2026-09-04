---
id: '101'
title: Implement Android manifest import and App Links analysis
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '100'
status: pending
---

# Prompt 101 — Implement Android manifest import and App Links analysis

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `100`
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
ruby tracking/scripts/prompt_tracker.rb start 101
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

Analyze customer-supplied Android manifest/build metadata to compare declared intent filters with hosted Digital Asset Links.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Define a safe upload/API format for parsed manifest data or bounded XML manifest; document that binary APK/AAB analysis is outside initial scope unless explicitly added.
2. Parse with XXE disabled and strict size/depth/count limits.
3. Extract package, activities, intent filters, schemes/hosts/paths, categories and `autoVerify` metadata needed for App Links.
4. Compare declared hosts/routes with verified website properties and assetlinks statements.
5. Implement autoVerify missing, host unverified, overly broad/narrow route and fallback-risk findings with Android-version caveats.
6. Version the analyzer and retain source artifact hash/release association.
7. Create upload/history/diff UI with authorization and retention.
8. Sanitize all component/path evidence.

## Required verification

- Manifest fixtures for valid, missing autoVerify, multiple hosts/path rules and malformed/XXE.
- Package/property mismatch and cross-tenant tests.
- Analyzer version/diff tests.
- Upload size/content-type/XSS tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define a safe upload/API format for parsed manifest data or bounded XML manifest; document that binary APK/AAB analysis is outside initial scope unless explicitly added.
- [ ] Parse with XXE disabled and strict size/depth/count limits.
- [ ] Extract package, activities, intent filters, schemes/hosts/paths, categories and `autoVerify` metadata needed for App Links.
- [ ] Compare declared hosts/routes with verified website properties and assetlinks statements.
- [ ] Implement autoVerify missing, host unverified, overly broad/narrow route and fallback-risk findings with Android-version caveats.
- [ ] Version the analyzer and retain source artifact hash/release association.
- [ ] Create upload/history/diff UI with authorization and retention.
- [ ] Sanitize all component/path evidence.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not execute uploaded Android code.
- Do not claim device verification across every Android version without actual device evidence.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 101 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 101 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 101
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
