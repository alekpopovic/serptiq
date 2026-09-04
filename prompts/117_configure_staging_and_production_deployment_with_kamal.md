---
id: '117'
title: Configure staging and production deployment with Kamal
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '116'
status: pending
---

# Prompt 117 — Configure staging and production deployment with Kamal

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `116`
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
ruby tracking/scripts/prompt_tracker.rb start 117
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

Create environment-separated Kamal deployment configuration, secret contracts, role topology, health checks and rollback commands without embedding real infrastructure credentials.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/12_SOURCE_REFERENCES.md`
- `docs/adr/0010_docker_and_kamal_deployment.md`

## Required work

1. Verify the current compatible Kamal release/documentation before pinning.
2. Create production and staging destination/config templates for web and specialized worker roles using immutable image tags.
3. Configure Kamal Proxy routing/TLS/health readiness, deploy timeouts, drain behavior and rolling strategy.
4. Define accessories only where truly operated by Kamal; prefer managed PostgreSQL/object storage in production.
5. Integrate secrets through the deployment secret mechanism with placeholder references and rotation notes.
6. Implement pre-deploy migration and post-deploy smoke hooks using safe expand/migrate/contract practices.
7. Create `bin/deploy`, `bin/rollback` and dry-run/config validation helpers with guardrails against wrong environment.
8. Document first deploy, routine deploy, rollback and host replacement.

## Required verification

- Run Kamal config validation for staging/production templates.
- Perform a local/test-host dry run without real production mutation.
- Test wrong-environment/untagged-image guardrails.
- Verify rollback references a known immutable prior image.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Verify the current compatible Kamal release/documentation before pinning.
- [ ] Create production and staging destination/config templates for web and specialized worker roles using immutable image tags.
- [ ] Configure Kamal Proxy routing/TLS/health readiness, deploy timeouts, drain behavior and rolling strategy.
- [ ] Define accessories only where truly operated by Kamal; prefer managed PostgreSQL/object storage in production.
- [ ] Integrate secrets through the deployment secret mechanism with placeholder references and rotation notes.
- [ ] Implement pre-deploy migration and post-deploy smoke hooks using safe expand/migrate/contract practices.
- [ ] Create `bin/deploy`, `bin/rollback` and dry-run/config validation helpers with guardrails against wrong environment.
- [ ] Document first deploy, routine deploy, rollback and host replacement.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not run an actual production deploy without explicit operator credentials/approval.
- No secrets or real host keys in Git.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 117 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 117 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 117
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
