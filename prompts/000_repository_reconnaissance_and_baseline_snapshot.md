---
id: '000'
title: Repository reconnaissance and baseline snapshot
phase: 00 Governance and bootstrap
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on: []
status: pending
---

# Prompt 000 — Repository reconnaissance and baseline snapshot

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `none`
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
ruby tracking/scripts/prompt_tracker.rb start 000
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

Inspect the repository exactly as it exists, determine whether it is empty, partially initialized, or already contains application code, and establish a factual baseline before changing anything. Preserve this blueprint and make later prompts safe to execute against the observed state.

## Required references

- `README.md`
- `AGENTS.md`
- `docs/02_ARCHITECTURE.md`
- `docs/11_ROADMAP_AND_DEFINITION_OF_DONE.md`

## Required work

1. Read `AGENTS.md`, the top-level READMEs, all architecture ADRs, `tracking/state.json`, and this prompt before touching files.
2. Inventory tracked and untracked files, Git status, branches/remotes, runtime/version files, dependency manifests, containers, CI configuration, databases, tests, and any existing Rails application.
3. Record available local tool versions for Ruby, Bundler, Rails, PostgreSQL client, Node, npm, Chromium/Chrome, Docker, and Git. Mark unavailable tools rather than installing them silently.
4. Check for committed secrets, credentials, private keys, generated binaries, and oversized artifacts using safe local inspection; do not print secret values.
5. Create `docs/implementation/000_BASELINE.md` with repository facts, compatibility risks, missing prerequisites, and a proposed initialization path that preserves all blueprint files.
6. Update only documentation/tracker support files required for this baseline. Do not initialize Rails or introduce dependencies in this prompt.

## Required verification

- `git status --short --branch` and record the factual outcome.
- Run the tracker validation command.
- Verify `docs/implementation/000_BASELINE.md` contains no secret values and distinguishes facts from assumptions.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Read `AGENTS.md`, the top-level READMEs, all architecture ADRs, `tracking/state.json`, and this prompt before touching files.
- [ ] Inventory tracked and untracked files, Git status, branches/remotes, runtime/version files, dependency manifests, containers, CI configuration, databases, tests, and any existing Rails application.
- [ ] Record available local tool versions for Ruby, Bundler, Rails, PostgreSQL client, Node, npm, Chromium/Chrome, Docker, and Git. Mark unavailable tools rather than installing them silently.
- [ ] Check for committed secrets, credentials, private keys, generated binaries, and oversized artifacts using safe local inspection; do not print secret values.
- [ ] Create `docs/implementation/000_BASELINE.md` with repository facts, compatibility risks, missing prerequisites, and a proposed initialization path that preserves all blueprint files.
- [ ] Update only documentation/tracker support files required for this baseline. Do not initialize Rails or introduce dependencies in this prompt.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Do not delete or overwrite user work.
- Do not install packages or create the Rails application yet.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 000 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 000 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 000
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
