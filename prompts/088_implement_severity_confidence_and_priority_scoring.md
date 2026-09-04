---
id: 088
title: Implement severity, confidence and priority scoring
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 087
status: pending
---

# Prompt 088 — Implement severity, confidence and priority scoring

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `087`
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
ruby tracking/scripts/prompt_tracker.rb start 088
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

Create transparent prioritization that combines rule severity, evidence confidence, affected scope/traffic, recurrence and effort without hiding raw facts.

## Required references

- `docs/01_PRD_V1.md`
- `docs/06_SEO_RULE_CATALOG.md`
- `docs/03_ERD.md`

## Required work

1. Define immutable value objects and versioned formula/configuration for severity weight, confidence, affected-page/traffic factor, recurrence and estimated effort.
2. Keep raw rule severity/confidence visible independently from computed priority.
3. Handle missing traffic/effort explicitly with documented neutral/default behavior.
4. Bound every factor and protect against outliers/manipulated provider data.
5. Persist score version and components with occurrence/read model so historical ordering is explainable.
6. Allow authorized project-level severity/effort adjustments as audited overlays, not mutation of rule truth.
7. Create sortable priority UI with explanation breakdown.
8. Add recalculation job for formula-version changes without rewriting occurrence facts.

## Required verification

- Table-driven scoring and boundary tests.
- Missing/outlier input tests.
- Historical score-version reproducibility.
- Authorization/audit tests for overrides.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define immutable value objects and versioned formula/configuration for severity weight, confidence, affected-page/traffic factor, recurrence and estimated effort.
- [ ] Keep raw rule severity/confidence visible independently from computed priority.
- [ ] Handle missing traffic/effort explicitly with documented neutral/default behavior.
- [ ] Bound every factor and protect against outliers/manipulated provider data.
- [ ] Persist score version and components with occurrence/read model so historical ordering is explainable.
- [ ] Allow authorized project-level severity/effort adjustments as audited overlays, not mutation of rule truth.
- [ ] Create sortable priority UI with explanation breakdown.
- [ ] Add recalculation job for formula-version changes without rewriting occurrence facts.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No single score may replace underlying evidence.
- Do not imply calculated priority equals guaranteed traffic/revenue impact.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 088 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 088 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 088
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
