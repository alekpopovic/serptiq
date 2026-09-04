---
id: 092
title: Implement Search Console connection and property mapping
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 091
status: pending
---

# Prompt 092 — Implement Search Console connection and property mapping

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `091`
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
ruby tracking/scripts/prompt_tracker.rb start 092
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

Add separately consented Search Console OAuth, exact accessible-property selection and tenant-safe mapping to SearchOps properties.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Implement authorization start/callback using the integration credential boundary, state/PKCE/exact redirect and least current scopes.
2. Keep Search Console authorization separate from Google login identity.
3. Fetch accessible sites/properties through a bounded adapter and display only during authorized selection.
4. Map an exact provider property to one SearchOps website property/environment using documented matching rules.
5. Record permission level, mapping actor/time and health status.
6. Handle duplicate mapping, revoked access, scope change and organization/project transfer restrictions.
7. Create connect/reauthorize/disconnect UI protected by integration permissions.
8. Audit all mapping changes.

## Required verification

- OAuth/integration callback security tests.
- URL-prefix/domain-property exact matching fixtures.
- Cross-tenant connection/mapping tests.
- Revocation/reauthorization system tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement authorization start/callback using the integration credential boundary, state/PKCE/exact redirect and least current scopes.
- [ ] Keep Search Console authorization separate from Google login identity.
- [ ] Fetch accessible sites/properties through a bounded adapter and display only during authorized selection.
- [ ] Map an exact provider property to one SearchOps website property/environment using documented matching rules.
- [ ] Record permission level, mapping actor/time and health status.
- [ ] Handle duplicate mapping, revoked access, scope change and organization/project transfer restrictions.
- [ ] Create connect/reauthorize/disconnect UI protected by integration permissions.
- [ ] Audit all mapping changes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not treat social login consent as Search Console consent.
- Do not store or expose all accessible provider properties indefinitely.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 092 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 092 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 092
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
