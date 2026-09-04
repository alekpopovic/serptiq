---
id: 090
title: Implement scan baselines, diffs and regressions
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 089
status: pending
---

# Prompt 090 — Implement scan baselines, diffs and regressions

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `089`
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
ruby tracking/scripts/prompt_tracker.rb start 090
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

Compare compatible scan snapshots to identify new, resolved, worsened and unchanged findings with explicit coverage/confidence.

## Required references

- `docs/01_PRD_V1.md`
- `docs/03_ERD.md`
- `docs/09_TEST_STRATEGY.md`

## Required work

1. Create baseline selection rules by project/property/environment/scan type/rule catalog and optional release.
2. Persist immutable comparison records with source/target scan IDs, versions, coverage metrics and completion quality.
3. Classify new, resolved-candidate, recurring, severity/priority changed and evidence changed findings.
4. Prevent partial/failed target scans from declaring broad resolution; surface coverage differences.
5. Compare URL inventory, indexability, redirects, canonical/schema and performance summary metrics where compatible.
6. Create regression summary/read models and per-finding diff evidence.
7. Allow approved baseline pin/unpin with audit.
8. Emit domain events for confirmed critical/high regressions.

## Required verification

- Compatibility and partial-coverage matrix tests.
- New/resolved/reopened/version-changed fixtures.
- Baseline authorization/audit tests.
- Large comparison performance/idempotency tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create baseline selection rules by project/property/environment/scan type/rule catalog and optional release.
- [ ] Persist immutable comparison records with source/target scan IDs, versions, coverage metrics and completion quality.
- [ ] Classify new, resolved-candidate, recurring, severity/priority changed and evidence changed findings.
- [ ] Prevent partial/failed target scans from declaring broad resolution; surface coverage differences.
- [ ] Compare URL inventory, indexability, redirects, canonical/schema and performance summary metrics where compatible.
- [ ] Create regression summary/read models and per-finding diff evidence.
- [ ] Allow approved baseline pin/unpin with audit.
- [ ] Emit domain events for confirmed critical/high regressions.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not compare incompatible rule/normalization versions silently.
- A missing URL in a failed scan is not resolved.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 090 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 090 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 090
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
