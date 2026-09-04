---
id: '102'
title: Implement iOS AASA and Associated Domains validation
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '101'
status: pending
---

# Prompt 102 — Implement iOS AASA and Associated Domains validation

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `101`
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
ruby tracking/scripts/prompt_tracker.rb start 102
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

Validate iOS Universal Links using exact app identifiers, declared domains and bounded Apple App Site Association retrieval.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Complete iOS property fields for Team ID, Bundle ID and expected associated domains with strict validation.
2. Fetch AASA from supported well-known/root locations on approved verified HTTPS hosts through safe HTTP policy.
3. Parse bounded JSON without remote resolution and evaluate `applinks` details/components/paths for exact app identifiers and routes.
4. Implement missing, invalid, app ID mismatch, associated-domain missing and route coverage findings.
5. Support multiple app IDs/environments deliberately and version parser semantics.
6. Store source hash/retrieval time/evidence and create overview/targeted recheck UI.
7. Accept a customer-supplied entitlement export/config in a bounded non-executable format for comparison.
8. Audit changes and meter validations.

## Required verification

- Fixtures for valid legacy/current structures, malformed/oversized and route mismatch.
- HTTPS/redirect/private-network tests.
- Team+Bundle identifier exact-match tests.
- Cross-tenant configuration/upload tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Complete iOS property fields for Team ID, Bundle ID and expected associated domains with strict validation.
- [ ] Fetch AASA from supported well-known/root locations on approved verified HTTPS hosts through safe HTTP policy.
- [ ] Parse bounded JSON without remote resolution and evaluate `applinks` details/components/paths for exact app identifiers and routes.
- [ ] Implement missing, invalid, app ID mismatch, associated-domain missing and route coverage findings.
- [ ] Support multiple app IDs/environments deliberately and version parser semantics.
- [ ] Store source hash/retrieval time/evidence and create overview/targeted recheck UI.
- [ ] Accept a customer-supplied entitlement export/config in a bounded non-executable format for comparison.
- [ ] Audit changes and meter validations.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not execute uploaded iOS artifacts.
- Do not claim on-device Universal Link success without device testing.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 102 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 102 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 102
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
