---
id: '054'
title: Implement DNS TXT domain verification
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '053'
status: pending
---

# Prompt 054 — Implement DNS TXT domain verification

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `053`
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
ruby tracking/scripts/prompt_tracker.rb start 054
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

Verify domain control through DNS TXT with bounded resolution, exact token matching and clear propagation/error behavior.

## Required references

- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/08_INTEGRATIONS_AND_API.md`

## Required work

1. Create a DNS resolver adapter with timeouts, result-size limits, CNAME/delegation bounds and normalized error categories.
2. Generate an unpredictable single-use TXT challenge at a documented hostname and display it safely.
3. Resolve only the intended verification name, normalize TXT record chunks without accepting near/substring matches and require exact token semantics.
4. Handle NXDOMAIN, no record, propagation, transient resolver failure and multiple records distinctly.
5. Prevent DNS responses from being reused across organizations/challenges.
6. Consume/mark challenge atomically and record resolver evidence without full unrelated DNS data.
7. Add periodic recheck hook according to verification freshness policy.
8. Document local fake DNS testing.

## Required verification

- Resolver contract tests for success/NXDOMAIN/timeout/multiple/chunked TXT.
- Token near-match/case/whitespace tests.
- Concurrent verify/replay tests.
- Cross-tenant and redaction tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Create a DNS resolver adapter with timeouts, result-size limits, CNAME/delegation bounds and normalized error categories.
- [ ] Generate an unpredictable single-use TXT challenge at a documented hostname and display it safely.
- [ ] Resolve only the intended verification name, normalize TXT record chunks without accepting near/substring matches and require exact token semantics.
- [ ] Handle NXDOMAIN, no record, propagation, transient resolver failure and multiple records distinctly.
- [ ] Prevent DNS responses from being reused across organizations/challenges.
- [ ] Consume/mark challenge atomically and record resolver evidence without full unrelated DNS data.
- [ ] Add periodic recheck hook according to verification freshness policy.
- [ ] Document local fake DNS testing.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not use DNS TXT verification as permission to access private IP destinations.
- Do not rely on one global mutable resolver cache for security decisions.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 054 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 054 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 054
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
