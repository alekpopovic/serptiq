---
id: '108'
title: Implement immutable report snapshots and export
phase: 10 Reporting, API and administration
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '107'
status: pending
---

# Prompt 108 — Implement immutable report snapshots and export

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `107`
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
ruby tracking/scripts/prompt_tracker.rb start 108
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

Generate reproducible organization/project reports from frozen read-model inputs with private artifacts, source dates and evidence caveats.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Create report definitions/runs/snapshots with organization/project scope, template version, filters, requested/started/completed state and source data cutoffs.
2. Snapshot metrics/findings/comparisons used by a report so later data changes do not rewrite historical output.
3. Generate accessible HTML first and PDF only through a controlled renderer if required; store artifacts privately.
4. Include methodology, coverage, data freshness, rule/catalog versions and limitations.
5. Support technical summary, executive summary, regression and web/mobile route reports according to entitlements.
6. Ensure all customer-controlled content is escaped/sanitized and external resources are not fetched during report rendering.
7. Create authorized download with short-lived URL and retention.
8. Meter generation and make jobs idempotent/cancelable.

## Required verification

- Snapshot immutability and reproducibility tests.
- Cross-tenant artifact/download tests.
- XSS/external-resource/report-size tests.
- Job retry/cancellation/usage tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create report definitions/runs/snapshots with organization/project scope, template version, filters, requested/started/completed state and source data cutoffs.
- [ ] Snapshot metrics/findings/comparisons used by a report so later data changes do not rewrite historical output.
- [ ] Generate accessible HTML first and PDF only through a controlled renderer if required; store artifacts privately.
- [ ] Include methodology, coverage, data freshness, rule/catalog versions and limitations.
- [ ] Support technical summary, executive summary, regression and web/mobile route reports according to entitlements.
- [ ] Ensure all customer-controlled content is escaped/sanitized and external resources are not fetched during report rendering.
- [ ] Create authorized download with short-lived URL and retention.
- [ ] Meter generation and make jobs idempotent/cancelable.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not regenerate an old report silently from current data.
- Report rendering must not become an SSRF path.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 108 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 108 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 108
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
