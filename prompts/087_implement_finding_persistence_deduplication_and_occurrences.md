---
id: 087
title: Implement finding persistence, deduplication and occurrences
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 086
status: pending
---

# Prompt 087 — Implement finding persistence, deduplication and occurrences

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `086`
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
ruby tracking/scripts/prompt_tracker.rb start 087
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

Persist rule results as stable findings with per-scan occurrences, evidence lineage and lifecycle behavior across changing scans/rule versions.

## Required references

- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Create findings as organization/project/property-level identities and finding occurrences linked to scan, subject, rule key/version, outcome, evidence and timestamps.
2. Define deterministic fingerprint inputs and version; prevent cross-tenant collisions.
3. Upsert occurrences idempotently and update first/last seen/count/status without overwriting historical evidence.
4. Represent present, absent-in-latest, verification-pending, resolved-candidate, suppressed and reopened behavior explicitly.
5. Handle rule-version/fingerprint migrations conservatively.
6. Store large evidence as artifacts and bounded searchable summaries in PostgreSQL.
7. Create list/detail filters by severity/category/status/property/scan.
8. Add indexes/partition/retention strategy.

## Required verification

- First/repeat/disappear/reappear/idempotent occurrence tests.
- Rule-version and fingerprint migration tests.
- Concurrent upsert tests.
- Cross-tenant and high-volume query tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create findings as organization/project/property-level identities and finding occurrences linked to scan, subject, rule key/version, outcome, evidence and timestamps.
- [ ] Define deterministic fingerprint inputs and version; prevent cross-tenant collisions.
- [ ] Upsert occurrences idempotently and update first/last seen/count/status without overwriting historical evidence.
- [ ] Represent present, absent-in-latest, verification-pending, resolved-candidate, suppressed and reopened behavior explicitly.
- [ ] Handle rule-version/fingerprint migrations conservatively.
- [ ] Store large evidence as artifacts and bounded searchable summaries in PostgreSQL.
- [ ] Create list/detail filters by severity/category/status/property/scan.
- [ ] Add indexes/partition/retention strategy.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never overwrite prior scan evidence.
- Absence from a partial/failed scan is not automatic resolution.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 087 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 087 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 087
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
