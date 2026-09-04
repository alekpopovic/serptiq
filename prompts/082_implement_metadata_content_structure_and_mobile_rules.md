---
id: 082
title: Implement metadata, content-structure and mobile rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 081
status: pending
---

# Prompt 082 — Implement metadata, content-structure and mobile rules

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `081`
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
ruby tracking/scripts/prompt_tracker.rb start 082
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

Implement explainable on-page rules over static/rendered snapshots while avoiding arbitrary ranking formulas and unsafe content display.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/01_PRD_V1.md`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Implement configured title, description, H1/heading, language, viewport and basic content-presence rules.
2. Use documented configurable thresholds as heuristic metadata, not provider guarantees; version threshold changes.
3. Detect duplicate titles/descriptions through normalized bounded hashes and representative clusters.
4. Compare static and rendered metadata only when both sources exist.
5. Sanitize/truncate evidence and never render captured HTML as trusted markup.
6. Distinguish exact absence, empty value, duplicate and unknown/unavailable source.
7. Create category summary/read models without one opaque overall ranking score.
8. Document limitations for client-rendered/personalized content.

## Required verification

- Golden fixtures for boundaries, duplicates, malformed markup and missing inputs.
- XSS/evidence escaping tests.
- Threshold versioning tests.
- Cluster performance tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement configured title, description, H1/heading, language, viewport and basic content-presence rules.
- [ ] Use documented configurable thresholds as heuristic metadata, not provider guarantees; version threshold changes.
- [ ] Detect duplicate titles/descriptions through normalized bounded hashes and representative clusters.
- [ ] Compare static and rendered metadata only when both sources exist.
- [ ] Sanitize/truncate evidence and never render captured HTML as trusted markup.
- [ ] Distinguish exact absence, empty value, duplicate and unknown/unavailable source.
- [ ] Create category summary/read models without one opaque overall ranking score.
- [ ] Document limitations for client-rendered/personalized content.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not claim an ideal title/description length guarantees ranking.
- Do not store or display unbounded page text.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 082 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 082 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 082
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
