---
id: '114'
title: Complete observability, metrics, tracing and alert definitions
phase: 11 Production hardening and launch
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '113'
status: pending
---

# Prompt 114 — Complete observability, metrics, tracing and alert definitions

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `113`
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
ruby tracking/scripts/prompt_tracker.rb start 114
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

Instrument every critical customer and security path with low-cardinality metrics, correlated structured events and actionable alerts/runbooks.

## Required references

- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Implement/request/job correlation and tracing across web, outbox/enqueue, workers, provider calls and status publishing using a provider-neutral interface.
2. Add metrics listed in `docs/10_DEPLOYMENT_AND_OPERATIONS.md` for auth, billing, queue, scan, DNS/SSRF denials, fetch/render, usage, rules, reports, integrations and database health.
3. Hash or omit tenant identifiers according to privacy policy and prevent customer strings from metric labels.
4. Define dashboards for web control plane, billing, crawl fleet, render fleet, integrations and database.
5. Define symptom/customer-impact alerts with thresholds initially marked hypotheses and links to runbooks.
6. Add synthetic low-risk checks for health, queue, object storage and key provider configuration.
7. Test redaction/cardinality and failure behavior when observability provider is unavailable.
8. Document release annotations and incident correlation.

## Required verification

- Instrumentation unit/integration tests on critical paths.
- Redaction and cardinality-budget tests.
- Observability-provider outage test proving product path degrades safely.
- Validate every paging alert references a runbook.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Implement/request/job correlation and tracing across web, outbox/enqueue, workers, provider calls and status publishing using a provider-neutral interface.
- [ ] Add metrics listed in `docs/10_DEPLOYMENT_AND_OPERATIONS.md` for auth, billing, queue, scan, DNS/SSRF denials, fetch/render, usage, rules, reports, integrations and database health.
- [ ] Hash or omit tenant identifiers according to privacy policy and prevent customer strings from metric labels.
- [ ] Define dashboards for web control plane, billing, crawl fleet, render fleet, integrations and database.
- [ ] Define symptom/customer-impact alerts with thresholds initially marked hypotheses and links to runbooks.
- [ ] Add synthetic low-risk checks for health, queue, object storage and key provider configuration.
- [ ] Test redaction/cardinality and failure behavior when observability provider is unavailable.
- [ ] Document release annotations and incident correlation.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Telemetry must not contain page bodies, tokens or unbounded URLs/queries.
- Do not block customer requests on optional telemetry delivery.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 114 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 114 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 114
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
