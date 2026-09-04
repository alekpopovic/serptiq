---
id: 079
title: Implement HTTP status and redirect rules
phase: 07 Rules, findings and issue workflow
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- 078
status: pending
---

# Prompt 079 — Implement HTTP status and redirect rules

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `078`
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
ruby tracking/scripts/prompt_tracker.rb start 079
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

Implement the first rule family over fetch and redirect-chain snapshots with clear severity, evidence and verification.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/adr/0009_versioned_rule_engine_and_evidence.md`

## Required work

1. Implement configured rules for unreachable URLs, 4xx/5xx responses, soft-error indicators only where evidence is explicit, redirect chains, loops, temporary/permanent mismatch and HTTPS downgrade.
2. Use final and hop response facts from the fetcher; never refetch inside a rule.
3. Differentiate internal entry URL, redirect hop and final URL subjects.
4. Create deterministic fingerprints that remain stable when irrelevant timing/header data changes.
5. Provide bounded evidence showing statuses/locations and remediation grounded in the observed chain.
6. Mark rules not applicable or unknown when required data is missing.
7. Add rule catalog version/source notes and UI grouping.

## Required verification

- Golden fixtures for success, each failure and malformed/incomplete chain.
- Fingerprint stability tests.
- Evidence escaping/size tests.
- Batch execution performance test.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement configured rules for unreachable URLs, 4xx/5xx responses, soft-error indicators only where evidence is explicit, redirect chains, loops, temporary/permanent mismatch and HTTPS downgrade.
- [ ] Use final and hop response facts from the fetcher; never refetch inside a rule.
- [ ] Differentiate internal entry URL, redirect hop and final URL subjects.
- [ ] Create deterministic fingerprints that remain stable when irrelevant timing/header data changes.
- [ ] Provide bounded evidence showing statuses/locations and remediation grounded in the observed chain.
- [ ] Mark rules not applicable or unknown when required data is missing.
- [ ] Add rule catalog version/source notes and UI grouping.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not label a transient fetch failure as a permanent search-engine outcome.
- Do not expose sensitive query values in evidence.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 079 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 079 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 079
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
