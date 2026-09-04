---
id: 096
title: Implement isolated Lighthouse runner
phase: 08 Search and performance integrations
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 095
status: pending
---

# Prompt 096 — Implement isolated Lighthouse runner

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `095`
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
ruby tracking/scripts/prompt_tracker.rb start 096
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

Run Lighthouse as a controlled, versioned lab analysis in dedicated workers with network safety, metering and artifact provenance.

## Required references

- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0007_isolated_browser_workers.md`

## Required work

1. Pin Node/Lighthouse/Chromium versions in the render/performance image and record them per run.
2. Define Lighthouse job admission from an approved property URL and representative-page sampling policy.
3. Apply the safe destination/browser egress controls, wall time, CPU/memory, request and artifact limits.
4. Run selected categories/configuration with deterministic device/network profile metadata.
5. Persist normalized metrics/audits and store full JSON as private artifact.
6. Classify tool crash, page failure, timeout and no-result separately.
7. Charge credits idempotently and support cancellation/retry bounds.
8. Create operator metrics and customer lab-result UI.

## Required verification

- Local fixture end-to-end run.
- Unsafe subresource/private redirect tests.
- Timeout/crash/cancellation/credit tests.
- Provenance/artifact authorization tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Pin Node/Lighthouse/Chromium versions in the render/performance image and record them per run.
- [ ] Define Lighthouse job admission from an approved property URL and representative-page sampling policy.
- [ ] Apply the safe destination/browser egress controls, wall time, CPU/memory, request and artifact limits.
- [ ] Run selected categories/configuration with deterministic device/network profile metadata.
- [ ] Persist normalized metrics/audits and store full JSON as private artifact.
- [ ] Classify tool crash, page failure, timeout and no-result separately.
- [ ] Charge credits idempotently and support cancellation/retry bounds.
- [ ] Create operator metrics and customer lab-result UI.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Lighthouse is lab data, not real-user field data.
- Do not run it in the web/default worker.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 096 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 096 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 096
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
