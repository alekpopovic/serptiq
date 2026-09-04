---
id: 083
title: Implement internal link and image rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 082
status: pending
---

# Prompt 083 — Implement internal link and image rules

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `082`
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
ruby tracking/scripts/prompt_tracker.rb start 083
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

Analyze the internal graph and image facts for broken links, orphan-risk indicators and accessibility/performance-relevant metadata.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/03_ERD.md`

## Required work

1. Implement broken internal link, redirected internal link, excessive chain, nofollow inconsistency and depth-related rules using captured graph/fetch results.
2. Define orphan-risk only relative to known entry sources/sitemap/crawl coverage and surface that limitation.
3. Implement missing/empty alt, missing dimensions, oversized artifact when measured and lazy-loading misuse rules from available facts.
4. Deduplicate cluster-level findings and include representative source/target evidence.
5. Exclude mailto/tel/javascript/data and unsupported schemes according to explicit applicability.
6. Use bounded anchor/alt snippets and sanitize hostile values.
7. Create internal-link and image summary views with filters/export-ready read models.

## Required verification

- Graph fixtures for broken/redirect/orphan/depth scenarios.
- Coverage-confidence tests.
- Image rule boundary and unknown-byte-size tests.
- Evidence escaping and large-graph performance tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement broken internal link, redirected internal link, excessive chain, nofollow inconsistency and depth-related rules using captured graph/fetch results.
- [ ] Define orphan-risk only relative to known entry sources/sitemap/crawl coverage and surface that limitation.
- [ ] Implement missing/empty alt, missing dimensions, oversized artifact when measured and lazy-loading misuse rules from available facts.
- [ ] Deduplicate cluster-level findings and include representative source/target evidence.
- [ ] Exclude mailto/tel/javascript/data and unsupported schemes according to explicit applicability.
- [ ] Use bounded anchor/alt snippets and sanitize hostile values.
- [ ] Create internal-link and image summary views with filters/export-ready read models.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not infer true orphan status from an incomplete crawl as a certainty.
- Do not fetch arbitrary external images for size analysis without an approved policy.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 083 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 083 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 083
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
