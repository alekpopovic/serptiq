---
id: '074'
title: Implement HTML extraction and internal link graph
phase: 06 Safe crawling and rendering
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '073'
status: pending
---

# Prompt 074 — Implement HTML extraction and internal link graph

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `073`
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
ruby tracking/scripts/prompt_tracker.rb start 074
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

Extract normalized page facts and links from untrusted HTML for rule evaluation and graph analysis without executing scripts.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/03_ERD.md`

## Required work

1. Parse bounded HTML using a maintained tolerant parser and capture title, meta directives, headings, canonical, hreflang, links, images, structured-data blocks and language hints.
2. Resolve relative URLs against the effective document/base URL using explicit rules and apply normalization/scope before discovery.
3. Persist page snapshots/facts and directed internal/external link edges with source locator, rel, anchor summary and nofollow metadata.
4. Bound node counts, attribute/text lengths and structured data size; sanitize all displayed snippets.
5. Record parser/version/content hash and distinguish absent, malformed and unavailable facts.
6. Detect duplicate edges efficiently and prepare graph read models for broken/orphan/internal depth rules.
7. Do not store full visible text in PostgreSQL unless a bounded derived representation is required.
8. Add extraction fixtures for malformed/adversarial HTML.

## Required verification

- Fixture tests for relative/base/canonical/hreflang/link/image/schema extraction.
- Malformed/huge DOM/attribute/XSS display tests.
- URL discovery and graph deduplication tests.
- Performance test on a large bounded document.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Parse bounded HTML using a maintained tolerant parser and capture title, meta directives, headings, canonical, hreflang, links, images, structured-data blocks and language hints.
- [ ] Resolve relative URLs against the effective document/base URL using explicit rules and apply normalization/scope before discovery.
- [ ] Persist page snapshots/facts and directed internal/external link edges with source locator, rel, anchor summary and nofollow metadata.
- [ ] Bound node counts, attribute/text lengths and structured data size; sanitize all displayed snippets.
- [ ] Record parser/version/content hash and distinguish absent, malformed and unavailable facts.
- [ ] Detect duplicate edges efficiently and prepare graph read models for broken/orphan/internal depth rules.
- [ ] Do not store full visible text in PostgreSQL unless a bounded derived representation is required.
- [ ] Add extraction fixtures for malformed/adversarial HTML.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Parsing HTML is not authorization to fetch every referenced URL.
- Never render unescaped evidence snippets.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 074 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 074 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 074
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
