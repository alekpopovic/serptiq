---
id: '075'
title: Implement dedicated Chromium/Ferrum render workers
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '074'
status: pending
---

# Prompt 075 — Implement dedicated Chromium/Ferrum render workers

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `074`
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
ruby tracking/scripts/prompt_tracker.rb start 075
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

Add opt-in JavaScript rendering as an isolated, metered worker capability with reproducible provenance and no execution in web/default workers.

## Required references

- `docs/02_ARCHITECTURE.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/adr/0007_isolated_browser_workers.md`

## Required work

1. Install/pin Chromium and Ferrum-compatible dependencies and record exact versions in image/result provenance.
2. Define render job input from an approved static-fetch URL/destination and scan snapshot.
3. Launch/reuse browser safely according to isolation policy, creating a fresh incognito/context/page per target.
4. Navigate with strict wall-clock/request/byte limits, wait strategy and cancellation.
5. Capture final URL, DOM artifact, screenshot when enabled, console/page errors, timing and selected network summary.
6. Run the same extraction pipeline over rendered DOM and persist source-vs-render relationships.
7. Charge weighted credits idempotently and cap sampling per settings/plan.
8. Create dedicated queue/process command and health metrics.

## Required verification

- End-to-end render of a local JavaScript fixture.
- Queue-routing test proving render job never executes in web/default worker.
- Timeout/crash/cancellation/credit tests.
- Version/provenance and artifact tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Install/pin Chromium and Ferrum-compatible dependencies and record exact versions in image/result provenance.
- [ ] Define render job input from an approved static-fetch URL/destination and scan snapshot.
- [ ] Launch/reuse browser safely according to isolation policy, creating a fresh incognito/context/page per target.
- [ ] Navigate with strict wall-clock/request/byte limits, wait strategy and cancellation.
- [ ] Capture final URL, DOM artifact, screenshot when enabled, console/page errors, timing and selected network summary.
- [ ] Run the same extraction pipeline over rendered DOM and persist source-vs-render relationships.
- [ ] Charge weighted credits idempotently and cap sampling per settings/plan.
- [ ] Create dedicated queue/process command and health metrics.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not pass application/provider secrets into browser environment.
- Do not enable arbitrary browser flags supplied by customers.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 075 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 075 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 075
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
