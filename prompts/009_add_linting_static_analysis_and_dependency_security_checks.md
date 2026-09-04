---
id: 009
title: Add linting, static analysis and dependency security checks
phase: 01 Rails and operational foundation
recommended_reasoning: medium
recommended_model: strongest_available_codex
depends_on:
- 008
status: pending
---

# Prompt 009 — Add linting, static analysis and dependency security checks

## Codex execution settings

- **Recommended reasoning:** `medium`
- **Recommended model:** the strongest coding-capable Codex model available in the current environment
- **Dependencies:** `008`
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
ruby tracking/scripts/prompt_tracker.rb start 009
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

Establish fast, reproducible quality checks for Ruby, ERB, JavaScript/importmap assets, configuration and dependencies.

## Required references

- `docs/09_TEST_STRATEGY.md`
- `docs/07_SECURITY_AND_THREAT_MODEL.md`

## Required work

1. Configure RuboCop using a documented style baseline and minimal justified exclusions.
2. Configure Brakeman and a dependency vulnerability audit compatible with the chosen Rails/Bundler versions.
3. Add ERB/template linting and YAML/JSON validation; include custom validation for config blueprints where practical.
4. Add a repository script such as `bin/quality` that runs deterministic local checks in a sensible order.
5. Keep generated/vendor directories out of scans without excluding application code.
6. Document how advisories are triaged, upgraded and temporarily waived with owner/expiry.
7. Fix existing findings instead of adding blanket exclusions.

## Required verification

- Run all configured linters with zero unreviewed errors.
- Run Brakeman and dependency audit.
- Validate all YAML and JSON files in the blueprint.
- Run the Rails test suite.

Also run every existing check affected by the change. Use real PostgreSQL for locking, queue, quota and concurrency behavior. Provider calls must use fakes/sanitized fixtures in the default test suite.

## Acceptance checklist

- [ ] Configure RuboCop using a documented style baseline and minimal justified exclusions.
- [ ] Configure Brakeman and a dependency vulnerability audit compatible with the chosen Rails/Bundler versions.
- [ ] Add ERB/template linting and YAML/JSON validation; include custom validation for config blueprints where practical.
- [ ] Add a repository script such as `bin/quality` that runs deterministic local checks in a sensible order.
- [ ] Keep generated/vendor directories out of scans without excluding application code.
- [ ] Document how advisories are triaged, upgraded and temporarily waived with owner/expiry.
- [ ] Fix existing findings instead of adding blanket exclusions.
- [ ] Required automated tests were added at the correct layers and all recorded required checks pass.
- [ ] Negative, cross-tenant, retry/idempotency and failure paths are covered where applicable.
- [ ] Migrations include constraints/indexes and production-safety notes where applicable.
- [ ] Customer-visible terminology distinguishes observations, provider data, heuristics and guarantees.
- [ ] Documentation, configuration examples, schemas and ADRs affected by the change are synchronized.
- [ ] No secret, token, private key, production credential or sensitive raw payload was committed.
- [ ] `git diff` contains no accidental or unexplained changes.

## Constraints and explicit non-goals

- No `--force` or blanket ignore of security findings.
- Do not auto-format migrations in ways that obscure generated intent.

## Completion protocol

1. Review the diff and execute the required verification.
2. Run:

```bash
ruby tracking/scripts/prompt_tracker.rb validate
```

3. If required work or verification cannot be completed, keep the prompt honest:

```bash
ruby tracking/scripts/prompt_tracker.rb block 009 \
  --reason "Describe the exact blocker, evidence, and safe next action"
```

4. Only after the acceptance checklist is satisfied, complete it with factual details. Prefer repeatable `--test` arguments:

```bash
ruby tracking/scripts/prompt_tracker.rb complete 009 \
  --summary "Describe the implemented behavior and key files" \
  --test "actual command::passed::actual result" \
  --files "comma-separated changed paths" \
  --risks "remaining risks or none" \
  --next-steps "specific follow-up or none"
```

5. In the final Codex response report:

```text
Prompt: 009
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
