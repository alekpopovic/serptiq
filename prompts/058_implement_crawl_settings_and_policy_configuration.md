---
id: 058
title: Implement crawl settings and policy configuration
phase: 05 Projects, properties and verification
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- '057'
status: pending
---

# Prompt 058 — Implement crawl settings and policy configuration

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `057`
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
ruby tracking/scripts/prompt_tracker.rb start 058
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

Store validated per-environment crawl policy with safe defaults, plan bounds and immutable snapshots for each scan.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`
- `docs/05_PLAN_ENTITLEMENT_MATRIX.md`

## Required work

1. Model settings for start URLs/sitemaps, include/exclude patterns, maximum URLs/depth, query handling, user agent, rate/concurrency, robots behavior, rendering sampling and artifact retention.
2. Validate all values against global safety caps and effective entitlements; organization settings may reduce but never exceed global policy.
3. Compile patterns safely with complexity/length limits to avoid regex denial of service.
4. Normalize start URLs to the verified allowed origin and reject credentials, fragments or unsupported schemes.
5. Version settings and snapshot the exact effective configuration into each scan.
6. Create settings UI with estimates/credit explanations and safe defaults.
7. Audit changes and provide reset-to-plan-safe-default action.
8. Document which controls are unavailable in MVP, including authenticated/private crawl.

## Required verification

- Validation/property-origin/plan-bound tests.
- Regex/glob complexity security tests.
- Snapshot immutability tests after settings change.
- Cross-tenant settings tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Model settings for start URLs/sitemaps, include/exclude patterns, maximum URLs/depth, query handling, user agent, rate/concurrency, robots behavior, rendering sampling and artifact retention.
- [ ] Validate all values against global safety caps and effective entitlements; organization settings may reduce but never exceed global policy.
- [ ] Compile patterns safely with complexity/length limits to avoid regex denial of service.
- [ ] Normalize start URLs to the verified allowed origin and reject credentials, fragments or unsupported schemes.
- [ ] Version settings and snapshot the exact effective configuration into each scan.
- [ ] Create settings UI with estimates/credit explanations and safe defaults.
- [ ] Audit changes and provide reset-to-plan-safe-default action.
- [ ] Document which controls are unavailable in MVP, including authenticated/private crawl.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not expose an option to ignore global SSRF/network policy.
- User-agent/robots controls must not impersonate unrelated privileged crawlers.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 058 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 058 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 058
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
