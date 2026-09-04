---
id: '105'
title: Implement the web-to-app route map
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '104'
status: pending
---

# Prompt 105 — Implement the web-to-app route map

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `104`
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
ruby tracking/scripts/prompt_tracker.rb start 105
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

Model expected relationships between public web URLs, Android App Links, iOS Universal Links and web fallbacks, then verify them from available evidence.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`
- `docs/06_SEO_RULE_CATALOG.md`

## Required work

1. Create route-map entries/patterns scoped to project and environment with web pattern, Android target, iOS target, fallback and priority.
2. Use a safe bounded path-pattern language; reject catastrophic regex or ambiguous overlapping routes.
3. Compile expected route samples from configured templates/known URLs without generating unbounded combinations.
4. Compare web inventory, Android intent filters/assetlinks and iOS entitlements/AASA coverage.
5. Implement missing app destination, missing web landing/fallback, route conflict and inconsistent locale/identifier findings with confidence.
6. Create visual/table route coverage UI with representative evidence and release history.
7. Support CSV/JSON import/export through schema validation and permissions.
8. Allow targeted verification and audit changes.

## Required verification

- Pattern parser/overlap/complexity tests.
- Cross-platform coverage fixtures.
- Partial-evidence confidence tests.
- Cross-tenant import/export/verification tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create route-map entries/patterns scoped to project and environment with web pattern, Android target, iOS target, fallback and priority.
- [ ] Use a safe bounded path-pattern language; reject catastrophic regex or ambiguous overlapping routes.
- [ ] Compile expected route samples from configured templates/known URLs without generating unbounded combinations.
- [ ] Compare web inventory, Android intent filters/assetlinks and iOS entitlements/AASA coverage.
- [ ] Implement missing app destination, missing web landing/fallback, route conflict and inconsistent locale/identifier findings with confidence.
- [ ] Create visual/table route coverage UI with representative evidence and release history.
- [ ] Support CSV/JSON import/export through schema validation and permissions.
- [ ] Allow targeted verification and audit changes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not attempt to launch native apps from server-side validation.
- Route maps describe expectations and evidence, not guaranteed device behavior.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 105 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 105 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 105
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
