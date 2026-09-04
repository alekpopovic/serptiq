---
id: '052'
title: Implement environments and canonical URL origin normalization
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '051'
status: pending
---

# Prompt 052 — Implement environments and canonical URL origin normalization

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `051`
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
ruby tracking/scripts/prompt_tracker.rb start 052
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

Add development/staging/production environments and a strict URL/origin normalizer that later crawler security can trust.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/03_ERD.md`
- `docs/adr/0006_ssrf_safe_crawler_boundary.md`

## Required work

1. Create project/property environments with stable key, kind, display name, primary flag and lifecycle.
2. Implement canonical HTTP(S) origin parsing: scheme, IDNA hostname handling, normalized port, no userinfo, no path/query/fragment for origin fields.
3. Define default-port collapse, trailing-dot behavior, Unicode display vs ASCII network form and exact subdomain boundaries.
4. Require one primary production environment where applicable and enforce uniqueness transactionally.
5. Build environment management UI with warnings for public vs non-public targets.
6. Keep private/internal origins unsupported for MVP unless an explicit future enterprise policy is introduced.
7. Emit audit events for origin changes because they affect verification and scan trust.

## Required verification

- Extensive normalization table tests for IPv4/IPv6/IDNA/ports/userinfo/malformed input.
- Concurrent primary-environment tests.
- Cross-tenant environment tests.
- Security tests rejecting non-HTTP(S) origins.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create project/property environments with stable key, kind, display name, primary flag and lifecycle.
- [ ] Implement canonical HTTP(S) origin parsing: scheme, IDNA hostname handling, normalized port, no userinfo, no path/query/fragment for origin fields.
- [ ] Define default-port collapse, trailing-dot behavior, Unicode display vs ASCII network form and exact subdomain boundaries.
- [ ] Require one primary production environment where applicable and enforce uniqueness transactionally.
- [ ] Build environment management UI with warnings for public vs non-public targets.
- [ ] Keep private/internal origins unsupported for MVP unless an explicit future enterprise policy is introduced.
- [ ] Emit audit events for origin changes because they affect verification and scan trust.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- URL parsing is not SSRF authorization by itself.
- Do not silently rewrite an invalid hostname into a different target.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 052 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 052 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 052
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
