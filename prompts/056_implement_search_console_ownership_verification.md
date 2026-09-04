---
id: '056'
title: Implement Search Console ownership verification
phase: 05 Projects, properties and verification
recommended_reasoning: high
recommended_model: strongest_available_codex
depends_on:
- '055'
status: pending
---

# Prompt 056 — Implement Search Console ownership verification

## Codex execution settings

- **Recommended reasoning:** `high`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `055`
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
ruby tracking/scripts/prompt_tracker.rb start 056
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

Allow an authorized Search Console connection to serve as property-control evidence without conflating login identity, provider access and SearchOps membership.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Define the verification adapter over a separately consented Search Console integration connection.
2. List/access exact provider property identifiers and match them to the normalized SearchOps site property using documented URL-prefix/domain-property rules.
3. Require the current member to have both integration and property-management permissions.
4. Record provider permission level, checked timestamp and external property identifier.
5. Handle revoked scopes, inaccessible property, provider outage and ambiguous match.
6. Do not retain broader property lists longer than necessary.
7. Reverify on token/account/property-origin changes.
8. Create UI to select an exact eligible property and explain provider-known proof.

## Required verification

- Adapter tests for URL-prefix/domain property matching.
- Permission and cross-tenant connection tests.
- Revoked/insufficient provider permission tests.
- Ambiguous/no-match tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define the verification adapter over a separately consented Search Console integration connection.
- [ ] List/access exact provider property identifiers and match them to the normalized SearchOps site property using documented URL-prefix/domain-property rules.
- [ ] Require the current member to have both integration and property-management permissions.
- [ ] Record provider permission level, checked timestamp and external property identifier.
- [ ] Handle revoked scopes, inaccessible property, provider outage and ambiguous match.
- [ ] Do not retain broader property lists longer than necessary.
- [ ] Reverify on token/account/property-origin changes.
- [ ] Create UI to select an exact eligible property and explain provider-known proof.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- A Google login session is not automatically a Search Console authorization.
- Do not infer sibling-domain ownership.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 056 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 056 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 056
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
