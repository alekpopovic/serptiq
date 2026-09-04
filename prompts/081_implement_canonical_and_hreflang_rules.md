---
id: 081
title: Implement canonical and hreflang rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 080
status: pending
---

# Prompt 081 — Implement canonical and hreflang rules

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `080`
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
ruby tracking/scripts/prompt_tracker.rb start 081
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

Analyze canonical clusters and internationalization declarations using normalized graph facts and explicit uncertainty.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/03_ERD.md`

## Required work

1. Implement missing/multiple/malformed/out-of-scope/canonical-to-error/canonical-chain/canonical-loop and inconsistent canonical rules.
2. Build canonical graph components from scan snapshots without treating declared canonical as crawl authorization.
3. Implement hreflang syntax, self-reference, reciprocal return-link, language/region code, target status/indexability and canonical consistency rules.
4. Support HTTP header and HTML link sources with provenance.
5. Handle partial scan coverage by reducing confidence or returning unknown rather than asserting a broken return link.
6. Create cluster-level subjects/fingerprints and evidence bounded to representative URLs with downloadable detail.
7. Prepare canonical/hreflang overview UI.

## Required verification

- Graph fixtures for chain, loop, cluster and partial coverage.
- Hreflang reciprocal/code/canonical combination fixtures.
- Scope/security tests for external targets.
- Determinism/performance tests on representative graphs.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement missing/multiple/malformed/out-of-scope/canonical-to-error/canonical-chain/canonical-loop and inconsistent canonical rules.
- [ ] Build canonical graph components from scan snapshots without treating declared canonical as crawl authorization.
- [ ] Implement hreflang syntax, self-reference, reciprocal return-link, language/region code, target status/indexability and canonical consistency rules.
- [ ] Support HTTP header and HTML link sources with provenance.
- [ ] Handle partial scan coverage by reducing confidence or returning unknown rather than asserting a broken return link.
- [ ] Create cluster-level subjects/fingerprints and evidence bounded to representative URLs with downloadable detail.
- [ ] Prepare canonical/hreflang overview UI.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not fetch external canonical/hreflang targets outside approved scan scope just to complete a rule.
- Confidence must reflect incomplete crawl coverage.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 081 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 081 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 081
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
