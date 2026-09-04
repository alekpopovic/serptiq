---
id: '070'
title: Implement private artifact storage and lifecycle
phase: 06 Safe crawling and rendering
recommended_reasoning: xhigh
recommended_model: strongest_available_codex
depends_on:
- 069
status: pending
---

# Prompt 070 — Implement private artifact storage and lifecycle

## Codex execution settings

- **Recommended reasoning:** `xhigh`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `069`
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
ruby tracking/scripts/prompt_tracker.rb start 070
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

Store crawl/render/report artifacts in S3-compatible object storage with tenant-safe metadata, authorization and retention.

## Required references

- `docs/03_ERD.md`
- `docs/10_DEPLOYMENT_AND_OPERATIONS.md`
- `docs/adr/0005_object_storage_for_large_artifacts.md`

## Required work

1. Define artifact metadata with organization/project/scan/source, kind, media type, byte count, content hash, storage key, encryption/version and retention state.
2. Implement provider-neutral artifact store adapter plus local/test fake.
3. Stream uploads/downloads; generate opaque keys without raw URL/query/customer names.
4. Use private objects and short-lived signed retrieval only after current authorization.
5. Deduplicate by content hash only within safe tenant/security boundaries; do not create cross-tenant side channels.
6. Implement retention expiry, deletion queue, missing-object/orphan reconciliation and legal-hold placeholder policy.
7. Redact/sanitize downloadable filenames and response headers.
8. Add storage metrics and cost attribution.

## Required verification

- Adapter contract tests including partial upload/failure/retry.
- Cross-tenant signed URL and metadata tests.
- Retention/deletion/idempotency reconciliation tests.
- Secret/key/URL leakage tests.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Define artifact metadata with organization/project/scan/source, kind, media type, byte count, content hash, storage key, encryption/version and retention state.
- [ ] Implement provider-neutral artifact store adapter plus local/test fake.
- [ ] Stream uploads/downloads; generate opaque keys without raw URL/query/customer names.
- [ ] Use private objects and short-lived signed retrieval only after current authorization.
- [ ] Deduplicate by content hash only within safe tenant/security boundaries; do not create cross-tenant side channels.
- [ ] Implement retention expiry, deletion queue, missing-object/orphan reconciliation and legal-hold placeholder policy.
- [ ] Redact/sanitize downloadable filenames and response headers.
- [ ] Add storage metrics and cost attribution.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No public bucket/object ACL.
- Do not store large artifact bodies in PostgreSQL.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 070 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 070 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 070
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
