---
id: 095
title: Implement CrUX field-data client and history
phase: 08 Search and performance integrations
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 094
status: pending
---

# Prompt 095 — Implement CrUX field-data client and history

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `094`
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
ruby tracking/scripts/prompt_tracker.rb start 095
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

Import available real-user Core Web Vitals data by URL/origin with period, form-factor and no-data semantics.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/06_SEO_RULE_CATALOG.md`

## Required work

1. Implement adapters for current CrUX API and CrUX History API contracts with bounded HTTP, quota and error handling.
2. Normalize source scope (URL/origin), form factor, collection period, metric distributions and percentile values.
3. Persist versioned field-data snapshots and explicit no-data state.
4. Map only exact normalized URL/origin and avoid substituting origin data without labeling.
5. Create history/read models for LCP, INP and CLS plus good/needs-improvement/poor thresholds sourced/versioned from official guidance.
6. Display collection period/sample limitations and separate mobile/desktop.
7. Schedule fair refresh and handle corrections/idempotency.
8. Add provider health and freshness metrics.

## Required verification

- Adapter fixtures for URL, origin, history, no-data, quota and malformed cases.
- Threshold/boundary/version tests.
- Mapping/labeling tests preventing URL-origin confusion.
- Cross-tenant history tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement adapters for current CrUX API and CrUX History API contracts with bounded HTTP, quota and error handling.
- [ ] Normalize source scope (URL/origin), form factor, collection period, metric distributions and percentile values.
- [ ] Persist versioned field-data snapshots and explicit no-data state.
- [ ] Map only exact normalized URL/origin and avoid substituting origin data without labeling.
- [ ] Create history/read models for LCP, INP and CLS plus good/needs-improvement/poor thresholds sourced/versioned from official guidance.
- [ ] Display collection period/sample limitations and separate mobile/desktop.
- [ ] Schedule fair refresh and handle corrections/idempotency.
- [ ] Add provider health and freshness metrics.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fabricate field data from Lighthouse.
- Thresholds are versioned source-backed values, not hardcoded marketing claims.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 095 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 095 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 095
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
