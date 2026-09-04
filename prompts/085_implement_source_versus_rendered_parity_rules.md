---
id: 085
title: Implement source-versus-rendered parity rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 084
status: pending
---

# Prompt 085 — Implement source-versus-rendered parity rules

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `084`
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
ruby tracking/scripts/prompt_tracker.rb start 085
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

Compare static HTML and rendered DOM to detect JavaScript-dependent search visibility risks without assuming every difference is an error.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/adr/0007_isolated_browser_workers.md`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Create matched static/render snapshots using normalized URL, response lineage and scan version.
2. Implement configured parity rules for title, description, canonical, robots, headings, primary links, structured data and materially absent content.
3. Define normalization and significance thresholds per field; version them.
4. Classify additions, removals and conflicts, with lower confidence for nondeterministic/personalized pages.
5. Record browser/static provenance and bounded side-by-side evidence.
6. Identify render failure/timeout separately from content parity.
7. Create parity summary and per-URL diff UI.
8. Allow targeted re-render verification with quota.

## Required verification

- Fixtures for equivalent formatting, meaningful conflict, dynamic noise and missing snapshots.
- Deterministic diff/fingerprint tests.
- Evidence XSS/size tests.
- Targeted verification quota/idempotency tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create matched static/render snapshots using normalized URL, response lineage and scan version.
- [ ] Implement configured parity rules for title, description, canonical, robots, headings, primary links, structured data and materially absent content.
- [ ] Define normalization and significance thresholds per field; version them.
- [ ] Classify additions, removals and conflicts, with lower confidence for nondeterministic/personalized pages.
- [ ] Record browser/static provenance and bounded side-by-side evidence.
- [ ] Identify render failure/timeout separately from content parity.
- [ ] Create parity summary and per-URL diff UI.
- [ ] Allow targeted re-render verification with quota.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Differences are evidence, not automatic proof of indexing failure.
- Rules must not execute new browser work during analysis.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 085 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 085 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 085
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
