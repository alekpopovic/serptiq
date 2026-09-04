---
id: 093
title: Implement Search Analytics import and read models
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 092
status: pending
---

# Prompt 093 — Implement Search Analytics import and read models

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `092`
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
ruby tracking/scripts/prompt_tracker.rb start 093
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

Import Search Console performance aggregates with provenance, quotas and explicit disclosure that returned rows may not be exhaustive.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/03_ERD.md`

## Required work

1. Implement bounded adapter requests for configured date ranges/dimensions/filters, pagination/row limits and aggregation type.
2. Persist import run, request dimensions, provider property, data date/freshness, returned rows and metrics using appropriate numeric precision.
3. Use idempotent keys so retries do not duplicate rows; support incremental re-import/correction windows.
4. Associate page dimensions to normalized known URLs where safe while retaining unmatched rows.
5. Respect provider quotas/rate limits and schedule fairly across organizations.
6. Create project/page/query read models for clicks, impressions, CTR and average position with no unsupported causal claims.
7. Display source freshness, filters, top-row limitation and no-data/error states.
8. Meter/store cost only if configured by plan.

## Required verification

- Adapter pagination/rate-limit/malformed response contracts.
- Idempotent incremental/correction import tests.
- Precision/aggregation/date-boundary tests.
- Cross-tenant read-model and authorization tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement bounded adapter requests for configured date ranges/dimensions/filters, pagination/row limits and aggregation type.
- [ ] Persist import run, request dimensions, provider property, data date/freshness, returned rows and metrics using appropriate numeric precision.
- [ ] Use idempotent keys so retries do not duplicate rows; support incremental re-import/correction windows.
- [ ] Associate page dimensions to normalized known URLs where safe while retaining unmatched rows.
- [ ] Respect provider quotas/rate limits and schedule fairly across organizations.
- [ ] Create project/page/query read models for clicks, impressions, CTR and average position with no unsupported causal claims.
- [ ] Display source freshness, filters, top-row limitation and no-data/error states.
- [ ] Meter/store cost only if configured by plan.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not present the dataset as all search queries.
- Do not mix differently aggregated rows without labeling.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 093 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 093 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 093
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
