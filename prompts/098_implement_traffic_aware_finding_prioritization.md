---
id: 098
title: Implement traffic-aware finding prioritization
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 097
status: pending
---

# Prompt 098 — Implement traffic-aware finding prioritization

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `097`
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
ruby tracking/scripts/prompt_tracker.rb start 098
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

Enrich priority with Search Console evidence while preserving explainability, privacy and sane behavior when data is missing or sampled.

## Required references

- `docs/01_PRD_V1.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/03_ERD.md`

## Required work

1. Map finding subjects to exact page performance rows with normalized URL/version and a bounded lookback window.
2. Define traffic factor from impressions/clicks or page importance with robust caps and explicit missing-data default.
3. Prevent a high-traffic low-confidence heuristic from automatically outranking verified critical safety/indexability issues without policy.
4. Persist factor source/date/coverage with score version.
5. Recompute asynchronously after imports without mutating finding evidence.
6. Display why traffic affected priority and disclose top-row/incomplete provider coverage.
7. Allow authorized manual business importance overlay with audit.
8. Add batch performance/indexes.

## Required verification

- Scoring fixtures for high/low/missing/outlier traffic.
- Provider partial-data disclosure tests.
- Recalculation idempotency/version tests.
- Cross-tenant mapping and manual-override authorization tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Map finding subjects to exact page performance rows with normalized URL/version and a bounded lookback window.
- [ ] Define traffic factor from impressions/clicks or page importance with robust caps and explicit missing-data default.
- [ ] Prevent a high-traffic low-confidence heuristic from automatically outranking verified critical safety/indexability issues without policy.
- [ ] Persist factor source/date/coverage with score version.
- [ ] Recompute asynchronously after imports without mutating finding evidence.
- [ ] Display why traffic affected priority and disclose top-row/incomplete provider coverage.
- [ ] Allow authorized manual business importance overlay with audit.
- [ ] Add batch performance/indexes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Missing provider rows do not mean zero traffic.
- Do not expose raw search queries to users lacking project access.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 098 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 098 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 098
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
