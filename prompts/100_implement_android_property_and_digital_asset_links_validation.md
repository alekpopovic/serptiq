---
id: '100'
title: Implement Android property and Digital Asset Links validation
phase: 09 Mobile discovery and release guard
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 099
status: pending
---

# Prompt 100 — Implement Android property and Digital Asset Links validation

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `099`
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
ruby tracking/scripts/prompt_tracker.rb start 100
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

Validate the association between an Android package/signing certificate and verified website hosts using bounded `assetlinks.json` retrieval and exact semantics.

## Required references

- `docs/06_SEO_RULE_CATALOG.md`
- `docs/08_INTEGRATIONS_AND_API.md`
- `docs/12_SOURCE_REFERENCES.md`

## Required work

1. Complete Android property fields for package name and one or more expected SHA-256 signing fingerprints with safe formatting/validation.
2. Fetch `/.well-known/assetlinks.json` from each approved verified HTTPS host through the safe HTTP boundary with redirect/content/size limits.
3. Parse bounded JSON and evaluate exact namespace/package/fingerprint/relation entries.
4. Implement missing, invalid, package mismatch, fingerprint mismatch and host coverage rules from the catalog.
5. Store file hash, retrieval time, source version and bounded evidence; never expose confidential unrelated statements.
6. Support multiple production signing certificates/rotation explicitly.
7. Create Android association overview and targeted recheck.
8. Meter rechecks and audit configuration changes.

## Required verification

- Fixtures for valid/multiple/malformed/oversized/mismatch files.
- HTTPS/redirect/private-target security tests.
- Fingerprint normalization/rotation tests.
- Cross-tenant host/property tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Complete Android property fields for package name and one or more expected SHA-256 signing fingerprints with safe formatting/validation.
- [ ] Fetch `/.well-known/assetlinks.json` from each approved verified HTTPS host through the safe HTTP boundary with redirect/content/size limits.
- [ ] Parse bounded JSON and evaluate exact namespace/package/fingerprint/relation entries.
- [ ] Implement missing, invalid, package mismatch, fingerprint mismatch and host coverage rules from the catalog.
- [ ] Store file hash, retrieval time, source version and bounded evidence; never expose confidential unrelated statements.
- [ ] Support multiple production signing certificates/rotation explicitly.
- [ ] Create Android association overview and targeted recheck.
- [ ] Meter rechecks and audit configuration changes.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not accept an arbitrary assetlinks URL.
- A matching file does not prove the installed app build uses the same signing key without manifest/build evidence.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 100 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 100 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 100
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
