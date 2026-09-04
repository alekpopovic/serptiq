---
id: '004'
title: Integrate and verify the prompt execution tracker
phase: 00 Governance and bootstrap
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- '003'
status: pending
---

# Prompt 004 — Integrate and verify the prompt execution tracker

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `003`
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
ruby tracking/scripts/prompt_tracker.rb start 004
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

Make the included prompt tracker a dependable repository workflow: validate catalog/state consistency, document recovery, and add non-destructive checks to CI without changing prompt statuses incorrectly.

## Required references

- `tracking/README.md`
- `schemas/prompt_result.schema.json`
- `AGENTS.md`

## Required work

1. Review `tracking/README.md`, the CSV catalog, initial state, result schema and Ruby CLI implementation included in this blueprint.
2. Run all read-only tracker commands and validate IDs, prompt files, dependencies, cycles, statuses and result-file consistency.
3. Add automated tests for the tracker in an isolated temporary directory, covering next/start/complete/block/reset, dependency denial, concurrent/current prompt denial, atomic state writes and invalid catalog input.
4. Add a CI check that runs tracker validation but never starts/completes prompts.
5. Document how to recover from an interrupted prompt, resolve a block, repair a corrupt state from Git and record an honest failed test.
6. Ensure tracker output is useful to both humans and Codex and never marks this prompt complete automatically.

## Required verification

- Run the tracker test suite.
- Run `ruby tracking/scripts/prompt_tracker.rb validate`.
- Run `ruby tracking/scripts/prompt_tracker.rb status` and verify no unrelated prompt status changed.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Review `tracking/README.md`, the CSV catalog, initial state, result schema and Ruby CLI implementation included in this blueprint.
- [ ] Run all read-only tracker commands and validate IDs, prompt files, dependencies, cycles, statuses and result-file consistency.
- [ ] Add automated tests for the tracker in an isolated temporary directory, covering next/start/complete/block/reset, dependency denial, concurrent/current prompt denial, atomic state writes and invalid catalog input.
- [ ] Add a CI check that runs tracker validation but never starts/completes prompts.
- [ ] Document how to recover from an interrupted prompt, resolve a block, repair a corrupt state from Git and record an honest failed test.
- [ ] Ensure tracker output is useful to both humans and Codex and never marks this prompt complete automatically.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- Tracker tests must operate on a copied temporary state.
- Do not rewrite execution history to hide earlier entries.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 004 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 004 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 004
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
