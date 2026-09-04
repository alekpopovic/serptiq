---
id: 097
title: Build the field, lab and crawl performance read model
phase: 08 Search and performance integrations
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 096
status: pending
---

# Prompt 097 — Build the field, lab and crawl performance read model

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `096`
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
ruby tracking/scripts/prompt_tracker.rb start 097
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

Present performance evidence from CrUX, Lighthouse and crawler timings as distinct sources with compatible trends and honest uncertainty.

## Required references

- `docs/01_PRD_V1.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Create read models grouping field data, lab runs and crawl/network timings without merging them into one unlabeled number.
2. Normalize units and metric names while preserving source, device/profile, URL/origin scope, period and version.
3. Display current value, threshold classification, trend and no-data/error/stale states.
4. Allow representative-page/template grouping with explicit selection metadata.
5. Create performance findings only from source-appropriate rules and confidence.
6. Add accessible tables and lightweight charts with textual equivalents.
7. Optimize queries and cache read models using revision-based invalidation.
8. Document interpretation limitations.

## Required verification

- View/read-model tests for all source/no-data combinations.
- Unit conversion and threshold boundary tests.
- Accessibility tests for charts/tables.
- Query-count/performance tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create read models grouping field data, lab runs and crawl/network timings without merging them into one unlabeled number.
- [ ] Normalize units and metric names while preserving source, device/profile, URL/origin scope, period and version.
- [ ] Display current value, threshold classification, trend and no-data/error/stale states.
- [ ] Allow representative-page/template grouping with explicit selection metadata.
- [ ] Create performance findings only from source-appropriate rules and confidence.
- [ ] Add accessible tables and lightweight charts with textual equivalents.
- [ ] Optimize queries and cache read models using revision-based invalidation.
- [ ] Document interpretation limitations.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not average incompatible field and lab measurements.
- Do not imply correlation proves an SEO ranking cause.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 097 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 097 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 097
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
