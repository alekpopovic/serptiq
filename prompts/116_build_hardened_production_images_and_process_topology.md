---
id: '116'
title: Build hardened production images and process topology
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '115'
status: pending
---

# Prompt 116 — Build hardened production images and process topology

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `115`
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
ruby tracking/scripts/prompt_tracker.rb start 116
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

Produce reproducible non-root application/browser images and executable process definitions for web, scheduler and specialized workers.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/adr/0007_isolated_browser_workers.md`
- `docs/adr/0010_docker_and_kamal_deployment.md`

## Required work

1. Create multi-stage Dockerfile(s) pinning Ruby, Bundler, system packages, Node/Lighthouse and Chromium versions with release metadata.
2. Minimize final images, remove build credentials/caches and run as non-root with explicit writable temp directories.
3. Configure correct signal handling, graceful shutdown and health checks for each role.
4. Define process commands/queue filters for web, scheduler, default, crawl, render, analysis and report roles.
5. Set browser container security/resource/egress assumptions and document host requirements.
6. Generate SBOM and run container/dependency vulnerability scans in CI; triage findings rather than suppressing globally.
7. Prove assets, migrations and boots do not require network access beyond documented runtime dependencies.
8. Add local compose or scripts for production-like smoke without making compose the production orchestrator.

## Required verification

- Build images from clean cache.
- Run as non-root/read-only where configured and probe `/up`/`ready`.
- Execute one job per worker role and one render fixture.
- Run image/SBOM/vulnerability checks and record results.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create multi-stage Dockerfile(s) pinning Ruby, Bundler, system packages, Node/Lighthouse and Chromium versions with release metadata.
- [ ] Minimize final images, remove build credentials/caches and run as non-root with explicit writable temp directories.
- [ ] Configure correct signal handling, graceful shutdown and health checks for each role.
- [ ] Define process commands/queue filters for web, scheduler, default, crawl, render, analysis and report roles.
- [ ] Set browser container security/resource/egress assumptions and document host requirements.
- [ ] Generate SBOM and run container/dependency vulnerability scans in CI; triage findings rather than suppressing globally.
- [ ] Prove assets, migrations and boots do not require network access beyond documented runtime dependencies.
- [ ] Add local compose or scripts for production-like smoke without making compose the production orchestrator.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Never bake Rails credentials/provider secrets into images.
- Do not disable the browser sandbox merely for convenience.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 116 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 116 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 116
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
