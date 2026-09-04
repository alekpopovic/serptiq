---
id: '107'
title: Implement release guard policies and status publishing
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '106'
status: pending
---

# Prompt 107 — Implement release guard policies and status publishing

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `106`
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
ruby tracking/scripts/prompt_tracker.rb start 107
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

Evaluate scan regressions against versioned project policies and publish an explainable pass/warn/fail result to CI/CD.

## Required references

- `config_blueprints/release_policy.example.yml`
- `docs/01_PRD_V1.md`
- `docs/08_INTEGRATIONS_AND_API.md`

## Required work

1. Model versioned release policies based on `config_blueprints/release_policy.example.yml`, with thresholds for new critical/high findings, URL/indexability loss, redirects, schema and performance regressions.
2. Validate policy keys/types/bounds and preserve the exact policy snapshot on each evaluation.
3. Evaluate only compatible completed/partial scans with explicit coverage rules and produce pass, warn, fail or inconclusive.
4. List every contributing condition and evidence; do not hide results behind one score.
5. Allow advisory mode before blocking mode and require explicit project authorization to enable blocking.
6. Implement provider-neutral status publisher/webhook callback with retries, signing and idempotency.
7. Create release result UI and downloadable machine-readable result.
8. Audit policy changes and blocking activation.

## Required verification

- Policy parser/boundary/version tests.
- Pass/warn/fail/inconclusive fixtures including partial scan.
- Publisher retry/idempotency/signature tests.
- Authorization and advisory-to-blocking transition tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Model versioned release policies based on `config_blueprints/release_policy.example.yml`, with thresholds for new critical/high findings, URL/indexability loss, redirects, schema and performance regressions.
- [ ] Validate policy keys/types/bounds and preserve the exact policy snapshot on each evaluation.
- [ ] Evaluate only compatible completed/partial scans with explicit coverage rules and produce pass, warn, fail or inconclusive.
- [ ] List every contributing condition and evidence; do not hide results behind one score.
- [ ] Allow advisory mode before blocking mode and require explicit project authorization to enable blocking.
- [ ] Implement provider-neutral status publisher/webhook callback with retries, signing and idempotency.
- [ ] Create release result UI and downloadable machine-readable result.
- [ ] Audit policy changes and blocking activation.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fail a release from missing/incompatible evidence without an explicit inconclusive policy.
- Never claim the gate guarantees ranking impact.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 107 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 107 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 107
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
